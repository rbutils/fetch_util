# frozen_string_literal: true

require 'nokogiri'

RSpec.describe 'FetchUtil Khaosod extractor integration' do
  include_context 'extractor integration helpers'

  it 'does not guess an undeclared REST endpoint from the legacy news URL' do
    html = fixture_contents(File.expand_path('../fixtures/khaosod_article.html', __dir__))
    rest_json = fixture_contents(File.expand_path('../fixtures/khaosod_article_rest.json', __dir__))
    url = 'https://www.khaosod.co.th/breaking-news/news_10314048'
    rest_url = 'https://www.khaosod.co.th/wp-json/wp/v2/posts/10314048'
    requests = []

    path = required_browser_path

    browser = Ferrum::Browser.new(
      headless: true,
      browser_path: path,
      timeout: 10,
      window_size: [1280, 900],
      browser_options: { 'no-sandbox': nil }
    )
    page = browser.create_page
    page.bypass_csp
    page.network.intercept(pattern: '*')
    page.on(:request) do |request|
      requests << request.url
      case request.url
      when url
        request.respond(body: html, responseHeaders: { 'content-type' => 'text/html; charset=UTF-8' })
      when rest_url
        request.respond(body: rest_json, responseHeaders: { 'content-type' => 'application/json; charset=UTF-8' })
      else
        request.abort
      end
    end

    page.go_to(url)
    payload = extract_payload(page)

    expect(requests).not_to include(rest_url)
    expect(payload['markdown']).not_to include('เมื่อเวลา 14.00 น. วันที่ 7 ก.ค.2569')
  ensure
    page&.close
    browser&.quit
  end

  it 'preserves complete visible reporting, caption and media without the host fallback' do
    html = fixture_contents(File.expand_path('../../fixtures/khaosod_visible_article.html', __dir__))
    source = Nokogiri::HTML(html, nil, 'UTF-8')
    paragraphs = source.css('[itemprop="articleBody"] p').map { |node| node.text.strip }
    url = 'https://www.khaosod.co.th/breaking-news/news_10314048'
    with_url_page(url, html) do |page|
      before = page.evaluate('document.body.innerHTML')
      payload = extract_payload(page)
      result = Nokogiri::HTML(payload.fetch('html'), nil, 'UTF-8')
      extracted = result.css('p').map { |node| node.text.strip }
      positions = paragraphs.map { |text| extracted.index(text) }
      expect(positions).to all(be_a(Integer))
      expect(positions).to eq(positions.sort)
      paragraphs.each { |text| expect(payload.fetch('markdown')).to include(text) }
      expect(result.at_css('img')['src']).to eq(source.at_css('img')['src'])
      expect(result.text).to include(source.at_css('.udsg__featured-image-caption').text)
      expect(payload['title']).to eq(source.at_css('h1').text)
      expect(payload['publishedTime']).to eq('2026-07-07T07:36:57+00:00')
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end

  it 'preserves owned featured media and captions on a pingback-only unknown host' do
    html = <<~HTML
      <!doctype html><title>Independent source report</title>
      <link rel="pingback" href="https://independent.example/engine/xmlrpc.php">
      <main><article><h1>Independent source report</h1>
      <div class="theme-featured-image-wrap"><img src="/report.jpg" alt="Independent report"></div>
      <p class="theme-caption">The photographer documented the original source.</p>
      <aside><div class="theme-featured-image-wrap"><img src="/unrelated.jpg" alt="Other story"></div></aside>
      <div itemprop="articleBody">
      <p>This independent report gives a complete account of the observations made during the original investigation.</p>
      <p>The authors then describe their evidence, its limitations and the further questions that remain open for readers.</p>
      </div></article></main>
    HTML
    with_url_page('https://independent.example/report', html) do |page|
      payload = extract_payload(page)
      document = Nokogiri::HTML(payload.fetch('html'), nil, 'UTF-8')
      expect(document.css('img').map { |image| image['src'] }).to eq(['https://independent.example/report.jpg'])
      expect(document.text).to include('The photographer documented the original source.', 'further questions that remain open')
      expect(payload['title']).to eq('Independent source report')
    end
  end
end
