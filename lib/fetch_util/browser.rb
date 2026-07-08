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
    NAVIGATION_MAX_RETRIES = 2
    NAVIGATION_RETRY_WAIT = 0.5
    NAVIGATION_RETRY_PATTERN = Regexp.new(
      "pending connections|ERR_NAME_NOT_RESOLVED|DNS|resolve|resolution|ENOTFOUND|" \
      "EAI_AGAIN|ECONNREFUSED|ECONNRESET|ETIMEDOUT|timed out|timeout|" \
      "connection (?:refused|reset|closed)|disconnected|network",
      Regexp::IGNORECASE
    ).freeze

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
      @default_headers = {
        "User-Agent" => @user_agent,
        "Accept-Language" => @accept_language
      }.freeze
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
      @navigator_patch = build_navigator_patch
      @ferrum = nil
      @mutex = Mutex.new
    end

    # Navigate to +url+ in a fresh browser tab, stabilize the page, then yield
    # the +Ferrum::Page+ to the caller. The page is closed after the block
    # returns (or on error), but the underlying Chromium process is kept alive
    # for reuse by subsequent calls.
    def with_page(url)
      raise BrowserError, "No Chromium browser found. Set BROWSER_PATH or install Chromium." unless @browser_path

      ferrum = ensure_browser
      page = ferrum.create_page
      page.headers.set(@default_headers)
      page.bypass_csp
      retries = 0
      begin
        page.go_to(url)
      rescue Ferrum::PendingConnectionsError, Ferrum::TimeoutError, Ferrum::Error => e
        raise unless retryable_navigation_error?(e)

        unless page_loaded_enough?(page)
          raise if retries >= NAVIGATION_MAX_RETRIES

          retries += 1
          sleep NAVIGATION_RETRY_WAIT
          retry
        end
      end
      stabilize_page(page, url)
      yield page
    rescue Ferrum::Error => e
      raise BrowserError, e.message
    ensure
      page&.close
    end

    # Shut down the underlying Chromium process. Safe to call multiple times or
    # when no browser has been started yet. After +quit+, a subsequent
    # +with_page+ call will transparently launch a new process.
    def quit
      @mutex.synchronize do
        @ferrum&.quit
        @ferrum = nil
      end
    end

    private

    # Lazily start the shared Chromium process on first use. The
    # +evaluate_on_new_document+ call registers the navigator patch once;
    # Ferrum automatically applies it to every new page/context created
    # afterwards.
    def ensure_browser
      @mutex.synchronize do
        return @ferrum if @ferrum

        @ferrum = Ferrum::Browser.new(
          headless: true,
          browser_path: @browser_path,
          timeout: @timeout,
          window_size: [@viewport.fetch(:width), @viewport.fetch(:height)],
          browser_options: @browser_options
        )
        @ferrum.evaluate_on_new_document(navigator_patch)
        @ferrum
      end
    end

    def host_matches?(url, host)
      normalized_host = FetchUtil.strip_www_host(url)
      normalized_host == host || normalized_host.end_with?(".#{host}")
    end

    def retryable_navigation_error?(error)
      error.message.to_s.match?(NAVIGATION_RETRY_PATTERN)
    end
  end
end
