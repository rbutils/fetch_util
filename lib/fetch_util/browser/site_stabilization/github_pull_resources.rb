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

        def github_pull_resource_state_script
          <<~'JS'
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
                const bodySelector = '.js-file-content, .blob-wrapper, table.diff-table, table, [data-testid="diff-lines"], [data-testid="diff-file-content"], .rendered-diff';
                const deferredSelector = '.js-diff-load-container include-fragment[src], .js-diff-load-container[data-fragment-url], include-fragment[src*="/pull/"][src*="/files"]';
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
                const materialTextSize = (node) => {
                  if (!node) return 0;
                  return [node, ...node.querySelectorAll('*')].reduce((total, candidate) => {
                    if (!nodeVisible(candidate)) return total;
                    const directText = Array.from(candidate.childNodes)
                      .filter((child) => child.nodeType === Node.TEXT_NODE)
                      .map((child) => child.textContent || '')
                      .join('')
                      .trim();
                    return total + directText.length;
                  }, 0);
                };
                const materialNode = (node) => {
                  if (materialTextSize(node) > 0) return true;
                  return [node, ...node.querySelectorAll('*')].some((candidate) => {
                    return nodeVisible(candidate) && candidate.matches('img[src], canvas, video, audio');
                  });
                };

                let loaded = 0;
                let selectedSize = 0;
                let selectedRequested = false;
                let selectedLoaded = false;
                let selectedDeferred = false;
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
                  const selectedBody = selectedFileRoot && Array.from(selectedFileRoot.querySelectorAll(bodySelector)).find(materialNode);
                  selectedLoaded = !!selectedBody;
                  selectedDeferred = !!(selectedFileRoot && Array.from(selectedFileRoot.querySelectorAll(deferredSelector)).some((node) =>
                    nodeVisible(node) && (node.getAttribute('src') || node.getAttribute('data-fragment-url'))
                  ));
                  selectedSize = selectedLoaded ? materialTextSize(selectedBody) : 0;
                  explicitEmpty = /(?:no files (?:were )?changed|there are no files)/i.test((document.querySelector('.blankslate, main') || {}).textContent || '');
                }

                const rootReady = surface === 'commits' ? !!commitRoot : (surface === 'checks' ? !!checksRoot : (loaded > 0 || explicitEmpty));
                const selectedReady = explicitEmpty || !selectedRequested || selectedLoaded || selectedDeferred;
                const ready = rootReady && (loaded > 0 || explicitEmpty) && selectedReady;
                return {
                  ready,
                  selectedLoaded,
                  selectedDeferred,
                  signature: [surface, loaded, selectedLoaded, selectedDeferred, selectedSize, location.search, location.hash].join(':')
                };
              })()
          JS
        end
      end
    end
  end
end
