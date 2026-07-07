# frozen_string_literal: true

RSpec.describe 'FetchUtil Khaosod extractor integration' do
  include_context 'extractor integration helpers'

  it 'extracts Khaosod article bodies from public WordPress REST content without cookie or sponsored chrome' do
    html = File.read(File.expand_path('../fixtures/khaosod_article.html', __dir__))
    rest_json = File.read(File.expand_path('../fixtures/khaosod_article_rest.json', __dir__))
    url = 'https://www.khaosod.co.th/breaking-news/news_10314048'
    rest_url = 'https://www.khaosod.co.th/wp-json/wp/v2/posts/10314048'

    path = browser_path
    skip 'Chromium not available' unless path

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

    expect_content_type(payload, 'article')
    expect(payload['markdown']).to include('เมื่อเวลา 14.00 น. วันที่ 7 ก.ค.2569')
    expect(payload['markdown']).to include('นายพงษ์สวาท นีละโยธิน ปลัดกระทรวง กระทรวงยุติธรรม')
    expect(payload['markdown']).not_to include('เว็บไซต์นี้ใช้คุ้กกี้')
    expect(payload['markdown']).not_to include('Sponsored teaser should not leak')
    expect_warnings(payload, exclude: %w[empty_extraction short_extraction url_content_mismatch consent_interstitial])
  ensure
    page&.close
    browser&.quit
  end
end
