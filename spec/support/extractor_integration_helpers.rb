# frozen_string_literal: true

require 'ferrum'

RSpec.shared_context 'extractor integration helpers' do
  def browser_path
    FetchUtil::Browser::BROWSER_CANDIDATES.find { |path| File.executable?(path) }
  end

  def with_page(html)
    path = browser_path
    skip 'Chromium not available' unless path

    browser = Ferrum::Browser.new(
      headless: true,
      browser_path: path,
      timeout: 10,
      window_size: [1280, 900],
      browser_options: { 'no-sandbox': nil }
    )
    browser.bypass_csp
    browser.go_to('about:blank')
    browser.content = html
    yield browser
  ensure
    browser&.quit
  end

  def with_url_page(url, html)
    path = browser_path
    skip 'Chromium not available' unless path

    request_url = url.sub(/#.*/u, '')

    browser = Ferrum::Browser.new(
      headless: true,
      browser_path: path,
      timeout: 10,
      window_size: [1280, 900],
      browser_options: { 'no-sandbox': nil }
    )
    browser.bypass_csp
    browser.network.intercept(pattern: '*')
    browser.on(:request) do |request|
      if request.url == request_url
        request.respond(
          body: html,
          responseHeaders: { 'content-type' => 'text/html; charset=UTF-8' }
        )
      else
        request.abort
      end
    end
    browser.go_to(url)
    yield browser
  ensure
    browser&.quit
  end

  def extract(page, reader_mode: true)
    FetchUtil::Extractor.new(reader_mode: reader_mode).extract(page)
  end

  def extract_payload(page, reader_mode: true)
    FetchUtil::Extractor.new(reader_mode: reader_mode).extract(page)
  end

  def expect_warnings(subject, include: [], exclude: [])
    warnings = subject.is_a?(Hash) ? subject["warnings"] : subject.warnings

    expect(warnings).to include(*Array(include)) unless Array(include).empty?
    Array(exclude).each { |warning| expect(warnings).not_to include(warning) }
  end

  def expect_content_type(payload, type)
    expect(payload["contentType"]).to eq(type)
  end

  def extract_from_url(url, html, reader_mode: true, &block)
    with_url_page(url, html) do |page|
      block.call(extract_payload(page, reader_mode: reader_mode))
    end
  end

  # rubocop:disable Style/KeywordParametersOrder -- keep required call shape grouped by assertion order.
  def expect_fixture_article(url:, fixture_path:, content_type: 'article', includes:, excludes:, warning_excludes:, suspect: false)
    html = File.read(fixture_path)

    extract_from_url(url, html) do |payload|
      expect_content_type(payload, content_type)
      Array(includes).each { |substring| expect(payload['markdown']).to include(substring) }
      Array(excludes).each { |substring| expect(payload['markdown']).not_to include(substring) }
      expect_warnings(payload, exclude: warning_excludes)
      expect(payload['suspect']).to be(suspect)
    end
  end
  # rubocop:enable Style/KeywordParametersOrder
end
