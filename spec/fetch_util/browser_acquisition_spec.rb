# frozen_string_literal: true

require "spec_helper"

RSpec.describe FetchUtil::Browser do
  def with_server
    server = LocalAcquisitionServer.new
    yield server
  ensure
    server&.close
  end

  def with_browser(**options)
    browser_path = ENV["BROWSER_PATH"] || described_class::BROWSER_CANDIDATES.find { |path| File.executable?(path) }
    unless browser_path && File.executable?(browser_path)
      skip "Chromium is unavailable by explicit opt-in" if ENV["FETCH_UTIL_ALLOW_MISSING_CHROMIUM"] == "1"

      raise "Chromium is required; set FETCH_UTIL_ALLOW_MISSING_CHROMIUM=1 only for explicitly limited environments"
    end

    browser = described_class.new(
      browser_path: browser_path, timeout: 3, wait: 0.2, wait_for_idle: false, **options
    )
    yield browser
  ensure
    browser&.quit
  end

  it "follows a local redirect and waits for its hydrated body" do
    with_server do |server|
      with_browser do |browser|
        browser.with_page(server.url("/redirect")) do |page|
          expect(page.current_url).to eq(server.url("/hydrated"))
          expect(page.evaluate("document.querySelector('#hydrated').textContent")).to eq("hydrated body")
        end
      end
    end
  end

  it "stabilizes substantive content while a background request remains open" do
    with_server do |server|
      with_browser(wait_for_idle: true, idle_duration: 0.08, wait: 0) do |browser|
        browser.with_page(server.url("/persistent")) do |page|
          expect(page.evaluate("document.body.innerText").length).to be > FetchUtil::Browser::CONTENT_READY_MIN_LENGTH
          expect(server.wait_for_request("/pending").path).to eq("/pending")

          background_request = page.network.traffic.find { |exchange| exchange.url == server.url("/pending") }
          expect(background_request).not_to be_nil
          expect(background_request).to be_pending
        end
      end
    end
  end

  it "recovers on the next URL after a local navigation disconnect" do
    with_server do |server|
      with_browser do |browser|
        expect { browser.with_page(server.url("/drop")) {} }.to raise_error(FetchUtil::BrowserError)

        text = browser.with_page(server.url("/recovery")) { |page| page.evaluate("document.querySelector('main').textContent") }
        expect(text).to eq("recovered")
      end
    end
  end

  it "retains cookies across fresh pages in one owned browser but not another" do
    with_server do |server|
      with_browser do |browser|
        browser.with_page(server.url("/set-cookie")) { |_page| }
        browser.with_page(server.url("/echo-cookie")) { |page| expect(page.evaluate("document.body.innerText")).to include("local_session=kept") }
        expect(server.wait_for_request("/echo-cookie").headers.fetch("cookie")).to include("local_session=kept")
      end

      with_browser do |separate_browser|
        separate_browser.with_page(server.url("/echo-cookie")) { |page| expect(page.evaluate("document.body.innerText")).to be_empty }
        expect(server.wait_for_request("/echo-cookie").headers.fetch("cookie", "")).not_to include("local_session=kept")
      end
    end
  end
end
