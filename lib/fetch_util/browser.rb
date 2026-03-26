# frozen_string_literal: true

require "ferrum"
require "json"
require "uri"

module FetchUtil
  class Browser
    # Prefer full Chromium over headless_shell — the full binary supports
    # --headless=new (Chrome 112+) which runs the real browser engine headlessly,
    # making bot detection significantly harder.  headless_shell is the old
    # headless-only binary that sites like Instagram easily fingerprint.
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
      # Use new headless mode with the full browser binary — it runs the real
      # browser engine headlessly, avoiding most bot detection.  Also disable
      # the enable-automation flag that Ferrum adds by default.
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

    private

    def default_headers
      {
        "User-Agent" => @user_agent,
        "Accept-Language" => @accept_language
      }
    end

    def page_loaded_enough?(page)
      page.evaluate(<<~JS)
        (() => !!(document && document.body && (document.body.innerText || document.body.textContent || '').trim().length > 0))()
      JS
    rescue Ferrum::JavaScriptError, Ferrum::TimeoutError
      false
    end

    def navigator_patch
      ua_version = @user_agent[%r{Chrome/([\d.]+)}, 1] || "136.0.7103.113"
      major = ua_version.split(".").first
      languages_json = JSON.generate(@accept_language.split(",").map { |part| part.split(";").first.strip })
      <<~JS
        // Core webdriver / language / platform cloaking
        Object.defineProperty(navigator, "webdriver", { get: () => undefined });
        Object.defineProperty(navigator, "languages", { get: () => #{languages_json} });
        Object.defineProperty(navigator, "platform", { get: () => "Linux x86_64" });

        // Plugins — headless Chrome has zero plugins; real Chrome has PDF Viewer etc.
        Object.defineProperty(navigator, "plugins", {
          get: () => {
            const p = { 0: { name: "PDF Viewer", filename: "internal-pdf-viewer", description: "Portable Document Format" },
                        1: { name: "Chrome PDF Viewer", filename: "internal-pdf-viewer", description: "Portable Document Format" },
                        2: { name: "Chromium PDF Viewer", filename: "internal-pdf-viewer", description: "Portable Document Format" },
                        length: 3 };
            p[Symbol.iterator] = function*() { yield p[0]; yield p[1]; yield p[2]; };
            return p;
          }
        });
        Object.defineProperty(navigator, "mimeTypes", {
          get: () => {
            const m = { 0: { type: "application/pdf", suffixes: "pdf", description: "Portable Document Format" },
                        length: 1 };
            m[Symbol.iterator] = function*() { yield m[0]; };
            return m;
          }
        });

        // window.chrome stub (missing in headless_shell)
        if (!window.chrome) {
          window.chrome = { runtime: {}, loadTimes: function(){}, csi: function(){} };
        }

        // Permissions API — headless instantly resolves "denied" for notifications;
        // real Chrome returns "prompt"
        const origQuery = window.Permissions && Permissions.prototype.query;
        if (origQuery) {
          Permissions.prototype.query = function(parameters) {
            return parameters.name === "notifications"
              ? Promise.resolve({ state: Notification.permission })
              : origQuery.call(this, parameters);
          };
        }

        // Hardware concurrency — servers often expose 32+ cores; cap to desktop-normal
        Object.defineProperty(navigator, "hardwareConcurrency", { get: () => 4 });

        // Device memory (missing in headless_shell, present in real Chrome)
        if (!navigator.deviceMemory) {
          Object.defineProperty(navigator, "deviceMemory", { get: () => 8 });
        }

        // Connection API stub (missing in some headless configs)
        if (!navigator.connection) {
          Object.defineProperty(navigator, "connection", {
            get: () => ({ effectiveType: "4g", rtt: 50, downlink: 10, saveData: false })
          });
        }

        // User-Agent Client Hints API (navigator.userAgentData) — missing in headless_shell
        {
          const uaData = navigator.userAgentData;
          const missingUserAgentData = !uaData || !Array.isArray(uaData.brands) || uaData.brands.length === 0 || !uaData.platform;
          if (missingUserAgentData) {
          Object.defineProperty(navigator, "userAgentData", {
            get: () => ({
              brands: [
                { brand: "Chromium", version: "#{major}" },
                { brand: "Google Chrome", version: "#{major}" },
                { brand: "Not.A/Brand", version: "24" }
              ],
              mobile: false,
              platform: "Linux",
              getHighEntropyValues: function(hints) {
                return Promise.resolve({
                  architecture: "x86",
                  bitness: "64",
                  brands: this.brands,
                  fullVersionList: [
                    { brand: "Chromium", version: "#{ua_version}" },
                    { brand: "Google Chrome", version: "#{ua_version}" }
                  ],
                  mobile: false,
                  model: "",
                  platform: "Linux",
                  platformVersion: "6.1.0",
                  uaFullVersion: "#{ua_version}"
                });
              }
            })
          });
        }
        }

        // WebGL renderer masking — hide SwiftShader (software renderer = headless signal)
        {
          const getParameterProto = WebGLRenderingContext.prototype.getParameter;
          WebGLRenderingContext.prototype.getParameter = function(param) {
            const debugExt = this.getExtension('WEBGL_debug_renderer_info');
            if (debugExt) {
              if (param === debugExt.UNMASKED_VENDOR_WEBGL) return 'Google Inc. (Intel)';
              if (param === debugExt.UNMASKED_RENDERER_WEBGL)
                return 'ANGLE (Intel, Mesa Intel(R) UHD Graphics 630 (CFL GT2), OpenGL 4.6)';
            }
            return getParameterProto.call(this, param);
          };
        }

        // Screen dimensions — headless defaults to 800x600 screen which is smaller
        // than typical window sizes, an obvious detection vector.
        Object.defineProperty(screen, "width", { get: () => #{@viewport.fetch(:width)} });
        Object.defineProperty(screen, "height", { get: () => #{@viewport.fetch(:height)} });
        Object.defineProperty(screen, "availWidth", { get: () => #{@viewport.fetch(:width)} });
        Object.defineProperty(screen, "availHeight", { get: () => #{@viewport.fetch(:height)} });
      JS
    end

    POST_CONSENT_IDLE_TIMEOUT = 3.0
    CONTENT_READY_MIN_LENGTH = 200
    SPA_HYDRATION_TIMEOUT = 2.0
    SPA_HYDRATION_POLL = 0.15

    def stabilize_page(page, url)
      return stabilize_reddit(page) if reddit_url?(url)
      return stabilize_instagram(page) if instagram_url?(url)
      return stabilize_facebook(page) if facebook_url?(url)
      return stabilize_ebay_search(page) if ebay_search_url?(url)

      reached_idle = !@wait_for_idle || wait_for_idle_or_content(page)
      preserve_consent = preserve_consent_wall?(page, url)
      accepted_cookies = preserve_consent ? false : accept_cookie_consent(page)
      accepted_cookies = (!preserve_consent && dismiss_privacy_preference_overlay(page)) || accepted_cookies
      sleep @wait if @wait.positive?
      accepted_cookies = (!preserve_consent && accept_cookie_consent(page)) || accepted_cookies
      accepted_cookies = (!preserve_consent && dismiss_privacy_preference_overlay(page)) || accepted_cookies

      # Wait for SPA framework hydration when a framework is detected
      wait_for_spa_hydration(page) if @wait_for_idle && reached_idle
      accepted_cookies = (!preserve_consent && accept_cookie_consent(page)) || accepted_cookies
      accepted_cookies = (!preserve_consent && dismiss_privacy_preference_overlay(page)) || accepted_cookies

      return unless accepted_cookies && @wait_for_idle && reached_idle

      page.network.wait_for_idle(duration: @idle_duration, timeout: POST_CONSENT_IDLE_TIMEOUT)
    end

    def wait_for_idle_or_content(page)
      content_seen_at = nil

      retry_until_timeout(@timeout, interval: @idle_duration) do
        now = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        next true if page.network.idle?
        if content_seen_at.nil? && page_has_content?(page)
          content_seen_at = now
        end

        content_seen_at && (now - content_seen_at) >= @idle_duration
      end
    rescue Ferrum::Error
      false
    end

    def page_has_content?(page)
      page.evaluate(<<~JS)
        (() => {
          const body = document.body;
          if (!body) return false;
          const text = body.innerText || '';
          return text.length > #{CONTENT_READY_MIN_LENGTH};
        })()
      JS
    rescue Ferrum::JavaScriptError, Ferrum::TimeoutError
      false
    end

    # Detect SPA framework and wait for hydration to complete.
    # Polls for framework-specific signals that indicate the app has finished
    # mounting/hydrating, then gives a brief grace period for post-hydration rendering.
    def wait_for_spa_hydration(page)
      framework = detect_spa_framework(page)
      return unless framework

      retry_until_timeout(SPA_HYDRATION_TIMEOUT, interval: SPA_HYDRATION_POLL) do
        spa_hydration_complete?(page, framework)
      end

      # Brief grace after hydration for any post-hydration rendering (lazy components, etc.)
      sleep SPA_HYDRATION_POLL
    rescue Ferrum::JavaScriptError, Ferrum::TimeoutError
      # Best-effort — don't fail the fetch if hydration detection errors
    end

    # Detect which SPA framework is running on the page.
    # Returns a symbol (:react, :next, :vue, :nuxt, :angular, :svelte, :ember,
    # :remix, :qwik, :gatsby, :docusaurus, :generic_spa) or nil if no SPA detected.
    def detect_spa_framework(page)
      result = page.evaluate(<<~JS)
        (() => {
          // Next.js (check before generic React since Next uses React)
          if (window.__NEXT_DATA__ || (window.next && window.next.version)) return 'next';

          // Nuxt (check before Vue since Nuxt uses Vue)
          if (window.__NUXT__ || window.$nuxt) return 'nuxt';

          // Remix (check before generic React since Remix uses React)
          if (window.__remixContext) return 'remix';

          // Docusaurus (check before generic React)
          if (document.getElementById('__docusaurus')) return 'docusaurus';

          // Gatsby (check before generic React)
          if (document.getElementById('___gatsby')) return 'gatsby';

          // Vue 3
          const vueMount = document.querySelector('#app, #root, #__nuxt');
          if ((vueMount && vueMount.__vue_app__) || window.__VUE__) return 'vue';

          // Vue 2
          if (vueMount && vueMount.__vue__) return 'vue';

          // Angular
          if (document.querySelector('[ng-version]')) return 'angular';

          // Svelte / SvelteKit
          if (window.__svelte || document.getElementById('svelte-announcer') ||
              document.querySelector('[data-sveltekit-preload-data]') ||
              document.querySelector('[class*="svelte-"]')) return 'svelte';

          // Ember
          if (window.Ember) return 'ember';

          // Qwik
          if (document.querySelector('[q\\\\:container]')) return 'qwik';

          // Mintlify docs platform (React SPA, renders content asynchronously into #content-area)
          if (document.querySelector('meta[name="generator"][content*="Mintlify" i]') || document.querySelector('#content-area')) {
            const gen = (document.querySelector('meta[name="generator"]') || {}).content || '';
            if (/mintlify/i.test(gen) || document.querySelector('[class*="mintlify"]')) return 'mintlify';
          }

          // GitBook docs platform (React SPA, renders content asynchronously)
          {
            const gen = (document.querySelector('meta[name="generator"]') || {}).content || '';
            if (/gitbook/i.test(gen) || /\.gitbook\.io$/.test(location.hostname)) return 'gitbook';
          }

          // Scalar OpenAPI viewer (renders API reference asynchronously)
          if (document.querySelector('.scalar-api-reference, .scalar-app, [data-scalar]')) return 'scalar';

          // Redoc / OpenAPI spec viewer (renders asynchronously from spec-url)
          if (document.querySelector('redoc, rapi-doc, .redoc-wrap')) return 'redoc';

          // ReadMe.io docs platform (React SPA, renders article content asynchronously)
          if (document.querySelector('meta[name="readme-deploy"]') || document.querySelector('.rm-Article, .rm-LandingPage, .rm-ReferenceMain')) return 'readme';

          // Generic React (last — many frameworks use React internally)
          const reactCandidates = document.querySelectorAll('#root, #app, #__next, [data-reactroot], body > div');
          for (const el of reactCandidates) {
            if (el._reactRootContainer || Object.keys(el).some(k => k.startsWith('__reactContainer$'))) return 'react';
          }

          // Generic SPA mount point with minimal content
          const mounts = document.querySelectorAll('#root, #app, [data-reactroot]');
          if (mounts.length > 0) {
            const bodyText = (document.body.innerText || '').trim();
            if (bodyText.length < 500) return 'generic_spa';
          }

          return null;
        })()
      JS

      result.is_a?(String) ? result.to_sym : nil
    rescue Ferrum::JavaScriptError, Ferrum::TimeoutError
      nil
    end

    # Check if SPA hydration is complete for the detected framework.
    def spa_hydration_complete?(page, framework)
      page.evaluate(<<~JS)
        (() => {
          const mainContent = document.querySelector('main, [role="main"], article, .content, .docs-content, #content');
          const mainText = (mainContent ? mainContent.innerText : document.body.innerText || '').trim();

          // Content-based fallback: if main area has substantial text, hydration is done
          if (mainText.length > 500) return true;

          switch ('#{framework}') {
            case 'next': {
              // Next.js Pages Router: __NEXT_DATA__ exists + React fiber on mount
              const mount = document.getElementById('__next');
              if (mount && Object.keys(mount).some(k => k.startsWith('__reactFiber$'))) return true;
              // Next.js App Router: next.version set + React fiber on body children
              if (window.next && window.next.version) {
                const bodyKids = document.body.children;
                for (let i = 0; i < bodyKids.length; i++) {
                  if (Object.keys(bodyKids[i]).some(k => k.startsWith('__reactFiber$'))) return true;
                }
              }
              return false;
            }
            case 'nuxt': {
              const mount = document.getElementById('__nuxt');
              return !!(mount && mount.__vue_app__ && mount.__vue_app__._instance);
            }
            case 'vue': {
              const mount = document.querySelector('#app, #root');
              return !!(mount && (mount.__vue_app__ ? mount.__vue_app__._instance : mount.__vue__));
            }
            case 'react': {
              const candidates = document.querySelectorAll('#root, #app, [data-reactroot], body > div');
              for (const el of candidates) {
                if (Object.keys(el).some(k => k.startsWith('__reactFiber$'))) return true;
              }
              return false;
            }
            case 'angular': {
              // Angular SSR adds ngh attributes during SSR, removes them after hydration
              const hasNgh = document.querySelectorAll('[ngh]').length > 0;
              if (hasNgh) return false; // still hydrating
              return !!document.querySelector('[ng-version]');
            }
            case 'svelte': {
              // SvelteKit injects announcer after hydration
              return !!document.getElementById('svelte-announcer') ||
                     !!document.querySelector('[class*="svelte-"]');
            }
            case 'remix': {
              // Remix hydrates React — check for fiber on root
              const candidates = document.querySelectorAll('#root, #app, body > div');
              for (const el of candidates) {
                if (Object.keys(el).some(k => k.startsWith('__reactFiber$'))) return true;
              }
              return !!window.__remixContext;
            }
            case 'ember': {
              return !!window.Ember && !!document.querySelector('.ember-view');
            }
            case 'qwik': {
              // Qwik uses resumability — container is interactive once q:container exists
              return !!document.querySelector('[q\\\\:container]');
            }
            case 'mintlify': {
              // Mintlify renders content into #content-area asynchronously
              const contentArea = document.querySelector('#content-area, [id="content-area"]');
              if (contentArea && (contentArea.innerText || '').trim().length > 100) return true;
              return false;
            }
            case 'gitbook': {
              // GitBook renders content into main asynchronously
              const gbMain = document.querySelector('main');
              if (gbMain && (gbMain.innerText || '').trim().length > 100) return true;
              return false;
            }
            case 'scalar': {
              // Scalar renders OpenAPI reference asynchronously
              const scalarRef = document.querySelector('.scalar-api-reference, .scalar-app');
              if (scalarRef && (scalarRef.innerText || '').trim().length > 500) return true;
              return false;
            }
            case 'redoc': {
              // Redoc renders API content asynchronously from spec-url
              const apiContent = document.querySelector('.api-content, .redoc-wrap [role="main"], .redoc-wrap');
              if (apiContent && (apiContent.innerText || '').trim().length > 500) return true;
              return false;
            }
            case 'readme': {
              // ReadMe.io renders content into .rm-Article or .rm-LandingPage
              const rmArticle = document.querySelector('.rm-Article, .rm-LandingPage, article .markdown-body');
              if (rmArticle && (rmArticle.innerText || '').trim().length > 100) return true;
              return false;
            }
            case 'gatsby':
            case 'docusaurus': {
              // SSG frameworks — content should be in the HTML already
              // Just check React fiber is attached
              const mountId = '#{framework}' === 'gatsby' ? '___gatsby' : '__docusaurus';
              const mount = document.getElementById(mountId);
              return !!(mount && Object.keys(mount).some(k => k.startsWith('__reactFiber$')));
            }
            case 'generic_spa': {
              return mainText.length > 200;
            }
            default:
              return true;
          }
        })()
      JS
    rescue Ferrum::JavaScriptError, Ferrum::TimeoutError
      true # Assume complete on error to avoid infinite waiting
    end

    def reddit_url?(url)
      host = URI.parse(url).host.to_s.downcase
      host == "reddit.com" || host.end_with?(".reddit.com")
    rescue URI::InvalidURIError
      false
    end

    def stabilize_reddit(page)
      retry_until_timeout(capped_timeout(3.0), interval: 0.1) do
        dismiss_reddit_cookie_dialog(page)
        reddit_content_ready?(page)
      end

      settle_after_stabilization(0.25)
      dismiss_reddit_cookie_dialog(page)
    end

    def ebay_search_url?(url)
      uri = URI.parse(url)
      host = uri.host.to_s.downcase
      return false unless host == "ebay.com" || host.end_with?(".ebay.com")

      uri.path.include?("/sch/") || uri.query.to_s.include?("_nkw=")
    rescue URI::InvalidURIError
      false
    end

    def stabilize_ebay_search(page)
      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + capped_timeout(6.0)
      accepted_cookies = false

      loop do
        accepted_cookies ||= click_visible_button_by_text(
          page,
          [
            "accept all",
            "accept all cookies",
            "accept cookies",
            "allow all",
            "allow cookies",
            "agree to cookies",
            "continue with cookies"
          ],
          selectors: 'button, [role="button"], a, input[type="button"], input[type="submit"]'
        )

        state = safe_evaluate(page, <<~JS, default: { "itemCount" => 0, "challengeVisible" => false })
          (() => {
            const bodyText = document.body ? document.body.innerText : '';
            return {
              itemCount: document.querySelectorAll('li.s-item a[href*="/itm/"], ul.srp-results a[href*="/itm/"]').length,
              challengeVisible: /checking your browser before you access ebay|your browser will redirect to your requested content shortly|pardon our interruption/i.test(bodyText)
            };
          })()
        JS

        break if state["itemCount"].to_i >= 4
        break if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline

        sleep(state["challengeVisible"] ? 0.35 : 0.15)
      end

      settle_after_stabilization(0.25) if accepted_cookies
    end

    def reddit_content_ready?(page)
      page.evaluate(<<~JS)
        !!document.querySelector('shreddit-post, faceplate-screen-reader-content, shreddit-comment, [data-testid="comment"]')
      JS
    rescue Ferrum::JavaScriptError
      false
    end

    def dismiss_reddit_cookie_dialog(page)
      removed = dismiss_overlay_dialog(
        page,
        close_selectors: [],
        dialog_selectors: [
          '[data-testid="onboarding-modal"]',
          '[data-testid="gdpr-modal"]',
          '[aria-modal="true"]',
          '[role="dialog"]',
          "shreddit-experience-tree"
        ],
        dialog_pattern: "before you continue to reddit|let us know your cookie preferences"
      )
      return true if removed

      safe_evaluate(page, <<~JS)
        (() => {
          let removed = false;
          document.querySelectorAll('section, div, aside, form, footer, shreddit-experience-tree').forEach((node) => {
            const text = (node.innerText || node.textContent || '').replace(/\s+/g, ' ').trim();
            if (/before you continue to reddit|let us know your cookie preferences/i.test(text) && text.length < 2000) {
              node.remove();
              removed = true;
            }
          });

          if (removed) {
            if (document.body) document.body.style.overflow = 'auto';
            if (document.documentElement) document.documentElement.style.overflow = 'auto';
          }

          return removed;
        })()
      JS
    end

    def instagram_url?(url)
      host = URI.parse(url).host.to_s.downcase
      host == "instagram.com" || host.end_with?(".instagram.com")
    rescue URI::InvalidURIError
      false
    end

    def stabilize_instagram(page)
      # Phase 1: wait for page to have content, accept cookie consent
      wait_for_idle_or_content(page) if @wait_for_idle
      accept_instagram_cookie_dialog(page) || accept_cookie_consent(page)
      social_login_phase_pause
      accept_instagram_cookie_dialog(page) || accept_cookie_consent(page)

      # Phase 2: dismiss the login modal overlay
      retry_until_timeout(capped_timeout(5.0)) { dismiss_instagram_login_modal(page) }

      # Phase 3: brief settle after modal dismiss
      social_login_phase_pause
      # Final sweep in case modal reappeared
      dismiss_instagram_login_modal(page)
    end

    def accept_instagram_cookie_dialog(page)
      click_visible_button_by_text(
        page,
        [
          "accept",
          "accept all",
          "accept all cookies"
        ],
        [
          "allow all cookies",
          "allow all",
          "allow cookies"
        ],
        selectors: 'button, [role="button"], a, input[type="button"], input[type="submit"]'
      )
    end

    def dismiss_instagram_login_modal(page)
      dismiss_overlay_dialog(
        page,
        close_selectors: [
          '[role="dialog"] button[aria-label]',
          '[role="dialog"] button[title]',
          '[role="dialog"] button svg',
          '[role="presentation"] button[aria-label]',
          '[role="presentation"] button[title]',
          '[role="presentation"] button svg',
          '[aria-modal="true"] button[aria-label]',
          '[aria-modal="true"] button[title]',
          '[aria-modal="true"] button svg'
        ],
        dialog_selectors: ['[role="dialog"]', '[role="presentation"]', '[aria-modal="true"]'],
        overlay_selectors: ['div[style*="position: fixed"]', 'div[style*="position:fixed"]'],
        dialog_pattern: "log in|sign up|create (?:new )?account|don.?t have an account",
        close_label_pattern: "^(?:close|dismiss|x|×)?$",
        allow_empty_close_label: true
      )
    end

    def facebook_url?(url)
      host = URI.parse(url).host.to_s.downcase
      host == "facebook.com" || host.end_with?(".facebook.com")
    rescue URI::InvalidURIError
      false
    end

    def stabilize_facebook(page)
      # Phase 1: wait for content to render
      wait_for_idle_or_content(page) if @wait_for_idle
      social_login_phase_pause

      # Phase 2: dismiss cookie dialog (click "Decline optional cookies")
      dismiss_facebook_cookie_dialog(page)
      social_login_phase_pause

      # Phase 3: dismiss login dialog
      retry_until_timeout(capped_timeout(5.0)) { dismiss_facebook_login_dialog(page) }

      # Phase 4: brief settle
      social_login_phase_pause
    end

    def dismiss_facebook_cookie_dialog(page)
      click_visible_button_by_text(
        page,
        [
          "decline optional cookies",
          "optionale cookies ablehnen",
          "refuser les cookies optionnels",
          "rechazar cookies opcionales",
          "rifiuta i cookie opzionali"
        ],
        [
          "allow all cookies",
          "alle cookies erlauben",
          "autoriser tous les cookies",
          "permitir todas las cookies",
          "consenti tutti i cookie"
        ]
      )
    end

    def dismiss_facebook_login_dialog(page)
      dismiss_overlay_dialog(
        page,
        close_selectors: ['[aria-label="Close"]', '[aria-label="close"]'],
        dialog_selectors: ['[role="dialog"]', '[aria-modal="true"]'],
        dialog_pattern: "log in|sign up|create (?:new )?account|see more from"
      )
    end

    def accept_cookie_consent(page)
      safe_evaluate(page, <<~JS)
        (() => {
          const pattern = /^(accept(?: all(?: cookies?)?)?|allow all(?: cookies)?|allow cookies|agree(?: to cookies| and continue| & continue)?|i agree|ok(?:ay)?|accept & continue|continue with cookies|consent|got it|i understand|continue|accept and close|close|accept recommended settings|przejdź do serwisu|zaakceptuj(?:\s+(?:wszystkie|wszystko))?|akceptuję|zgadzam się|zgoda|akzeptieren|alle akzeptieren|zustimmen|accepter (?:tout|les cookies|et continuer)|tout accepter|j'accepte|accepter|aceptar (?:todo|todas|cookies)|acepto|accetta (?:tutto|tutti)|accetto|aceitar (?:tudo|todos)|aceito|accetta e continua|akkoord|ga akkoord|alles accepteren|accepteer alles|すべて受け入れる|すべて許可|同意する|同意して閉じる|쿠키 허용|모두 허용|동의하고 계속|동의|接受全部|全部接受|同意并继续|接受并继续|принять все|согласен|согласиться|souhlasím|přijmout vše|přijmout(?:\s+(?:všechny|vše))?|povolit vše|souhlasit|godkänn alla|acceptera alla|tillåt alla|jag godkänner|godkänn|accepter alle|tillad alle|jeg accepterer|acceptér|godta alle|tanggap semua|setuju|terima semua|godkjenn alle|aksepter alle|aksepter|jeg godtar|godta|accepta-ho tot|accepta|accepto|d'acord|razumem|prihvatam|прихватам|прихвати све|qəbul edirəm|ყველას მიღება|සියල්ල පිළිගන්න|පිළිගන්න|همه را بپذیرید|ተቀበል|ሁሉንም ተቀበል|allow all|confirm my choices|pokračovat)$/i;
          const consentPattern = /(cookie|cookies|privacy|consent|gdpr|ccpa|onetrust|before you continue|device identifiers|personalized ads|trusted third party partners?|privacy preference center|your privacy settings|your privacy choices|manage privacy preferences|manage consent preferences|cookie information|cookie list|cookies details|list of partners(?: \(vendors\))?|pliki cookie|datenschutz|données personnelles|datos personales|dati personali|wish to store|access information on your devices|preferenze cookie|クッキー|Cookieプリファレンス|Cookie設定|同意設定|쿠키|동의|개인정보|接受|隐私设置|cookie 偏好设置|файлы cookie|настройки cookie|souhlas|personalizac|soukromí|nastavení souhlasu|kakor|sekretess|samtycke|cookies og data|privatlivs|samtykke|privatliv|personvern|informasjonskapsler|informasjonskapslar|aller media|dine data|galetes|protecció de dades|política de privadesa|ግላዊነት|ኩኪ|ኩኪዎች|pro pokračování vyberte|technické cookies|jakou formou vám máme zobrazovat obsah)/i;
          const containerPattern = /(cookie|consent|privacy|onetrust|cookiebot|usercentrics|trustarc|didomi|quantcast|gdpr|ccpa)/i;
          const queryAllRoots = (selectors) => {
            const matches = [];
            const queue = [document];
            while (queue.length) {
              const root = queue.shift();
              if (!root || !root.querySelectorAll) continue;
              root.querySelectorAll(selectors).forEach((el) => matches.push(el));
              root.querySelectorAll('*').forEach((el) => {
                if (el.shadowRoot) queue.push(el.shadowRoot);
              });
            }
            return matches;
          };
          const parentOrHost = (node) => {
            if (!node) return null;
            if (node.parentElement) return node.parentElement;
            const root = node.getRootNode && node.getRootNode();
            return root && root.host ? root.host : null;
          };
          const candidates = queryAllRoots('button, [role="button"], a, input[type="button"], input[type="submit"]');

          const visible = (el) => {
            const rect = el.getBoundingClientRect();
            const style = window.getComputedStyle(el);
            return rect.width > 0 && rect.height > 0 && style.visibility !== 'hidden' && style.display !== 'none';
          };

          const textFor = (el) => {
            const values = [el.innerText, el.textContent, el.value, el.getAttribute('aria-label'), el.getAttribute('title')]
              .filter(Boolean)
              .map((value) => value.replace(/\\s+/g, ' ').trim())
              .filter(Boolean);
            return values[0] || '';
          };

          const consentContext = (el) => {
            let node = el;
            for (let depth = 0; node && depth < 8; depth += 1, node = parentOrHost(node)) {
              const text = textFor(node);
              const attrs = [node.id, node.className, node.getAttribute('aria-label'), node.getAttribute('data-testid')]
                .filter(Boolean)
                .join(' ');
              if (consentPattern.test(text + ' ' + attrs)) return true;
            }
            return false;
          };

          const consentAttrs = (el) => [el.id, el.className, el.getAttribute('aria-label'), el.getAttribute('data-testid')]
            .filter(Boolean)
            .join(' ');

          let clicked = false;
          for (const el of candidates) {
            const text = textFor(el);
            if (!text || !visible(el) || !pattern.test(text) || !consentContext(el)) continue;
            el.click();
            clicked = true;
          }

          for (const el of queryAllRoots('[role="dialog"], [aria-modal="true"], dialog, section, div, aside, form, footer')) {
            const attrs = consentAttrs(el);
            if (!consentContext(el) && !containerPattern.test(attrs)) continue;

            const style = window.getComputedStyle(el);
            const overlayLike = el.matches('[role="dialog"], [aria-modal="true"], dialog') ||
              /fixed|sticky/.test(style.position);
            if (!overlayLike || !visible(el)) continue;

            el.remove();
            clicked = true;
          }

          if (clicked) {
            if (document.body) document.body.style.overflow = 'auto';
            if (document.documentElement) document.documentElement.style.overflow = 'auto';
          }

          return clicked;
        })()
      JS
    end

    def dismiss_privacy_preference_overlay(page)
      overlay_present = safe_evaluate(page, <<~'JS', default: false)
        (() => {
          const text = ((document.body && document.body.innerText) || '').toLowerCase()
          if (!text) return false
          if (!/(privacy preference center|your privacy settings|your privacy choices|manage privacy preferences|manage consent preferences|cookie information|cookie list|cookies details|list of partners(?: \(vendors\))?)/i.test(text)) return false
          return !!document.querySelector("[id*='onetrust' i], [class*='onetrust' i], [id*='cookie' i], [class*='cookie' i], [id*='privacy' i], [class*='privacy' i]")
        })()
      JS
      return false unless overlay_present

      click_visible_button_by_text(
        page,
        ["Accept All", "Allow all", "Confirm My Choices", "Save preferences", "Customize Choices"],
        ["Essential only", "Reject All"],
        selectors: 'button, [role="button"], a, input[type="button"], input[type="submit"]'
      )
    end

    def retry_until_timeout(timeout, interval: 0.2)
      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + timeout

      loop do
        return true if yield
        return false if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline

        sleep interval
      end
    end

    def capped_timeout(max_timeout)
      [@timeout, max_timeout].min
    end

    def settle_after_stabilization(max_wait)
      sleep [@wait, max_wait].min if @wait.positive?
    end

    def social_login_phase_pause
      if @wait.positive?
        settle_after_stabilization(SOCIAL_LOGIN_PHASE_WAIT)
      else
        sleep SOCIAL_LOGIN_PHASE_WAIT
      end
    end

    def click_visible_button_by_text(page, primary_labels, fallback_labels = [], selectors: 'button, [role="button"]')
      groups = [Array(primary_labels), Array(fallback_labels)].reject(&:empty?)

      safe_evaluate(page, <<~JS)
        (() => {
          const labelGroups = #{JSON.generate(groups)};
          const queryAllRoots = (selectors) => {
            const matches = [];
            const queue = [document];
            while (queue.length) {
              const root = queue.shift();
              if (!root || !root.querySelectorAll) continue;
              root.querySelectorAll(selectors).forEach((el) => matches.push(el));
              root.querySelectorAll('*').forEach((el) => {
                if (el.shadowRoot) queue.push(el.shadowRoot);
              });
            }
            return matches;
          };
          const buttons = queryAllRoots(#{selectors.to_json});

          const visible = (el) => {
            const rect = el.getBoundingClientRect();
            const style = window.getComputedStyle(el);
            return rect.width > 0 && rect.height > 0 && style.visibility !== 'hidden' && style.display !== 'none';
          };

          const textFor = (el) => [el.innerText, el.textContent, el.value, el.getAttribute('aria-label'), el.getAttribute('title')]
            .filter(Boolean)
            .join(' ')
            .replace(/\s+/g, ' ')
            .trim()
            .toLowerCase();

          for (const labels of labelGroups) {
            const allowed = new Set(labels.map((label) => String(label).toLowerCase()));
            for (const button of buttons) {
              if (!visible(button) || !allowed.has(textFor(button))) continue;
              button.click();
              return true;
            }
          }

          return false;
        })()
      JS
    end

    def dismiss_overlay_dialog(page, close_selectors:, dialog_selectors:, dialog_pattern:, overlay_selectors: [], close_label_pattern: nil,
                               allow_empty_close_label: false)
      config = {
        closeSelectors: Array(close_selectors),
        dialogSelectors: Array(dialog_selectors),
        overlaySelectors: Array(overlay_selectors),
        dialogPattern: dialog_pattern,
        closeLabelPattern: close_label_pattern,
        allowEmptyCloseLabel: allow_empty_close_label
      }

      safe_evaluate(page, <<~JS)
        (() => {
          const config = #{JSON.generate(config)};
          const dialogPattern = new RegExp(config.dialogPattern || '', 'i');
          const closeLabelPattern = config.closeLabelPattern ? new RegExp(config.closeLabelPattern, 'i') : null;
          const queryAllRoots = (selectors) => {
            const matches = [];
            const queue = [document];
            while (queue.length) {
              const root = queue.shift();
              if (!root || !root.querySelectorAll) continue;
              root.querySelectorAll(selectors).forEach((el) => matches.push(el));
              root.querySelectorAll('*').forEach((el) => {
                if (el.shadowRoot) queue.push(el.shadowRoot);
              });
            }
            return matches;
          };

          const visible = (el) => {
            const rect = el.getBoundingClientRect();
            const style = window.getComputedStyle(el);
            return rect.width > 0 && rect.height > 0 && style.visibility !== 'hidden' && style.display !== 'none';
          };

          const textFor = (el) => (el && (el.innerText || el.textContent || el.getAttribute('aria-label') || '') || '')
            .replace(/\s+/g, ' ')
            .trim();

          const restoreScroll = () => {
            if (document.body) document.body.style.overflow = 'auto';
            if (document.documentElement) document.documentElement.style.overflow = 'auto';
          };

          const clickCloseButton = () => {
            const selectorText = (config.closeSelectors || []).join(', ');
            if (!selectorText) return false;
            const candidates = queryAllRoots(selectorText);

            for (const candidate of candidates) {
              const button = candidate.closest('button, [role="button"]') || candidate;
              if (!button || !visible(button)) continue;

              const label = textFor(button).toLowerCase();
              const labelMatches = !closeLabelPattern || closeLabelPattern.test(label) || (config.allowEmptyCloseLabel && label === '');
              if (!labelMatches) continue;

              button.click();
              restoreScroll();
              return true;
            }

            return false;
          };

          if (clickCloseButton()) return true;

          let removed = false;
          const removeMatchingNodes = (selectors, requireOverlayPrompt) => {
            const selectorText = (selectors || []).join(', ');
            if (!selectorText) return;

            queryAllRoots(selectorText).forEach((node) => {
              const text = textFor(node).slice(0, 2000);
              if (!dialogPattern.test(text)) return;
              if (requireOverlayPrompt && !/log in|sign up/i.test(text)) return;
              node.remove();
              removed = true;
            });
          };

          removeMatchingNodes(config.dialogSelectors, false);
          removeMatchingNodes(config.overlaySelectors, true);

          if (removed) restoreScroll();
          return removed;
        })()
      JS
    end

    def safe_evaluate(page, script, default: false)
      page.evaluate(script)
    rescue Ferrum::JavaScriptError, Ferrum::TimeoutError
      default
    end

    def preserve_consent_wall?(page, url)
      host = URI.parse(url).host.to_s.downcase.sub(/\Awww\./, "")
      return false unless host == "youtube.com" || host.end_with?(".youtube.com") || host.match?(/\Agoogle\.[a-z.]+\z/)

      state = page.evaluate(<<~JS)
        (() => ({
          title: document.title || '',
          text: document.body ? document.body.innerText.replace(/\s+/g, ' ').trim().slice(0, 1200) : ''
        }))()
      JS

      combined = [state["title"], state["text"]].join(" ").downcase
      /before you continue to (google|youtube)|we use cookies and data|accept all|reject all|more options/.match?(combined)
    rescue URI::InvalidURIError, Ferrum::JavaScriptError, Ferrum::TimeoutError
      false
    end

    def symbolize_hash(hash)
      result = {}
      hash.each do |key, value|
        result[key.to_sym] = value
      end
      result
    end
  end
end
