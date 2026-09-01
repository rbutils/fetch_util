# frozen_string_literal: true

module FetchUtil
  class Browser
    module SiteStabilization
      module BitbucketCloudPullResourceState
        private

        def bitbucket_cloud_pull_resource_state_script
          <<~'JS'
            (() => {
              const match = location.pathname.match(/^\/([^/]+)\/([^/]+)\/pull-requests\/(\d+)\/commits\/?$/);
              if (!match) return { product: false, ready: false, loading: false, signature: '' };
              const decode = (value) => { try { return decodeURIComponent(value); } catch (_error) { return ''; } };
              const workspace = decode(match[1]);
              const repository = decode(match[2]);
              if (!workspace || !repository || workspace.includes('/') || repository.includes('/')) {
                return { product: false, ready: false, loading: false, signature: '' };
              }
              const current = (((window.__initial_state__ || {}).section || {}).repository || {}).currentRepository || {};
              const publicRepository = current.is_private === false || current.isPrivate === false || current.visibility === 'public';
              const runtime = current.type === 'repository' && publicRepository &&
                String(current.full_name || '').toLowerCase() === `${workspace}/${repository}`.toLowerCase();
              const application = document.querySelector('meta[name="application-name"]');
              const branded = /^Bitbucket$/i.test((application && application.content || '').trim());
              const asset = Array.from(document.querySelectorAll('script[src], link[href]'))
                .some((node) => {
                  const value = node.getAttribute('src') || node.getAttribute('href') || '';
                  return /(?:frontbucket|bbc-frontbucket-static|bitbucket)[^/]*\/(?:assets|static)\//i.test(value) ||
                    /\/(?:assets|static)\/[^?#]*(?:frontbucket|bitbucket)/i.test(value);
                });
              const header = document.querySelector('[data-testid="pr-header"]');
              const product = runtime && branded && !!(header || asset);
              if (!product) return { product: false, ready: false, loading: false, signature: '' };

              const panel = document.querySelector('[role="tabpanel"][id^="pull-request-tabs-"]');
              const wrapper = document.querySelector('[data-qa^="commit-hash-wrapper-"]');
              const root = panel || (wrapper && wrapper.closest('table, [role="grid"]'));

              const visible = (node) => {
                let currentNode = node;
                while (currentNode && currentNode !== document) {
                  const style = getComputedStyle(currentNode);
                  if (currentNode.hidden || style.display === 'none') return false;
                  currentNode = currentNode.parentElement;
                }
                const style = getComputedStyle(node);
                return style.visibility !== 'hidden' && style.visibility !== 'collapse';
              };
              const seen = new Set();
              const rows = Array.from(root ? root.querySelectorAll('a[aria-label^="Commit: "][href*="/commits/"]') : [])
                .map((link) => {
                  const label = (link.getAttribute('aria-label') || '').trim().match(/^Commit:\s*([0-9a-f]{7,40})$/i);
                  const row = link.closest('tr, [role="row"]');
                  try {
                    const url = new URL(link.href, location.href);
                    const path = url.pathname.match(/^\/([^/]+)\/([^/]+)\/commits\/([0-9a-f]{40})\/?$/i);
                    if (!label || !row || !visible(row) || url.origin !== location.origin || !path) return null;
                    if (decode(path[1]) !== workspace || decode(path[2]) !== repository) return null;
                    if (!path[3].toLowerCase().startsWith(label[1].toLowerCase())) return null;
                    const hash = path[3].toLowerCase();
                    if (seen.has(hash)) return null;
                    seen.add(hash);
                    return { row, hash, href: url.href };
                  } catch (_error) {
                    return null;
                  }
                }).filter(Boolean);
              const loading = Array.from(document.querySelectorAll(
                '[aria-busy="true"], [data-testid*="loading"], [data-testid*="spinner"], .loading, .spinner'
              )).some(visible);
              const signature = rows.map(({ row, hash, href }) =>
                `${hash}:${href}:${(row.textContent || '').replace(/\s+/g, ' ').trim()}`
              ).join('|');
              return { product: true, ready: !loading && rows.length > 0, loading, signature };
            })()
          JS
        end
      end
    end
  end
end
