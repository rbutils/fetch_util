# frozen_string_literal: true

require 'ferrum'

RSpec.configure do |config|
  config.after(:suite) do
    browser = RSpec.configuration.instance_variable_get(:@fetch_util_extractor_browser)
    browser&.quit
    RSpec.configuration.remove_instance_variable(:@fetch_util_extractor_browser) if browser
  end
end

RSpec.shared_context 'extractor integration helpers' do
  def browser_path
    FetchUtil::Browser::BROWSER_CANDIDATES.find { |path| File.executable?(path) }
  end

  def extractor_browser
    path = browser_path
    skip 'Chromium not available' unless path

    RSpec.configuration.instance_variable_get(:@fetch_util_extractor_browser) ||
      RSpec.configuration.instance_variable_set(
        :@fetch_util_extractor_browser,
        Ferrum::Browser.new(
          headless: true,
          browser_path: path,
          timeout: 10,
          window_size: [1280, 900],
          browser_options: { 'no-sandbox': nil }
        )
      )
  end

  def with_extractor_page
    page = extractor_browser.create_page
    page.bypass_csp
    yield page
  ensure
    page&.close
  end

  def with_page(html)
    with_extractor_page do |page|
      page.go_to('about:blank')
      page.content = html
      yield page
    end
  end

  def with_url_page(url, html)
    request_url = url.sub(/#.*/u, '')

    with_extractor_page do |page|
      page.network.intercept(pattern: '*')
      page.on(:request) do |request|
        if request.url == request_url
          request.respond(
            body: html,
            responseHeaders: { 'content-type' => 'text/html; charset=UTF-8' }
          )
        else
          request.abort
        end
      end

      page.go_to(url)
      yield page
    end
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
