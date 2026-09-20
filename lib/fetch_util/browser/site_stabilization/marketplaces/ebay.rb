# frozen_string_literal: true

module FetchUtil
  class Browser
    module SiteStabilization
      module EbayStabilization
        EBAY_STABILIZATION_PROFILE = {
          host: "ebay.com",
          path_query: ->(uri) { uri.path.include?("/sch/") || uri.query.to_s.include?("_nkw=") },
          strategy: :stabilize_ebay_search,
          notes: "Wait for search result items or short-lived eBay browser checks.",
          tests: "spec/fetch_util/browser_stabilization_spec.rb"
        }.freeze

        private

        def stabilize_ebay_search(page, deadline: stabilization_deadline)
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

          retry_until_timeout(capped_timeout(6.0, deadline: deadline), interval: 0.15, deadline: deadline) do
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

          settle_after_stabilization(0.25, deadline: deadline) if accepted_cookies
        end
      end
    end
  end
end
