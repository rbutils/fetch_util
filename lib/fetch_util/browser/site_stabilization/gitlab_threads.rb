# frozen_string_literal: true

module FetchUtil
  class Browser
    module SiteStabilization
      module GitlabThreads
        GITLAB_THREAD_STABILIZATION_PROFILE = {
          host: true,
          path_query: lambda { |uri|
            uri.path.match?(%r{/[^/]+/-/(?:issues|work_items|merge_requests)/\d+/?\z})
          },
          strategy: :stabilize_gitlab_thread,
          fallthrough: true,
          notes: "Wait for host-agnostic GitLab issue and merge-request conversations.",
          tests: "spec/fetch_util/browser_stabilization_spec.rb"
        }.freeze

        private

        def stabilize_gitlab_thread(page)
          last_signature = nil
          stable_observations = 0
          ready = retry_until_timeout(capped_timeout(8.0), interval: 0.1) do
            state = safe_evaluate(page, <<~JS, default: nil)
              (() => {
                const route = location.pathname.match(/\/-\/(issues|work_items|merge_requests)\/\d+\/?$/);
                if (!route) return null;

                const site = document.querySelector('meta[property="og:site_name"]');
                const branded = document.documentElement.classList.contains('gl-system') &&
                  /^GitLab$/i.test((site && site.content || '').trim());
                const meta = !!document.querySelector('meta[name="gitlab-meta"], meta[name^="gitlab-"]');
                const gon = window.gon || {};
                const hasRelativeRoot = Object.prototype.hasOwnProperty.call(gon, 'relative_url_root');
                const runtimeTarget = gon.gitlab_url || (hasRelativeRoot ? (gon.relative_url_root || location.origin) : '');
                let runtime = !!gon.api_version && !!runtimeTarget;
                if (runtime) {
                  try { runtime = new URL(runtimeTarget, location.href).origin === location.origin; } catch (_error) { runtime = false; }
                }
                const asset = Array.from(document.querySelectorAll('script[src], link[href]')).some((node) => {
                  const value = node.getAttribute('src') || node.getAttribute('href') || '';
                  if (!/\/assets\/(?:webpack|application|gitlab)/i.test(value)) return false;
                  try { return new URL(value, location.href).origin === location.origin; } catch (_error) { return false; }
                });
                const product = (runtime && (branded || meta || asset)) || (branded && (meta || asset));
                if (!product) return { product: false, ready: false, signature: '' };

                const root = document.querySelector(
                  '.work-item-page, [data-testid="work-item-view"], .work-item-notes, .issuable-details, .merge-request, .issue-details'
                );
                if (!root) return { product: true, ready: false, signature: '' };

                const title = document.querySelector('[data-testid="work-item-title"], [data-testid="issuable-title"], .issue-title, .merge-request .title');
                const description = document.querySelector('[data-testid="work-item-description"], [data-testid="description-content"], .detail-page-description .md, .issuable-description .md');
                const rows = document.querySelectorAll('.js-timeline-entry.timeline-entry, .timeline-entry');
                const bodies = document.querySelectorAll('.note-body, .note-text, [data-testid="note-body"]');
                const explicitZero = /\b0\s+(?:comments?|notes?)\b/i.test((root.textContent || ''));
                const loadControls = Array.from(root.querySelectorAll(
                  'button[data-testid*="load-more"], a[data-testid*="load-more"], [data-testid*="load-more"] button, [data-testid*="load-more"] a, .js-load-more button, .js-load-more a'
                )).filter((node) => {
                  let current = node;
                  while (current && current !== root.parentElement) {
                    const style = getComputedStyle(current);
                    if (current.hidden || style.display === 'none') return false;
                    current = current.parentElement;
                  }
                  return getComputedStyle(node).visibility !== 'hidden';
                });
                const loading = loadControls.some((node) =>
                  node.getAttribute('aria-busy') === 'true' || node.getAttribute('data-loading') === 'true' ||
                  /(?:^|\s)(?:is-)?loading(?:\s|$)/.test(node.className || '')
                );
                const continuation = !loading && loadControls.find((node) =>
                  !node.disabled && node.getAttribute('aria-disabled') !== 'true'
                );
                if (continuation) {
                  continuation.click();
                  return { product: true, ready: false, signature: [rows.length, bodies.length, true, 'loading'].join(':') };
                }
                const textSize = Array.from(rows).reduce((sum, row) => sum + (row.textContent || '').trim().length, 0) +
                  (description && description.textContent || '').trim().length;
                return {
                  product: true,
                  ready: !!title && !!description && !loading && (rows.length > 0 || explicitZero),
                  signature: [rows.length, bodies.length, loading, textSize].join(':')
                };
              })()
            JS
            return false if state.is_a?(Hash) && state["product"] == false
            next false unless state.is_a?(Hash) && state["product"] && state["ready"]

            if state["signature"] == last_signature
              stable_observations += 1
              stable_observations >= 3
            else
              last_signature = state["signature"]
              stable_observations = 1
              false
            end
          end

          settle_after_stabilization(0.5) if ready
          !!ready
        end
      end
    end
  end
end
