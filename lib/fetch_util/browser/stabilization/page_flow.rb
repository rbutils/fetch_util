# frozen_string_literal: true

module FetchUtil
  class Browser
    module Stabilization
      module PageFlow
        PAGE_FLOW_STABILIZATION_PROFILES = [
          SiteStabilization::CommunityAndMarketplace::COMMUNITY_MARKETPLACE_STABILIZATION_PROFILES[:stabilize_reddit],
          SiteStabilization::SocialPlatforms::SOCIAL_PLATFORM_STABILIZATION_PROFILES[:stabilize_instagram],
          SiteStabilization::SocialPlatforms::SOCIAL_PLATFORM_STABILIZATION_PROFILES[:stabilize_facebook],
          SiteStabilization::CommunityAndMarketplace::COMMUNITY_MARKETPLACE_STABILIZATION_PROFILES[:stabilize_ebay_search],
          { host: "gitlab.com", path_query: ->(uri) { uri.path.split("/").reject(&:empty?).length == 2 },
            strategy: :stabilize_gitlab_repo, notes: "Wait for repository README content on GitLab project roots.",
            tests: "spec/fetch_util/browser_stabilization_spec.rb" }
        ].freeze
        POST_GENERIC_STABILIZATION_PROFILES = [
          { host: ["wyborcza.pl", "gazeta.pl"], path_query: ->(uri) { uri.path.match?(%r{/(?:\d+,){2}\d+,|/7,}) },
            strategy: :wait_for_agora_article,
            notes: "After generic consent/idle handling, wait briefly for delayed Agora article bodies.",
            tests: "spec/fetch_util/browser_stabilization_spec.rb" }
        ].freeze

        private

        def stabilize_page(page, url)
          if (profile = matching_stabilization_profile(url, PAGE_FLOW_STABILIZATION_PROFILES))
            return send(profile.fetch(:strategy), page)
          end

          reached_idle = !@wait_for_idle || wait_for_idle_or_content(page)
          preserve_consent = preserve_consent_wall?(page, url)
          accepted_cookies = preserve_consent ? false : accept_cookie_consent(page)
          accepted_cookies = (!preserve_consent && dismiss_privacy_preference_overlay(page)) || accepted_cookies
          sleep @wait if @wait.positive?
          accepted_cookies = (!preserve_consent && accept_cookie_consent(page)) || accepted_cookies
          accepted_cookies = (!preserve_consent && dismiss_privacy_preference_overlay(page)) || accepted_cookies

          wait_for_spa_hydration(page) if @wait_for_idle && reached_idle
          accepted_cookies = (!preserve_consent && accept_cookie_consent(page)) || accepted_cookies
          accepted_cookies = (!preserve_consent && dismiss_privacy_preference_overlay(page)) || accepted_cookies
          if (profile = matching_stabilization_profile(url, POST_GENERIC_STABILIZATION_PROFILES))
            send(profile.fetch(:strategy), page, url)
          end

          return unless accepted_cookies && @wait_for_idle && reached_idle

          page.network.wait_for_idle(duration: @idle_duration, timeout: POST_CONSENT_IDLE_TIMEOUT)
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
      end
    end
  end
end
