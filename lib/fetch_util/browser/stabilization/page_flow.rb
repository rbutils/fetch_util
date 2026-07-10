# frozen_string_literal: true

module FetchUtil
  class Browser
    # rubocop:disable Metrics/ModuleLength -- shared stabilization module is intentionally centralized.
    module Stabilization
      module PageFlow
        PAGE_FLOW_STABILIZATION_PROFILES = [
          SiteStabilization::CommunityAndMarketplace::COMMUNITY_MARKETPLACE_STABILIZATION_PROFILES[:stabilize_reddit],
          SiteStabilization::SocialPlatforms::SOCIAL_PLATFORM_STABILIZATION_PROFILES[:stabilize_instagram],
          SiteStabilization::SocialPlatforms::SOCIAL_PLATFORM_STABILIZATION_PROFILES[:stabilize_facebook],
          SiteStabilization::CommunityAndMarketplace::COMMUNITY_MARKETPLACE_STABILIZATION_PROFILES[:stabilize_ebay_search],
          SiteStabilization::TravelAndLodging::TRAVEL_LODGING_STABILIZATION_PROFILES[:stabilize_lodging_detail],
          { host: "t.me", path_query: ->(uri) { uri.path.match?(%r{\A/s/[^/]+/\d+/?\z}) },
            strategy: :wait_for_telegram_message, notes: "Wait for the requested public Telegram preview message.",
            tests: "spec/fetch_util/browser_stabilization_spec.rb" },
          { host: "gitlab.com", path_query: ->(uri) { uri.path.split("/").reject(&:empty?).length == 2 },
            strategy: :stabilize_gitlab_repo, notes: "Wait for repository README content on GitLab project roots.",
            tests: "spec/fetch_util/browser_stabilization_spec.rb" },
          { host: "onet.pl", path_query: ->(uri) { uri.path == "/" },
            strategy: :wait_for_onet_homepage, notes: "Wait for Onet's hydrated feed regions and cards before extraction.",
            tests: "spec/fetch_util/browser_stabilization_spec.rb" },
          { host: "wp.pl", path_query: ->(uri) { uri.path == "/" },
            strategy: :wait_for_wp_homepage, notes: "Wait for WP's materialized section grids before extraction.",
            tests: "spec/fetch_util/browser_stabilization_spec.rb" }
        ].freeze
        POST_GENERIC_STABILIZATION_PROFILES = [
          { host: ["wyborcza.pl", "gazeta.pl"], path_query: ->(uri) { uri.path.match?(%r{/(?:\d+,){2}\d+,|/7,}) },
            strategy: :wait_for_agora_article,
            notes: "After generic consent/idle handling, wait briefly for delayed Agora article bodies.",
            tests: "spec/fetch_util/browser_stabilization_spec.rb" },
          { host: "france24.com", path_query: ->(uri) { uri.path.match?(%r{/\d{8}-}) },
            strategy: :wait_for_france24_article,
            notes: "After generic consent/idle handling, wait briefly for delayed France24 article bodies.",
            tests: "spec/fetch_util/browser_stabilization_spec.rb" }
        ].freeze

        private

        def stabilize_page(page, url)
          if (profile = matching_stabilization_profile(url, PAGE_FLOW_STABILIZATION_PROFILES))
            return send(profile.fetch(:strategy), page)
          end

          reached_idle = !@wait_for_idle || wait_for_idle_or_content(page)
          preserve_consent = preserve_consent_wall?(page, url)
          accepted_cookies = preserve_consent ? false : dismiss_cookie_overlays(page)
          if @wait.positive? && (!@wait_for_idle || accepted_cookies)
            sleep @wait
            accepted_cookies = dismiss_cookie_overlays(page) || accepted_cookies unless preserve_consent
          end

          wait_for_spa_hydration(page) if @wait_for_idle && reached_idle
          if accepted_cookies
            accepted_cookies = dismiss_cookie_overlays(page) || accepted_cookies
          end
          if (profile = matching_stabilization_profile(url, POST_GENERIC_STABILIZATION_PROFILES))
            send(profile.fetch(:strategy), page, url)
          end

          return unless accepted_cookies && @wait_for_idle && reached_idle

          wait_for_network_idle(page)
        end

        def matching_stabilization_profile(url, profiles)
          uri = URI.parse(url)
          host = FetchUtil.strip_www_host(url)
          profiles.find { |profile| profile_match?(profile, uri, host) }
        rescue URI::InvalidURIError
          nil
        end

        def profile_match?(profile, uri, host) = stabilization_host_matches?(profile.fetch(:host), host) && profile.fetch(:path_query, ->(_) { true }).call(uri)

        def stabilization_host_matches?(matcher, host) = Array(matcher).any? { |candidate| host == candidate || host.end_with?(".#{candidate}") }

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

        def wait_for_network_idle(page)
          page.network.wait_for_idle(duration: @idle_duration, timeout: POST_CONSENT_IDLE_TIMEOUT)
          true
        rescue Ferrum::TimeoutError
          false
        rescue Ferrum::Error => e
          raise if retryable_pending_connections_error?(e)

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

        def preserve_consent_wall?(page, url)
          host = FetchUtil.strip_www_host(url)
          return true if host == "france24.com" || host.end_with?(".france24.com")
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

        def wait_for_agora_article(page, _url)
          retry_until_timeout(7.0, interval: 0.25) do
            page.evaluate(<<~JS)
              (() => {
                const selectors = ['.mrf-article-body', '.article_body', 'div.articleBody', '.art_content', '.article-inner', 'section.article', '[itemprop=articleBody]'];
                if (selectors.some((selector) => document.querySelector(selector))) return true;
                const text = document.body ? (document.body.innerText || '') : '';
                return !(new RegExp('Wyłącz AdBlocka/uBlocka|Nieznany błąd', 'i')).test(text) && text.length > 1200;
              })()
            JS
          end
        rescue Ferrum::JavaScriptError, Ferrum::TimeoutError
          false
        end

        def wait_for_france24_article(page, _url)
          retry_until_timeout(15.0, interval: 0.25) do
            page.evaluate(<<~JS)
              (() => {
                const body = document.querySelector('.t-content__body') || document.querySelector('.t-content--article');
                if (!body) return false;
                const text = (body.innerText || '').replace(/\s+/g, ' ').trim();
                return body.querySelectorAll('p').length >= 3 && text.length > 1000;
              })()
            JS
          end
        rescue Ferrum::JavaScriptError, Ferrum::TimeoutError
          false
        end

        def wait_for_onet_homepage(page)
          wait_for_structural_readiness(page, "section[class*='Feed_']", "article[class*='Card_']")
        end

        def wait_for_wp_homepage(page)
          wait_for_structural_readiness(page, ".wp-section-grid", ".wp-teaser-tile, .wp-teaser-regular")
        end

        def wait_for_telegram_message(page)
          target = URI.parse(page.current_url).path.delete_prefix("/s/")

          ready = retry_until_timeout(capped_timeout(5.0), interval: 0.25) do
            page.evaluate(<<~JS)
              (() => {
                const card = document.querySelector('.tgme_widget_message[data-post="#{target}"]');
                const text = card && card.querySelector('.tgme_widget_message_text, .js-message_text');
                return !!(text && (text.innerText || '').trim());
              })()
            JS
          end
          sleep PRE_EXTRACTION_SETTLE_WAIT if ready
          ready
        rescue URI::InvalidURIError, Ferrum::JavaScriptError, Ferrum::TimeoutError
          false
        end
      end
    end
  end
end

# rubocop:enable Metrics/ModuleLength
