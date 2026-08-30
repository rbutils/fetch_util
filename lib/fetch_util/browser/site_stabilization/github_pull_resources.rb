# frozen_string_literal: true

module FetchUtil
  class Browser
    module SiteStabilization
      module GithubPullResources
        GITHUB_PULL_RESOURCE_STABILIZATION_PROFILE = {
          host: "github.com",
          path_query: ->(uri) { uri.path.match?(%r{\A/[^/]+/[^/]+/pull/\d+/(?:commits|checks|files)/?\z}) },
          strategy: :stabilize_github_pull_resource,
          notes: "Wait for public GitHub pull-request resource lists and selected detail.",
          tests: "spec/fetch_util/browser_stabilization_spec.rb"
        }.freeze

        private

        def stabilize_github_pull_resource(page)
          last_signature = nil
          stable_observations = 0
          ready = retry_until_timeout(capped_timeout(8.0), interval: 0.1) do
            state = safe_evaluate(page, <<~JS, default: nil)
              (() => {
                const match = location.pathname.match(/\/pull\/\d+\/(commits|checks|files)\/?$/);
                if (!match) return null;

                const surface = match[1];
                const commitRoot = document.querySelector('[data-testid="commits-list"]');
                const commitRows = document.querySelectorAll('[data-testid="commit-row-item"]');
                const checksRoot = document.querySelector('section.js-selected-check-run, .actions-grid-container, [class*="Checks-module__checksRoot"]');
                const checkLinks = document.querySelectorAll('a[href*="check_run_id="]');
                const requestedCheckId = new URLSearchParams(location.search).get('check_run_id') || '';
                const selectedCheck = /^\d+$/.test(requestedCheckId) ? document.getElementById('check_run_' + requestedCheckId) : null;
                const fileHeaders = document.querySelectorAll('.file.js-file .file-header[data-path][data-anchor]');
                const selectedFile = location.hash && document.querySelector('.file-header[data-anchor="' + CSS.escape(location.hash.slice(1)) + '"]');
                const selectedFileRoot = selectedFile && selectedFile.closest('.file.js-file');
                const nodeVisible = (node) => {
                  if (!node) return false;
                  const nodeStyle = getComputedStyle(node);
                  if (nodeStyle.visibility === 'hidden' || nodeStyle.visibility === 'collapse') return false;
                  let current = node;
                  while (current && current.nodeType === 1) {
                    if (current.hidden || getComputedStyle(current).display === 'none') return false;
                    current = current.parentElement;
                  }
                  return true;
                };

                let loaded = 0;
                let selectedSize = 0;
                let selectedRequested = false;
                let explicitEmpty = false;
                if (surface === 'commits') loaded = commitRows.length;
                if (surface === 'checks') {
                  loaded = checkLinks.length;
                  selectedRequested = !!requestedCheckId;
                  selectedSize = nodeVisible(selectedCheck) ? (selectedCheck.textContent || '').trim().length : 0;
                  explicitEmpty = /no checks (?:have been|were) run/i.test(checksRoot && checksRoot.textContent || '');
                }
                if (surface === 'files') {
                  loaded = fileHeaders.length;
                  selectedRequested = !!location.hash;
                  selectedSize = nodeVisible(selectedFileRoot) ? (selectedFileRoot.textContent || '').trim().length : 0;
                  explicitEmpty = /(?:no files (?:were )?changed|there are no files)/i.test((document.querySelector('.blankslate, main') || {}).textContent || '');
                }

                const rootReady = surface === 'commits' ? !!commitRoot : (surface === 'checks' ? !!checksRoot : (loaded > 0 || explicitEmpty));
                const selectedReady = explicitEmpty || !selectedRequested || selectedSize > 0;
                const ready = rootReady && (loaded > 0 || explicitEmpty) && selectedReady;
                return {
                  ready,
                  signature: [surface, loaded, selectedSize, location.search, location.hash].join(':')
                };
              })()
            JS
            next false unless state.is_a?(Hash) && state["ready"]

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
        end
      end
    end
  end
end
