# frozen_string_literal: true

RSpec.describe 'FetchUtil focal article excerpts' do
  include_context 'extractor integration helpers'

  def focal_excerpt_page(lead, repeated_headline: false)
    article_heading = repeated_headline ? '<p>Community housing review</p>' : '<h1>Community housing review</h1>'
    outer_heading = repeated_headline ? '<h1>Community housing review</h1>' : ''
    <<~HTML
      <html><head><title>Community housing review | Example News</title>
        <meta property="og:site_name" content="Example News">
        <meta property="og:type" content="article">
        <link rel="canonical" href="https://publisher.example/articles/housing-review-123456">
        <script type="application/ld+json">
          {"@type":"Article","headline":"Community housing review",
           "url":"https://publisher.example/articles/housing-review-123456"}
        </script>
      </head><body><main>#{outer_heading}<article>
        #{article_heading}
        <p class="byline">An editorial attribution that must not replace the actual article's opening paragraph.</p>
        <p>#{lead}</p>
        <p>The second paragraph describes the planning meetings and explains how residents can review the evidence.</p>
        <p>The final paragraph records the next public hearing and preserves the remaining reporting in the article.</p>
      </article></main></body></html>
    HTML
  end

  it 'keeps the complete owned lead without truncating or merging the next paragraph' do
    lead = [
      'Residents reviewed the housing proposal and asked planners to publish the assumptions behind each projected cost.',
      'The committee compared transport access, energy efficiency, and the long-term maintenance budgets in neighboring districts.',
      'Its report explains the remaining trade-offs and the dates when residents can submit further comments.'
    ].join(' ')
    with_url_page('https://publisher.example/articles/housing-review-123456', focal_excerpt_page(lead)) do |page|
      payload = extract_payload(page)
      expect(payload['readerMode']).to be(false)
      expect(payload['excerpt']).to eq(lead)
      expect(payload['markdown']).to include(lead, 'The second paragraph describes', 'The final paragraph records')
    end
  end

  it 'keeps the whole first prose paragraph after a source-owned repeated headline' do
    lead = [
      'Residents reviewed the housing proposal and asked planners to publish the assumptions behind each projected cost.',
      'The committee compared transport access, energy efficiency, and the long-term maintenance budgets in neighboring districts.',
      'This complete paragraph remains after the repeated page headline and ends with the next public review date.'
    ].join(' ')
    html = focal_excerpt_page(lead, repeated_headline: true)
    with_url_page('https://publisher.example/articles/housing-review-123456', html) do |page|
      payload = extract_payload(page)
      expect(payload['readerMode']).to be(false)
      expect(payload['excerpt']).to eq(lead)
      expect(payload['excerpt']).not_to include('Community housing review', 'editorial attribution', 'The second paragraph')
    end
  end

  def focal_summary_ownership_page(lead, summary_location: :article, declared_headline: 'Match replay between North City and South United')
    summary_html = lead.sub('decisive phases', '<strong>decisive phases</strong>')
    focal_summary = "<div class=\"summary\">#{summary_html}</div>"
    related_summary = ''
    quoted_summary = ''
    rendered_copy = ''
    case summary_location
    when :related_card
      focal_summary = ''
      related_summary = <<~HTML
        <section class="cards">
          <a href="https://sports.example/highlights/other-match"><h2>Another match recap</h2></a>
          <div class="summary">#{summary_html}</div>
        </section>
      HTML
      rendered_copy = "<h2>#{lead}</h2>"
    when :quote
      focal_summary = ''
      quoted_summary = "<blockquote><div class=\"summary\">#{summary_html}</div></blockquote>"
      rendered_copy = "<h2>#{lead}</h2>"
    when :conflicting_headline
      declared_headline = 'A different structured article headline'
      rendered_copy = "<h2>#{lead}</h2>"
    end

    <<~HTML
      <html><head><title>Match replay</title>
        <meta property="og:type" content="article">
        <link rel="canonical" href="https://sports.example/highlights/match-replay">
        <script type="application/ld+json">
          {"@type":"NewsArticle","headline":"#{declared_headline}","datePublished":"2026-09-21T09:41:06+07:00",
           "mainEntityOfPage":"https://sports.example/highlights/match-replay"}
        </script>
      </head><body><main><article class="news-content">
        <h1>Match replay between North City and South United</h1>
        <div id="match" class="score">North City 2 : 2 South United</div>
        <div class="embed-responsive"><div id="player"><iframe src="https://ok.ru/videoembed/16302024887023"></iframe></div></div>
        <p>The match report records the full result, describes the teams' decisive chances, and explains the context readers need to interpret the replay.</p>
        #{focal_summary}#{quoted_summary}#{rendered_copy}
      </article>#{related_summary}</main></body></html>
    HTML
  end

  it 'selects only a complete summary owned by the proved focal article' do
    lead = [
      'The full match summary identifies the teams and competition, then explains the decisive phases of play.',
      'It preserves the complete source description, including the result, the key chances, and the context needed to interpret the replay.',
      'The closing sentence remains intact instead of being truncated after a headline, player URL, score, or neighboring fixture.'
    ].join(' ')
    html = focal_summary_ownership_page(lead)

    with_url_page('https://sports.example/highlights/match-replay', html) do |page|
      payload = extract_payload(page, reader_mode: false)
      expect(payload.fetch('contentType')).to eq('article')
      expect(payload.fetch('excerpt')).to eq(lead)
      expect(payload.fetch('publishedTime')).to eq('2026-09-21T09:41:06+07:00')
      expect(payload.fetch('html')).not_to include('<iframe')

      related = focal_summary_ownership_page(lead, summary_location: :related_card)
      page.go_to('about:blank')
      page.content = related
      related_card = extract_payload(page, reader_mode: false)
      expect(related_card.fetch('contentType')).to eq('article')
      expect(related_card.fetch('excerpt')).not_to eq(lead)

      quoted = focal_summary_ownership_page(lead, summary_location: :quote)
      page.go_to('about:blank')
      page.content = quoted
      quoted_summary = extract_payload(page, reader_mode: false)
      expect(quoted_summary.fetch('excerpt')).not_to eq(lead)

      conflicting = focal_summary_ownership_page(lead, summary_location: :conflicting_headline)
      page.go_to('about:blank')
      page.content = conflicting
      mismatched = extract_payload(page, reader_mode: false)
      expect(mismatched.fetch('excerpt')).not_to eq(lead)
    end
  end
end
