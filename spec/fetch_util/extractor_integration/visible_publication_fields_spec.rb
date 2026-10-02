# frozen_string_literal: true

RSpec.describe 'FetchUtil visible publication fields' do
  include_context 'extractor integration helpers'

  def publication_field_page(field)
    <<~HTML
      <html><head><title>Restoring the river</title><meta name="generator" content="WordPress 6.8"></head>
      <body><main><article class="status-publish"><h1 class="entry-title">Restoring the river</h1>
        <div class="publication-wrapper">#{field}<div class="entry-content">
          <p>The restoration team returned to the river to measure the effect of removing the concrete barriers.</p>
          <p>Engineers compared water levels and wildlife counts before discussing the next stage with residents.</p>
          <p>The work will continue through the autumn, with a public report documenting each result.</p>
        </div></div></article></main></body></html>
    HTML
  end

  it 'does not treat publication-status article or body containers as a date field' do
    extract_from_url('https://example-blog.test/restoration/', publication_field_page('')) do |payload|
      expect(payload['publishedTime']).to be_nil
      expect(payload['markdown']).to include('The restoration team returned to the river')
    end
  end

  it 'uses the first linked answer timestamp only when it belongs to the current question' do
    canonical_url = 'https://publisher.example/questions/language'
    html = <<~HTML
      <!doctype html><html><head><link rel="canonical" href="#{canonical_url}"></head>
      <body><main><h1>Which language is this?</h1>
        <div class="answer-record"><a class="answer_timestamp" href="#{canonical_url}/answer/leading">8y</a>
          <p>The first answer explains the language's design and initial historical context at length.</p>
          <p>It continues with a second substantial paragraph that completes the leading answer.</p></div>
        <div class="answer-record"><a class="answer_timestamp" href="#{canonical_url}/answer/later">4y</a>
          <p>A later answer has its own date and separate explanatory content for this question.</p>
          <p hidden>This hidden paragraph cannot establish another publication record.</p></div>
        <div class="answer-record"><a class="answer_timestamp" href="https://publisher.example/questions/biology/answer/foreign">Sep 17</a>
          <p>A different question's answer and its publication time do not belong to this page.</p></div>
      </main></body></html>
    HTML

    extract_from_url(canonical_url, html) do |payload|
      expect(payload['publishedTime']).to eq('8y')
    end
  end

  it 'does not use answer timestamps in an unrelated article under the same main' do
    canonical_url = 'https://publisher.example/reference/language-history'
    html = <<~HTML
      <!doctype html><html><head><link rel="canonical" href="#{canonical_url}"></head><body>
      <main><h1>Language history reference</h1>
        <article class="reference-entry"><h2>Related answer collection</h2>
          <a class="answer_timestamp" href="#{canonical_url}/answer/one">8y</a>
          <p>This reference discusses a related question but does not own the page publication date.</p>
          <p>Its separate article body contains two paragraphs and a linked answer timestamp.</p>
        </article>
        <article class="reference-entry"><h2>Another answer collection</h2>
          <a class="answer_timestamp" href="#{canonical_url}/answer/two">4y</a>
          <p>This second reference entry also contains substantial prose and an answer link.</p>
          <p>Neither linked entry belongs to the page's unique heading or publication record.</p>
        </article>
      </main></body></html>
    HTML

    extract_from_url(canonical_url, html) do |payload|
      expect(payload['publishedTime']).to be_nil
    end
  end

  it 'does not promote answer timestamps inside form, aside, or quoted contexts' do
    canonical_url = 'https://publisher.example/questions/river'
    html = <<~HTML
      <!doctype html><html><head><link rel="canonical" href="#{canonical_url}"></head><body>
      <main><section class="question-region"><h1>How does the river recover?</h1>
        <form><a class="answer_timestamp" href="#{canonical_url}/answer/form">8y</a>
          <p>Form context paragraph one.</p><p>Form context paragraph two.</p></form>
        <aside><a class="answer_timestamp" href="#{canonical_url}/answer/aside">4y</a>
          <p>Aside context paragraph one.</p><p>Aside context paragraph two.</p></aside>
        <blockquote><a class="answer_timestamp" href="#{canonical_url}/answer/quoted">2y</a>
          <p>Quoted context paragraph one.</p><p>Quoted context paragraph two.</p></blockquote>
      </section></main></body></html>
    HTML

    extract_from_url(canonical_url, html) do |payload|
      expect(payload['publishedTime']).to be_nil
    end
  end

  it 'finds localized publication fields after rejecting a matching body wrapper' do
    fields = {
      '<div class="published"><p>Δημοσιεύτηκε: 25 Σεπτεμβρίου 2026</p></div>' => 'Δημοσιεύτηκε: 25 Σεπτεμβρίου 2026',
      '<p class="published"><span>Published</span> September 25, 2026</p>' => 'Published September 25, 2026'
    }

    fields.each do |field, expected|
      extract_from_url('https://example-blog.test/restoration/', publication_field_page(field)) do |payload|
        expect(payload['publishedTime']).to eq(expected)
      end
    end
  end

  it 'prefers a date value among section labels without discarding other date formats' do
    labeled_fields = <<~HTML
      <div class="publication-wrapper">
        <div class="detail-time">تازہ ترین</div>
        <div class="detail-time">قومی خبریں</div>
        <div class="detail-time">26 ستمبر ، 2026</div>
        <div class="entry-content"><p>#{"A" * 80}</p></div>
      </div>
    HTML
    extract_from_url('https://example-blog.test/restoration/', publication_field_page(labeled_fields)) do |payload|
      expect(payload['publishedTime']).to eq('26 ستمبر ، 2026')
    end

    timed_fields = '<time datetime="latest">Latest</time><time datetime="2026-09-28">September 28, 2026</time>'
    extract_from_url('https://example-blog.test/restoration/', publication_field_page(timed_fields)) do |payload|
      expect(payload['publishedTime']).to eq('2026-09-28')
    end

    {
      '<span class="published-date">13 July</span>' => '13 July',
      '<span class="published-date">2026年9月27日</span>' => '2026年9月27日',
      '<span class="published-date">٢٦ سبتمبر ٢٠٢٦</span>' => '26 سبتمبر 2026',
      '<span class="published-date">۲۶ سپتامبر ۲۰۲۶</span>' => '26 سپتامبر 2026',
      '<span class="published-date">3 hours ago</span>' => '3 hours ago',
      '<span class="published-date">12:30</span>' => '12:30'
    }.each do |field, expected|
      with_url_page('https://example-blog.test/restoration/', publication_field_page(field)) do |page|
        original = page.evaluate('document.body.innerHTML')
        payload = extract_payload(page)
        expect(payload['publishedTime']).to eq(expected)
        expect(page.evaluate('document.body.innerHTML')).to eq(original)
      end
    end
  end

  it 'retains the existing first-field fallback when no recognized date format is present' do
    field = '<span class="published-date">Latest coverage</span><span class="date">Regional news</span>'
    extract_from_url('https://example-blog.test/restoration/', publication_field_page(field)) do |payload|
      expect(payload['publishedTime']).to eq('Latest coverage')
    end
  end

  it 'preserves explicit datetime priority and ignores hidden date fields' do
    field = <<~HTML
      <span class="published" hidden>September 24, 2026</span>
      <time datetime="2026-09-25T09:30:00Z">25 September 2026</time>
    HTML

    extract_from_url('https://example-blog.test/restoration/', publication_field_page(field)) do |payload|
      expect(payload['publishedTime']).to eq('2026-09-25T09:30:00Z')
    end
  end

  def inline_publication_page(field)
    heading = '<h1 class="entry-title">Restoring the river</h1>'
    publication_field_page('').sub(heading, "<header class=\"entry-header\">#{field}#{heading}</header>")
  end

  it 'retains inline labeled header dates in metadata and content without making them the excerpt' do
    field = 'Atualizado em <strong>08/09/2026 às 13:55</strong> • Verificação em tempo real'

    extract_from_url('https://example-blog.test/restoration/', inline_publication_page(field)) do |payload|
      expect(payload['publishedTime']).to eq('08/09/2026 às 13:55')
      expect(payload['html']).to include('Atualizado em <strong>08/09/2026 às 13:55</strong>')
      expect(payload['markdown']).to include('Atualizado em **08/09/2026 às 13:55**')
      expect(payload['excerpt']).to start_with('The restoration team returned to the river')
    end
  end

  it 'does not promote event dates, hidden dates, ambiguous headers, or non-date labels' do
    fields = [
      'Meeting on <strong>08/09/2026</strong>',
      'Updated <strong hidden>2026-09-08</strong>',
      'Updated <strong style="visibility:hidden">2026-09-08</strong>',
      'Updated <strong>all river measurements</strong>',
      'Updated <strong>2026-09-08</strong><h1>Another article</h1>'
    ]

    fields.each do |field|
      extract_from_url('https://example-blog.test/restoration/', inline_publication_page(field)) do |payload|
        expect(payload['publishedTime']).to be_nil
      end
    end
  end

  it 'keeps explicit datetime priority while preserving the separate updated field in content' do
    field = 'Updated <strong>2026-09-08 13:55</strong><time datetime="2026-09-07T12:00:00Z">7 September</time>'

    extract_from_url('https://example-blog.test/restoration/', inline_publication_page(field)) do |payload|
      expect(payload['publishedTime']).to eq('2026-09-07T12:00:00Z')
      expect(payload['markdown']).to include('Updated **2026-09-08 13:55**')
    end
  end

  it 'retains a dated header when the same article repeats its exact headline in the body' do
    html = inline_publication_page('Atualizado em <strong>14/09/2026 às 13:36</strong>')
           .sub('<div class="entry-content">', '<div class="entry-content"><h1>Restoring the river</h1>')

    extract_from_url('https://example-blog.test/restoration/', html) do |payload|
      expect(payload['publishedTime']).to eq('14/09/2026 às 13:36')
      expect(payload['markdown']).to include('Atualizado em **14/09/2026 às 13:36**')
      expect(payload['excerpt']).to start_with('The restoration team returned to the river')
    end
  end

  it 'does not borrow dates from an author listing calendar or linked child stories' do
    html = <<~HTML
      <html><head><title>Denis Cosnard - Contributions</title>
      <link rel="canonical" href="https://example-blog.test/author/denis-cosnard"></head>
      <body><main><h1>Denis Cosnard</h1>
        <aside class="calendar"><p class="insert-date">Wednesday 23 September 2026</p></aside>
        <section class="teaser"><a href="/stories/first"><h2>First reported story</h2></a>
          <p class="published-date">Published September 21, 2026</p>
          <p>First source-owned story summary with enough text to establish a complete article card.</p>
        </section>
        <section class="teaser"><a href="/stories/second"><h2>Second reported story</h2></a>
          <p class="published-date">Published September 19, 2026</p>
          <p>Second source-owned story summary with enough text to establish a complete article card.</p>
        </section>
        <div class="event-schedule"><time datetime="2026-09-30">September 30, 2026</time></div>
      </main></body></html>
    HTML

    extract_from_url('https://example-blog.test/author/denis-cosnard', html) do |payload|
      expect(payload['publishedTime']).to be_nil
    end
  end

  it 'keeps an owned article header date when separate related records have foreign dates' do
    canonical_url = 'https://publisher.example/reports/river-restoration'
    html = <<~HTML
      <!doctype html><html><head><link rel="canonical" href="#{canonical_url}"></head><body>
      <main><article class="prevent-scroll event-report">
        <header class="article-header"><h1>River restoration progress report</h1>
          <time datetime="2026-09-24T08:15:00Z">September 24, 2026</time></header>
        <div class="entry-content">
          <p>The restoration team returned to the river to measure the effect of removing concrete barriers.</p>
          <p>Engineers compared water levels and wildlife counts before discussing the next phase with residents.</p>
          <p>The public report records the findings and explains how the project will continue through autumn.</p>
        </div>
        <aside class="related-rail">
          <article class="event-analysis"><h2><a href="/events/river-workshop">River restoration workshop</a></h2>
            <time itemprop="startDate" datetime="2026-10-04T09:00:00Z">October 4, 2026</time></article>
          <article class="related-card"><h2><a href="/reports/wetlands">Wetlands report</a></h2>
            <time class="published-date" datetime="2026-09-18">September 18, 2026</time></article>
        </aside>
      </article></main></body></html>
    HTML

    extract_from_url(canonical_url, html) do |payload|
      expect(payload['publishedTime']).to eq('2026-09-24T08:15:00Z')
    end
  end

  it 'keeps an unwrapped article date beside related cards with foreign linked headlines' do
    canonical_url = 'https://publisher.example/reports/water-restoration'
    html = <<~HTML
      <!doctype html><html><head><title>Water restoration progress report</title>
      <link rel="canonical" href="#{canonical_url}"></head><body><main>
        <article class="story">
          <h1>Water restoration progress report</h1>
          <time datetime="2026-09-24T08:15:00Z">September 24, 2026</time>
          <div class="entry-content">
            <p>The restoration team returned to the river to measure the effect of removing the concrete barriers.</p>
            <p>Engineers compared water levels and wildlife counts before discussing the next stage with residents.</p>
          </div>
          <aside class="related-rail">
            <article class="card"><h2><a href="/reports/wetlands">Wetlands report</a></h2>
              <time datetime="2026-09-18">September 18, 2026</time></article>
            <article class="card"><h2><a href="/reports/river-plan">River plan</a></h2>
              <time datetime="2026-09-19">September 19, 2026</time></article>
          </aside>
        </article>
      </main></body></html>
    HTML

    extract_from_url(canonical_url, html) do |payload|
      expect(payload['publishedTime']).to eq('2026-09-24T08:15:00Z')
    end
  end

  it 'accepts the unique question proof in a role main just as in a semantic main' do
    canonical_url = 'https://publisher.example/questions/river-restoration'
    html = <<~HTML
      <!doctype html><html><head><title>How did the river recover?</title>
      <link rel="canonical" href="#{canonical_url}"></head><body>
      <div role="main"><h1>How did the river recover?</h1>
        <div class="answer-record"><a class="answer_timestamp" href="#{canonical_url}/answer/first">8y</a>
          <p>The leading answer explains the restoration work and its long-term effect on the waterway.</p>
          <p>It continues with a second source-owned paragraph describing the recovery process.</p></div>
        <div class="answer-record"><a class="answer_timestamp" href="#{canonical_url}/answer/second">4y</a>
          <p>A separate answer contains its own publication age and independent explanation.</p></div>
      </div></body></html>
    HTML

    extract_from_url(canonical_url, html) do |payload|
      expect(payload['publishedTime']).to eq('8y')
    end
  end

  it 'rejects a contradictory role-main article with answer-shaped reference links' do
    canonical_url = 'https://publisher.example/reports/river-restoration'
    html = <<~HTML
      <!doctype html><html><head><title>River restoration reference</title>
      <link rel="canonical" href="#{canonical_url}"></head><body>
      <article role="main"><h1>River restoration reference</h1>
        <h2>Questions answered by another article</h2>
        <div><a class="answer_timestamp" href="#{canonical_url}/answer/first">8y</a>
          <p>This reference entry discusses the river without being the current question page.</p>
          <p>Its independent article prose does not establish the publication date of this document.</p></div>
        <div><a class="answer_timestamp" href="#{canonical_url}/answer/second">4y</a>
          <p>A second reference entry has separate prose and a different answer destination.</p></div>
      </article></body></html>
    HTML

    extract_from_url(canonical_url, html) do |payload|
      expect(payload['publishedTime']).to be_nil
    end
  end

  it 'declines a date inside one foreign card and an ambiguous shared wrapper' do
    canonical_url = 'https://publisher.example/reports/current'
    cases = [
      <<~HTML,
        <!doctype html><html><head><link rel="canonical" href="#{canonical_url}"></head><body>
        <main><h1>Current report</h1><article class="card">
          <h2><a href="/reports/child">A related child report</a></h2>
          <time class="published-date" datetime="2026-09-18">September 18, 2026</time>
          <p>This linked child record contains a summary and its own publication date.</p>
          <p>The record remains a separate item rather than the current page's publication.</p>
        </article></main></body></html>
      HTML
      <<~HTML
        <!doctype html><html><head><link rel="canonical" href="#{canonical_url}"></head><body>
        <main><h1>Reports index</h1><section class="shared-records">
          <time class="published-date" datetime="2026-09-18">September 18, 2026</time>
          <article class="card"><h2><a href="/reports/one">First report</a></h2>
            <p>The first linked report has a complete independent summary and source owner.</p></article>
          <article class="card"><h2><a href="/reports/two">Second report</a></h2>
            <p>The second linked report has another complete independent summary and owner.</p></article>
        </section></main></body></html>
      HTML
    ]

    cases.each do |html|
      extract_from_url(canonical_url, html) do |payload|
        expect(payload['publishedTime']).to be_nil
      end
    end
  end

  it 'does not promote explicit event start dates or calendar-widget dates' do
    canonical_url = 'https://publisher.example/reports/no-publication-date'
    html = <<~HTML
      <!doctype html><html><head><link rel="canonical" href="#{canonical_url}"></head><body>
      <main><article><header><h1>River restoration announcement</h1></header>
        <div class="entry-content"><p>The article explains the restoration plan and its community impact.</p>
          <p>It describes the research and explains how the team will share its findings.</p></div>
        <div class="event-start-date"><time datetime="2026-10-04T09:00:00Z">October 4, 2026</time></div>
        <div role="grid" aria-label="Event calendar">
          <time datetime="2026-10-05">October 5, 2026</time>
        </div>
      </article></main></body></html>
    HTML

    extract_from_url(canonical_url, html) do |payload|
      expect(payload['publishedTime']).to be_nil
    end
  end
end
