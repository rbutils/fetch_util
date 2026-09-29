# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'source-owned Reader attribution' do
  include_context 'extractor integration helpers'

  def csdn_reader_article(author: 'CSDN', other_article: '', foreign_leading: '', foreign_trailing: '')
    <<~HTML
      <!doctype html>
      <html><head>
        <title>Java begins leaving Intel Macs - CSDN Blog</title>
        <meta name="author" content="#{author}">
        <meta property="og:site_name" content="CSDN">
      </head><body><main>
        <div class="title-box"><h1>Java begins leaving Intel Macs</h1></div>
        <div class="article-bar-top"><span class="time">2026-07-06 11:16:42</span><a class="name" href="/users/csdnnews">csdnnews</a></div>
        #{foreign_leading}
        <article>
        <div id="article_content"><div id="content_views">
          <p>Intel Mac users have another clear sign that the old platform is leaving future Java releases.</p>
          <p>The OpenJDK community is discussing removal of macOS x64 builds in JDK 27.</p>
          <h2>Why now?</h2>
          <p>Apple moved to its own processors years ago, and maintaining older platforms keeps getting harder.</p>
          <p>Developers can keep using earlier Java versions while new releases focus on current hardware.</p>
        </div><div class="readall_box">登录后阅读全文</div></div></article>
        #{other_article}
        #{foreign_trailing}
      </main></body></html>
    HTML
  end

  def sky_reader_article(attribution: '<div class="article-sub-heading">سكاي نيوز عربية - أبوظبي</div>', duplicate_caption: '')
    <<~HTML
      <!doctype html>
      <html><head>
        <title>Regional program expands</title>
        <meta name="author" content="سكاي نيوز عربية">
        <meta property="og:site_name" content="سكاي نيوز عربية">
      </head><body><main class="article_detail_page">
        <h1>Regional program expands</h1>
        #{attribution}
        <div class="article_image_heading_bg">Photo caption for the regional program</div>
        <p class="article-summary">The regional program is expanding with new venues, workshops, and public events developed with community organizations.</p>
        <section class="article-content">
          <p>Organizers said the next phase will support local artists and give residents more opportunities to participate throughout the year.</p>
          <p>Schools and libraries will publish a shared calendar as each part of the program opens to the public.</p>
          <p>Community groups will coordinate the schedule with the venues taking part in the regional program.</p>
        </section>
      </main>
      #{duplicate_caption}
      </body></html>
    HTML
  end

  def conflicting_reader_byline_article(
    author: 'Synthetic Reporter', visible_byline: 'Mira Reporter', byline_attributes: '', byline_class: 'writers-names',
    other_visible_headline: ''
  )
    <<~HTML
      <!doctype html>
      <html><head>
        <title>River restoration report - Research Journal</title>
        <meta name="author" content="#{author}">
        <meta property="og:site_name" content="Research Journal">
      </head><body><main><article class="story-record">
        <h1 class="title">River restoration report</h1>
        <p class="#{byline_class}" #{byline_attributes}>#{visible_byline}</p>
        <p class="date-and-time-p">Published 6 July 2026</p>
        <section class="article-content">
          <h3>Measured results</h3>
          <p>Source paragraph 1 records the river restoration team measurements after six months of work.</p>
          <p>Source paragraph 2 explains how engineers documented improved flow throughout the river corridor.</p>
          <p>Source paragraph 3 links the <a href="https://reports.example/archive/river">complete monitoring record</a> for the published measurements.</p>
          <p>Source paragraph 4 describes the habitat changes recorded by the independent monitoring team.</p>
          <p>Source paragraph 5 gives residents the complete chronology of the river restoration project.</p>
        </section>
      </article>
      #{other_visible_headline}
      </main></body></html>
    HTML
  end

  def with_source_unchanged_payload(path, html)
    with_url_page("https://news.example.test/#{path}", html) do |page|
      source_before = page.evaluate('document.body.innerHTML')
      payload = extract_payload(page, reader_mode: true)
      expect(page.evaluate('document.body.innerHTML')).to eq(source_before)
      yield payload
    end
  end

  it 'restores a sibling header author link only for the same identity-bound Reader article' do
    with_source_unchanged_payload('csdn-reader-article', csdn_reader_article) do |payload|
      expect(payload).to include('readerMode' => true, 'contentType' => 'article', 'byline' => 'csdnnews')
      expect(payload['publishedTime']).to eq('2026-07-06 11:16:42')
      expect(payload['markdown']).to include('# Java begins leaving Intel Macs')
      expect(payload['markdown']).to include('Intel Mac users have another clear sign')
      expect(payload['markdown']).to include('Developers can keep using earlier Java versions')
    end
  end

  it 'restores an owner-bound publisher-prefix subtitle without borrowing narrative' do
    with_source_unchanged_payload('sky-reader-byline', sky_reader_article) do |payload|
      expect(payload).to include('readerMode' => true, 'contentType' => 'article', 'byline' => 'سكاي نيوز عربية - أبوظبي')
      expect(payload['markdown']).to include('سكاي نيوز عربية - أبوظبي')
      expect(payload['markdown']).to include('Photo caption for the regional program')
      expect(payload['markdown']).to include('Community groups will coordinate the schedule')
    end

    duplicate_caption = '<aside><div class="caption-copy">Photo caption for the regional program</div></aside>'
    with_source_unchanged_payload('sky-reader-duplicate-caption', sky_reader_article(duplicate_caption: duplicate_caption)) do |payload|
      expect(payload).to include('readerMode' => true, 'byline' => 'سكاي نيوز عربية')
      expect(payload['markdown']).to include('Photo caption for the regional program')
    end

    narratives = [
      '<div class="article-sub-heading">سكاي نيوز عربية - قال مسؤولون إن البرنامج سيتوسع خلال العام المقبل.</div>',
      '<div class="subtitle">سكاي نيوز عربية - أكدت الإدارة أن البرامج ستستمر.</div>',
      '<h2 class="subtitle">سكاي نيوز عربية - قالت مصادر إن البرنامج سيواصل عمله.</h2>',
      '<div class="article-sub-heading">سكاي نيوز عربية أبوظبي</div>'
    ]
    narratives.each_with_index do |narrative, index|
      with_source_unchanged_payload("sky-reader-narrative-#{index}", sky_reader_article(attribution: narrative)) do |payload|
        expect(payload).to include('readerMode' => true, 'contentType' => 'article', 'byline' => 'سكاي نيوز عربية')
        expect(payload['markdown']).to include(narrative[/>(.*?)</, 1])
      end
    end
  end

  it 'keeps a conflicting declared author and rejects an ambiguous mixed-article owner' do
    with_source_unchanged_payload('csdn-reader-conflict', csdn_reader_article(author: 'Alice Reporter')) do |payload|
      expect(payload).to include('readerMode' => true, 'byline' => 'Alice Reporter')
    end

    other = <<~HTML
      <article><h2>Separate report</h2>
        <p>The independent municipal report describes a separate public record with its own timeline, officials, and transportation decisions. Its long first paragraph gives the Reader enough source material to select this record independently from the Java article above.</p>
        <p>Its second paragraph explains how neighborhood routes, construction schedules, and public meeting dates were set by a different editorial team. Those facts and citations belong to that separate report, not to the article with the CSDN author bar.</p>
        <p>The final paragraph covers the independent project budget, a new council vote, and the next publication date. Readers following this story should not inherit an author attribution from the unrelated article before it.</p>
      </article>
    HTML
    with_source_unchanged_payload('csdn-reader-mixed-articles', csdn_reader_article(other_article: other)) do |payload|
      expect(payload).to include('readerMode' => true, 'contentType' => 'article')
      expect(payload['markdown']).to include('The independent municipal report describes a separate public record')
      expect(payload['byline']).not_to eq('csdnnews')
    end
  end

  it 'preserves a visible conflicting source byline while keeping declared-person precedence' do
    with_source_unchanged_payload('river-restoration-conflicting-byline', conflicting_reader_byline_article) do |payload|
      expect(payload).to include('readerMode' => true, 'contentType' => 'article', 'byline' => 'Synthetic Reporter')
      expect(payload['html']).to include('<h1 class="title">River restoration report</h1>', 'Mira Reporter', '<h3>Measured results</h3>')
      expect(payload['html'].index('River restoration report')).to be < payload['html'].index('Mira Reporter')
      expect(payload['html'].index('Mira Reporter')).to be < payload['html'].index('Measured results')
      expect(payload['markdown']).to include(
        '# River restoration report', 'Mira Reporter', 'Measured results', 'complete monitoring record',
        'Source paragraph 1', 'Source paragraph 2', 'Source paragraph 3', 'Source paragraph 4', 'Source paragraph 5'
      )
      expect(payload['markdown'].index('River restoration report')).to be < payload['markdown'].index('Mira Reporter')
      expect(payload['markdown'].index('Mira Reporter')).to be < payload['markdown'].index('Measured results')
      expect(payload['html']).to include('href="https://reports.example/archive/river"')
      expected_order = [
        'River restoration report', 'Mira Reporter', 'Measured results', 'Source paragraph 1',
        'Source paragraph 2', 'Source paragraph 3', 'complete monitoring record',
        'Source paragraph 4', 'Source paragraph 5'
      ]
      [payload['html'], payload['markdown']].each do |article_text|
        positions = expected_order.map { |text| article_text.index(text) }
        expect(positions).to all(be_truthy)
        expect(positions).to eq(positions.sort)
      end
    end
  end

  it 'does not add a duplicate for a matching declared author or attribute hidden and foreign bylines' do
    matching = conflicting_reader_byline_article(author: 'Mira Reporter', visible_byline: 'Mira Reporter')
    with_source_unchanged_payload('river-restoration-matching-byline', matching) do |payload|
      expect(payload).to include('readerMode' => true, 'byline' => 'Mira Reporter')
      expect(payload['markdown'].scan(/^Mira Reporter$/).length).to eq(1)
    end

    hidden = conflicting_reader_byline_article(byline_attributes: 'hidden')
    with_source_unchanged_payload('river-restoration-hidden-byline', hidden) do |payload|
      expect(payload).to include('readerMode' => true, 'byline' => 'Synthetic Reporter')
      expect(payload['html']).not_to include('Mira Reporter')
    end

    multiple = conflicting_reader_byline_article(visible_byline: 'Mira Reporter and Noam Witness')
    with_source_unchanged_payload('river-restoration-multiple-conflicting-authors', multiple) do |payload|
      expect(payload['byline']).to eq('Synthetic Reporter')
      expect(payload['html']).to include('Mira Reporter and Noam Witness')
      expect(payload['markdown']).to include('Mira Reporter and Noam Witness')
    end

    foreign = conflicting_reader_byline_article(visible_byline: 'Mira Reporter').sub(
      '</main>', '<article><h2>Separate report</h2><p class="writers-names">Foreign Reporter</p>' \
                 '<p>The separate report describes its own independently verified public record and timeline.</p></article></main>'
    )
    foreign = foreign.sub('</body>', '<footer><p class="writers-names">Footer Reporter</p></footer></body>')
    with_source_unchanged_payload('river-restoration-foreign-byline', foreign) do |payload|
      expect(payload['byline']).to eq('Synthetic Reporter')
      expect(payload['html']).to include('<h1 class="title">River restoration report</h1>', 'Mira Reporter', '<h3>Measured results</h3>')
      expect(payload['markdown']).to include('# River restoration report', 'Mira Reporter', 'Measured results')
      (1..5).each do |number|
        expect(payload['markdown']).to include("Source paragraph #{number}")
      end
      expect(payload['html']).not_to include('Foreign Reporter')
      expect(payload['html']).not_to include('Footer Reporter')
      expect(payload['markdown']).not_to include('Foreign Reporter')
      expect(payload['markdown']).not_to include('Footer Reporter')
      expect(payload['html']).to include('href="https://reports.example/archive/river"')
    end
  end

  it 'preserves source order for retained and restored coauthors without duplicating retained credits' do
    expected_order = [
      'River restoration report', 'Mira Reporter', 'Noam Witness', 'Measured results', 'Source paragraph 1',
      'Source paragraph 2', 'Source paragraph 3', 'complete monitoring record',
      'Source paragraph 4', 'Source paragraph 5'
    ]
    verify_coauthor_order = lambda do |payload, expected_byline|
      expect(payload).to include('readerMode' => true, 'contentType' => 'article', 'byline' => expected_byline)
      expect(payload['html']).to include('<h1 class="title">River restoration report</h1>', 'Mira Reporter', 'Noam Witness')
      expect(payload['html'].scan('Mira Reporter').length).to eq(1)
      expect(payload['html'].scan('Noam Witness').length).to eq(1)
      expect(payload['markdown'].scan(/^Mira Reporter$/).length).to eq(1)
      expect(payload['markdown'].scan(/^Noam Witness$/).length).to eq(1)
      [payload['html'], payload['markdown']].each do |article_text|
        positions = expected_order.map { |text| article_text.index(text) }
        expect(positions).to all(be_truthy)
        expect(positions).to eq(positions.sort)
      end
    end

    # Native Readability retains the unrecognized first class and selects the second author.
    retained_first = conflicting_reader_byline_article.sub(
      'Mira Reporter</p>', 'Mira Reporter</p><p class="author-name">Noam Witness</p>'
    )
    with_source_unchanged_payload('river-restoration-retained-first-coauthor', retained_first) do |payload|
      verify_coauthor_order.call(payload, 'Noam Witness')
    end

    # Swap the classes so the first source credit is removed and the second remains.
    retained_second = conflicting_reader_byline_article(byline_class: 'author-name').sub(
      'Mira Reporter</p>', 'Mira Reporter</p><p class="writers-names">Noam Witness</p>'
    )
    with_source_unchanged_payload('river-restoration-retained-second-coauthor', retained_second) do |payload|
      verify_coauthor_order.call(payload, 'Mira Reporter')
    end

    # When both source credits remain in Reader output, do not duplicate either one.
    both_retained = conflicting_reader_byline_article.sub(
      'Mira Reporter</p>', 'Mira Reporter</p><p class="writers-names">Noam Witness</p>'
    )
    with_source_unchanged_payload('river-restoration-both-coauthors-retained', both_retained) do |payload|
      verify_coauthor_order.call(payload, 'Synthetic Reporter')
    end

    # Native Readability selects the first author and retains the second after its byline is set.
    marked_coauthors = conflicting_reader_byline_article(byline_class: 'author-name').sub(
      'Mira Reporter</p>', 'Mira Reporter</p><p class="author-name">Noam Witness</p>'
    )
    with_source_unchanged_payload('river-restoration-both-coauthors-removed', marked_coauthors) do |payload|
      verify_coauthor_order.call(payload, 'Mira Reporter')
    end
  end

  it 'keeps native retained coauthors and byline when ambiguous headlines decline restoration' do
    article = conflicting_reader_byline_article(
      byline_class: 'author-name',
      other_visible_headline: '<article class="related-story"><h1>Independent headline outside the story</h1></article>'
    ).sub(
      'Mira Reporter</p>', 'Mira Reporter</p><p class="author-name">Noam Witness</p>'
    )
    with_url_page('https://news.example.test/river-restoration-ambiguous-headline-control', article) do |page|
      source_before = page.evaluate('document.body.innerHTML')
      expect(page.evaluate('document.querySelectorAll("h1").length')).to eq(2)
      payload = extract_payload(page, reader_mode: true)
      expect(page.evaluate('document.body.innerHTML')).to eq(source_before)
      expect(payload).to include('readerMode' => true, 'contentType' => 'article', 'byline' => 'Mira Reporter')
      expect(payload['html']).to include('<h2>River restoration report</h2>', 'Noam Witness')
      expect(payload['html']).not_to include('<h1')
      expect(payload['html']).not_to include('Mira Reporter')
      expect(payload['html'].scan('Noam Witness').length).to eq(1)
      expect(payload['markdown']).to include('River restoration report', 'Noam Witness')
      expect(payload['markdown']).not_to include('Mira Reporter')
      expect(payload['markdown']).to include(
        'Source paragraph 1 records the river restoration team measurements after six months of work.',
        'Source paragraph 5 gives residents the complete chronology of the river restoration project.'
      )
    end
  end

  it 'rejects selected leading and trailing paragraphs outside the owned article boundary' do
    foreign_lead = <<~HTML
      <article><h2>Independent leading story</h2>
        <p>The separate municipal report records its own timeline, officials, transportation decisions, and a distinct public record. Its first paragraph has enough source detail to be selected before the Java story.</p>
        <p>Its second paragraph explains neighborhood routes, construction schedules, and public meeting dates chosen by a different editorial team. Those facts belong only to this independent report.</p>
        <p>The final paragraph covers the separate project budget, council vote, and next publication date. Readers following this story must not inherit an author from the later CSDN article.</p>
      </article>
    HTML
    with_source_unchanged_payload('csdn-reader-foreign-leading', csdn_reader_article(foreign_leading: foreign_lead)) do |payload|
      expect(payload['markdown']).to include('The separate municipal report records its own timeline')
      expect(payload['byline']).not_to eq('csdnnews')
    end

    foreign_trailing = <<~HTML
      <article><h2>Independent trailing story</h2>
        <p>The later municipal report belongs to a different article. It explains a separate schedule, location, and agency decision as an independent editorial record.</p>
        <p>Additional background describes that separate program, public calendar, and the agency responsible for it. Nothing here updates the CSDN Java story.</p>
        <p>Its final paragraph notes the next council meeting and a publication date for the separate report. The CSDN author bar must not be borrowed by this trailing record.</p>
      </article>
    HTML
    with_source_unchanged_payload('csdn-reader-foreign-trailing', csdn_reader_article(foreign_trailing: foreign_trailing)) do |payload|
      expect(payload['markdown']).to include('The later municipal report belongs to a different article')
      expect(payload['byline']).not_to eq('csdnnews')
    end
  end
end
