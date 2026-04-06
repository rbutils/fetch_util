# frozen_string_literal: true

require "ferrum"
require "json"
require "uri"

module FetchUtil
  class Browser
    autoload :InteractionHelpers, "fetch_util/browser/interaction_helpers"
    autoload :Navigation, "fetch_util/browser/navigation"
    autoload :SiteStabilization, "fetch_util/browser/site_stabilization"
    autoload :Stabilization, "fetch_util/browser/stabilization"

    include InteractionHelpers
    include Navigation
    include SiteStabilization
    include Stabilization

    # Prefer full Chromium over `headless_shell`: the full browser stays closer
    # to standard Chromium behavior and exposes APIs that some sites expect,
    # which improves extraction consistency. `headless_shell` diverges more
    # often and can change page behavior in ways that degrade extraction.
    BROWSER_CANDIDATES = [
      "/usr/bin/chromium-browser",
      "/usr/bin/chromium",
      "/usr/bin/google-chrome",
      "/usr/lib64/chromium-browser/headless_shell"
    ].freeze

    DEFAULT_VIEWPORT = { width: 1366, height: 900 }.freeze
    DEFAULT_USER_AGENT = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 " \
                         "(KHTML, like Gecko) Chrome/136.0.0.0 Safari/537.36"
    DEFAULT_ACCEPT_LANGUAGE = "en-US,en;q=0.9"
    SOCIAL_LOGIN_PHASE_WAIT = 0.3
    POST_CONSENT_IDLE_TIMEOUT = 3.0
    CONTENT_READY_MIN_LENGTH = 200
    SPA_HYDRATION_TIMEOUT = 2.0
    SPA_HYDRATION_POLL = 0.15

    def initialize(timeout: 20, wait: 0.75, wait_for_idle: true, idle_duration: 0.35,
                   viewport: DEFAULT_VIEWPORT, user_agent: DEFAULT_USER_AGENT,
                   accept_language: DEFAULT_ACCEPT_LANGUAGE, browser_path: nil,
                   browser_options: nil)
      @timeout = timeout.to_f
      @wait = wait.to_f
      @wait_for_idle = wait_for_idle
      @idle_duration = idle_duration.to_f
      @viewport = DEFAULT_VIEWPORT.merge(symbolize_hash(viewport || {}))
      @user_agent = user_agent
      @accept_language = accept_language
      @browser_path = browser_path || ENV["BROWSER_PATH"] || BROWSER_CANDIDATES.find { |path| File.executable?(path) }
      @full_browser = @browser_path && !@browser_path.include?("headless_shell")
      default_opts = { "no-sandbox": nil }
      # Use newer headless mode with the full browser binary for closer runtime
      # parity with standard Chromium. Also disable Ferrum's
      # `enable-automation` flag to reduce tool-specific browser-state
      # differences during extraction.
      if @full_browser
        default_opts["headless"] = "new"
        default_opts["enable-automation"] = false # override Ferrum default
      end
      @browser_options = default_opts.merge(browser_options || {})
    end

    def with_page(url)
      raise BrowserError, "No Chromium browser found. Set BROWSER_PATH or install Chromium." unless @browser_path

      browser = Ferrum::Browser.new(
        headless: true,
        browser_path: @browser_path,
        timeout: @timeout,
        window_size: [@viewport.fetch(:width), @viewport.fetch(:height)],
        browser_options: @browser_options
      )
      browser.evaluate_on_new_document(navigator_patch)
      browser.headers.set(default_headers)
      browser.bypass_csp
      begin
        browser.go_to(url)
      rescue Ferrum::PendingConnectionsError, Ferrum::TimeoutError
        raise unless page_loaded_enough?(browser)
      end
      stabilize_page(browser, url)
      yield browser
    rescue Ferrum::Error => e
      raise BrowserError, e.message
    ensure
      browser&.quit
    end
  end
end
