require 'spec_helper'
require 'nokogiri'

RSpec.describe FetchUtil::Extractor do
  include_context 'extractor integration helpers'

  let(:url) { 'https://dispatch.example/p/careful-measurements' }
  let(:paragraphs) do
    [
      'Measurements need context before a reader can compare two observations.',
      'The same method can give different answers when its inputs change.',
      'Keeping the original observations makes later comparisons reproducible.',
      'A short report is still reporting, rather than a directory of other stories.'
    ]
  end

  def short_article_html(extra = '')
    <<~HTML
      <html><head><title>Careful measurements</title>
      <script type="application/ld+json">{"@type":"Article","headline":"Careful measurements","url":"#{url}"}</script>
      </head><body><main><article><h1>Careful measurements</h1>
      <div class="body">#{paragraphs.map { |text| "<p>#{text}</p>" }.join}</div>
      #{extra}</article></main>
      <section class="related-posts">
      <a href="/p/another-observation">Another observation</a>
      <a href="/p/latest-measurements">Latest measurements</a>
      <a href="/p/previous-method">The previous method</a>
      <a href="/p/more-results">More results to compare</a>
      </section></body></html>
    HTML
  end

  it 'retains every short owned paragraph on a commerce-shaped article route' do
    extract_from_url(url, short_article_html) do |payload|
      expect_content_type(payload, 'article')
      paragraphs.each { |text| expect(payload['markdown']).to include(text) }
      expect(payload['markdown']).not_to include('Another observation', 'Latest measurements', 'The previous method')
      expect(Nokogiri::HTML.fragment(payload['html']).css('p').map(&:text)).to eq(paragraphs)
    end
  end

  it 'retains material comments, replies and their inline resources beside the owned report' do
    comments = <<~HTML
      <section id="comments"><div class="comment">
      <p>A reader asks how the <a href="/reference/inputs">original inputs</a> were recorded.</p>
      <div class="reply"><p>The author replies that <code>sample_id</code> identifies each saved observation.</p></div>
      </div></section>
    HTML
    extract_from_url(url, short_article_html(comments)) do |payload|
      expect_content_type(payload, 'article')
      (paragraphs + [
        'A reader asks how the', 'The author replies that', '`sample_id`',
        '[original inputs](https://dispatch.example/reference/inputs)'
      ]).each { |text| expect(payload['markdown']).to include(text) }
      expect(payload['markdown']).not_to include('Another observation', 'More results to compare')
      expect(Nokogiri::HTML.fragment(payload['html']).css('p').map(&:text)).to eq(paragraphs + [
        'A reader asks how the original inputs were recorded.',
        'The author replies that sample_id identifies each saved observation.'
      ])
    end
  end
end
