# frozen_string_literal: true

module FetchUtil
  class Browser
    module SiteStabilization
      module GithubThreads
        GITHUB_THREAD_STABILIZATION_PROFILE = {
          host: "github.com",
          path_query: ->(uri) { uri.path.match?(%r{\A/[^/]+/[^/]+/(?:issues|pull|discussions)/\d+/?\z}) },
          strategy: :stabilize_github_thread,
          notes: "Wait for a public GitHub thread body and its materialized timeline.",
          tests: "spec/fetch_util/browser_stabilization_spec.rb"
        }.freeze

        private

        def stabilize_github_thread(page)
          last_signature = nil
          stable_observations = 0
          ready = retry_until_timeout(capped_timeout(6.0), interval: 0.1) do
            state = safe_evaluate(page, <<~JS, default: nil)
              (() => {
                const root = document.querySelector(
                  '[data-testid="issue-viewer-container"], [data-testid="issue-viewer-issue-container"], #discussion_bucket, .js-discussion, .discussion-timeline'
                );
                if (!root) return null;

                const modernBody = root.querySelector('[data-testid="issue-body"]');
                if (!modernBody) {
                  return { ready: !!root.querySelector('.comment-body, .js-comment-body, [data-testid="comment-body"], [itemprop="text"]'), complete: true, signature: 'legacy' };
                }

                const author = modernBody.querySelector('[data-testid="issue-body-header-author"]');
                const rows = root.querySelectorAll('[data-testid^="timeline-row-border-"]');
                const commentRows = Array.from(rows).filter((row) => row.querySelector('a[href*="#issuecomment-"], a[href*="#discussioncomment-"]'));
                const count = root.querySelector('[data-testid="issue-comment-count"], [data-testid="discussion-comment-count"]');
                const countText = (count && count.textContent || '').trim();
                const explicitZero = /^0\s+(?:comments?|replies)$/i.test(countText);
                const continuationControls = Array.from(root.querySelectorAll(
                  'a[rel~="next"][href*="timeline_page="], a[data-testid*="timeline-load-more"][href*="timeline_page="], ' +
                  '[data-testid*="timeline-load-more"] a[href*="timeline_page="], ' +
                  '[data-testid*="timeline-load-more"] button, button[data-testid*="timeline-load-more"]'
                ));
                const usableContinuation = continuationControls.some((control) => {
                  if (control.disabled || control.getAttribute('aria-disabled') === 'true') return false;

                  let current = control;
                  while (current && root.contains(current)) {
                    if (current.hidden || current.getAttribute('aria-hidden') === 'true') return false;
                    const style = getComputedStyle(current);
                    if (style.display === 'none' || style.visibility === 'hidden' || style.visibility === 'collapse') return false;
                    current = current.parentElement;
                  }
                  return true;
                });
                return {
                  ready: !!author && (explicitZero || rows.length > 0),
                  complete: false,
                  signature: [rows.length, commentRows.length, countText, usableContinuation].join(':')
                };
              })()
            JS
            next false unless state.is_a?(Hash) && state["ready"]

            if state["complete"]
              true
            elsif state["signature"] == last_signature
              stable_observations += 1
              stable_observations >= 3
            else
              last_signature = state["signature"]
              stable_observations = 1
              false
            end
          end

          settle_after_stabilization(0.5) if ready
        end
      end
    end
  end
end
