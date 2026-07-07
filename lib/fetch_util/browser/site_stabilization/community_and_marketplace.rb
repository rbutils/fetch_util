# frozen_string_literal: true

module FetchUtil
  class Browser
    module SiteStabilization
      module CommunityAndMarketplace
        COMMUNITY_MARKETPLACE_STABILIZATION_PROFILES = {
          stabilize_reddit: {
            host: "reddit.com",
            strategy: :stabilize_reddit,
            notes: "Use fast Reddit cookie dismissal/content readiness instead of full idle waits.",
            tests: "spec/fetch_util/browser_stabilization_spec.rb"
          },
          stabilize_ebay_search: {
            host: "ebay.com",
            path_query: ->(uri) { uri.path.include?("/sch/") || uri.query.to_s.include?("_nkw=") },
            strategy: :stabilize_ebay_search,
            notes: "Wait for search result items or short-lived eBay browser checks.",
            tests: "spec/fetch_util/browser_stabilization_spec.rb"
          }
        }.freeze
        private_constant :COMMUNITY_MARKETPLACE_STABILIZATION_PROFILES

        private

        def stabilize_reddit(page)
          retry_until_timeout(capped_timeout(3.0), interval: 0.1) do
            dismiss_reddit_cookie_dialog(page)
            reddit_content_ready?(page)
          end

          settle_after_stabilization(0.25)
          dismiss_reddit_cookie_dialog(page)
        end

        def stabilize_ebay_search(page)
          accepted_cookies = false
          cookie_config = consent_config(
            accept_labels: [
              "accept all",
              "accept all cookies",
              "accept cookies",
              "allow all",
              "allow cookies",
              "agree to cookies",
              "continue with cookies"
            ]
          )

          retry_until_timeout(capped_timeout(6.0), interval: 0.15) do
            accepted_cookies ||= click_visible_button_by_text(
              page,
              consent_accept_labels(cookie_config),
              selectors: consent_button_selectors(cookie_config)
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

            state["itemCount"].to_i >= 4 || (state["challengeVisible"] ? 0.35 : false)
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
              #{js_dom_helpers}
              let removed = false;
              document.querySelectorAll('section, div, aside, form, footer, shreddit-experience-tree').forEach((node) => {
                const text = (node.innerText || node.textContent || '').replace(/\s+/g, ' ').trim();
                if (/before you continue to reddit|let us know your cookie preferences/i.test(text) && text.length < 2000) {
                  node.remove();
                  removed = true;
                }
              });

              if (removed) {
                restoreScroll();
              }

              return removed;
            })()
          JS
        end
      end
    end
  end
end
