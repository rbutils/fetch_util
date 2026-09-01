# frozen_string_literal: true

require 'ferrum'

module FetchUtil
  module ExtractorIntegrationResources
    module_function

    def close(configuration)
      page = configuration.instance_variable_get(:@fetch_util_extractor_page)
      begin
        page&.close
      rescue Ferrum::Error
        nil
      ensure
        configuration.remove_instance_variable(:@fetch_util_extractor_page) if page
      end

      browser = configuration.instance_variable_get(:@fetch_util_extractor_browser)
      begin
        browser&.quit
      ensure
        configuration.remove_instance_variable(:@fetch_util_extractor_browser) if browser
      end
    end
  end
end

RSpec.configure do |config|
  config.after(:suite) do
    FetchUtil::ExtractorIntegrationResources.close(RSpec.configuration)
  end
end

RSpec.shared_context 'extractor integration helpers' do
  def fixture_contents(path)
    cache = RSpec.configuration.instance_variable_get(:@fetch_util_fixture_contents) ||
            RSpec.configuration.instance_variable_set(:@fetch_util_fixture_contents, {})
    cache[path] ||= File.read(path)
  end

  def browser_path
    configuration = RSpec.configuration
    if configuration.instance_variable_defined?(:@fetch_util_browser_path)
      return configuration.instance_variable_get(:@fetch_util_browser_path)
    end

    configuration.instance_variable_set(
      :@fetch_util_browser_path,
      ENV["BROWSER_PATH"] || FetchUtil::Browser::BROWSER_CANDIDATES.find { |path| File.executable?(path) }
    )
  end

  def required_browser_path
    path = browser_path
    return path if path

    if ENV["FETCH_UTIL_ALLOW_MISSING_CHROMIUM"] == "1"
      return skip "Chromium not available (FETCH_UTIL_ALLOW_MISSING_CHROMIUM=1)"
    end

    raise "Chromium not available; set FETCH_UTIL_ALLOW_MISSING_CHROMIUM=1 to skip browser integration examples"
  end

  def extractor_browser
    path = required_browser_path

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

  def extractor_page
    extractor_browser
    RSpec.configuration.instance_variable_get(:@fetch_util_extractor_page) ||
      RSpec.configuration.instance_variable_set(
        :@fetch_util_extractor_page,
        begin
          page = extractor_browser.create_page
          page.bypass_csp
          page
        end
      )
  end

  def with_extractor_page
    page = extractor_page
    page.go_to('about:blank')
    yield page
  end

  def with_page(html)
    with_extractor_page do |page|
      page.content = html
      yield page
    end
  end

  def with_url_page(url, html, content_type: 'text/html; charset=UTF-8')
    request_url = url.sub(/#.*/u, '')
    interception_enabled = false

    with_extractor_page do |page|
      page.network.intercept(pattern: '*')
      interception_enabled = true
      handler_id = page.on(:request) do |request|
        if request.url == request_url
          request.respond(
            body: html,
            responseHeaders: { 'content-type' => content_type }
          )
        else
          request.abort
        end
      end

      page.go_to(url)
      yield page
    ensure
      reset_url_interception(page, handler_id, interception_enabled)
    end
  end

  def reset_url_interception(page, handler_id, interception_enabled)
    page&.command('Fetch.disable') if interception_enabled
    page&.off(:request, handler_id) if handler_id
  rescue Ferrum::Error
    cached_page = RSpec.configuration.instance_variable_get(:@fetch_util_extractor_page)
    RSpec.configuration.remove_instance_variable(:@fetch_util_extractor_page) if cached_page.equal?(page)
    begin
      page&.close
    rescue Ferrum::Error
      nil
    end
  end

  def extract(page, reader_mode: true)
    extractor_for(reader_mode).extract(page)
  end

  def extract_payload(page, reader_mode: true)
    extract(page, reader_mode: reader_mode)
  end

  def extractor_for(reader_mode)
    extractors = RSpec.configuration.instance_variable_get(:@fetch_util_extractors) ||
                 RSpec.configuration.instance_variable_set(:@fetch_util_extractors, {})
    extractors[reader_mode] ||= FetchUtil::Extractor.new(reader_mode: reader_mode)
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
  def expect_fixture_article(url:, fixture_path:, content_type: 'article', includes:, excludes:, warning_excludes:, suspect: false, byline: nil, published_time: nil)
    html = fixture_contents(fixture_path)

    extract_from_url(url, html) do |payload|
      expect_content_type(payload, content_type)
      Array(includes).each { |substring| expect(payload['markdown']).to include(substring) }
      Array(excludes).each { |substring| expect(payload['markdown']).not_to include(substring) }
      expect(payload['byline']).to eq(byline) if byline
      expect(payload['publishedTime']).to eq(published_time) if published_time
      expect_warnings(payload, exclude: warning_excludes)
      expect(payload['suspect']).to be(suspect)
    end
  end
  # rubocop:enable Style/KeywordParametersOrder
end
