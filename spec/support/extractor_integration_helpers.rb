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
end
