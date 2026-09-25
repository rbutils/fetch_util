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
end
