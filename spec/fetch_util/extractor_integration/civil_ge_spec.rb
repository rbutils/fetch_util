# frozen_string_literal: true

require 'nokogiri'
require 'uri'

RSpec.describe 'FetchUtil Civil.ge extractor integration' do
  include_context 'extractor integration helpers'

  it 'extracts Civil.ge article bodies instead of sidebar lists' do
    # The shared article shell retains source-owned header and taxonomy context.
    expect_fixture_article(
      url: 'https://civil.ge/archives/743770',
      fixture_path: File.expand_path('../../fixtures/civil_ge_article.html', __dir__),
      includes: [
        'Giorgi Bakhuashvili, Deputy Head of SSSG. Photo: MIA',
        '[News](https://civil.ge/archives/category/news)',
        '[Civil.ge](https://civil.ge/archives/author/wpadmin',
        '1 minute read',
        'Giorgi Bakhuashvili, who reportedly served as a personal bodyguard',
        'According to RFE/RL’s Georgian Service',
        '[SSSG](https://civil.ge/archives/tag/sssg)'
      ],
      excludes: [
        'Home / News / Security', 'Facebook X LinkedIn Print', 'URL Copied',
        'Duplicate article metadata', 'MFA’s Newly Created Diplomatic Academy', 'Read Next'
      ],
      warning_excludes: %w[empty_extraction short_extraction url_content_mismatch consent_interstitial]
    )
  end

  it 'retains the same owned metadata and every tag on an unconfigured article shell' do
    path = File.expand_path('../../fixtures/civil_ge_article.html', __dir__)
    html = fixture_contents(path).gsub('https://civil.ge', 'https://journal.example.test').gsub('Civil.ge', 'Ada Reporter')
    tags = (1..20).map { |index| "<a rel='tag' href='/tag/topic-#{index}'>Topic #{index}</a>" }.join
    html = html.sub('Tags', "Tags #{tags}<a hidden href='/tag/hidden'>Hidden taxonomy</a>")
    source = Nokogiri::HTML(html)
    paragraphs = source.css('.entry-content p').map { |node| node.text.strip }
    links = source.css('.entry-header a, .post-bottom-tags a:not([hidden])').map { |node| [node.text.strip, URI.join('https://journal.example.test/', node['href']).to_s] }

    with_url_page('https://journal.example.test/reports/security', html) do |page|
      before = page.evaluate('document.body.innerHTML')
      payload = extract_payload(page)
      extracted = Nokogiri::HTML.fragment(payload.fetch('html'))
      expect(extracted.css('.entry-content p').map { |node| node.text.strip }).to eq(paragraphs)
      expect(extracted.css('a[href]').map { |node| [node.text.strip, node['href']] }).to eq(links)
      expect(payload['markdown']).to include('1 minute read', '07/07/2026 - 15:49', 'Photo: MIA')
      expect(payload['markdown']).not_to include('Duplicate article metadata', 'URL Copied', 'Read Next', 'Home / News / Security', 'Hidden taxonomy')
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
      expect_content_type(payload, 'article')
    end
  end
end
