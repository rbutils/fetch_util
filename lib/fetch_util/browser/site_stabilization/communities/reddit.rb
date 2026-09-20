# frozen_string_literal: true

module FetchUtil
  class Browser
    module SiteStabilization
      module RedditStabilization
        REDDIT_STABILIZATION_PROFILE = {
          host: "reddit.com",
          strategy: :stabilize_reddit,
          notes: "Use fast Reddit cookie dismissal/content readiness instead of full idle waits.",
          tests: "spec/fetch_util/browser_stabilization_spec.rb"
        }.freeze

        private

        def stabilize_reddit(page, deadline: stabilization_deadline)
          ready = retry_until_timeout(capped_timeout(3.0, deadline: deadline), interval: 0.1, deadline: deadline) do
            dismiss_reddit_cookie_dialog(page)
            reddit_content_ready?(page)
          end

          settle_after_stabilization(0.25, deadline: deadline)
          dismiss_reddit_cookie_dialog(page) if stabilization_time_remaining?(deadline)
          ready
        end

        def reddit_content_ready?(page)
          safe_evaluate(page, <<~JS, default: false)
            !!document.querySelector('shreddit-post, faceplate-screen-reader-content, shreddit-comment, [data-testid="comment"]')
          JS
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
