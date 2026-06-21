# frozen_string_literal: true

module FetchUtil
  class Browser
    module Stabilization
      module PageFlow
        private

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
      end
    end
  end
end
