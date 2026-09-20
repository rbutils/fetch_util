# frozen_string_literal: true

module FetchUtil
  class Browser
    module SiteStabilization
      module BitbucketCloudPullDiffProductState
        private

        def bitbucket_cloud_pull_diff_product_state_script
          <<~'JS'
            const fetchUtilBitbucketDiffProduct = () => {
              const match = location.pathname.match(/^\/([^/]+)\/([^/]+)\/pull-requests\/(\d+)\/diff\/?$/);
              if (!match) return { product: false };
              const decode = (value) => { try { return decodeURIComponent(value); } catch (_error) { return ''; } };
              const route = { workspace: decode(match[1]), repository: decode(match[2]), number: match[3] };
              if (!route.workspace || !route.repository || route.workspace.includes('/') || route.repository.includes('/')) {
                return { product: false };
              }

              const current = (((window.__initial_state__ || {}).section || {}).repository || {}).currentRepository || {};
              const publicRepository = current.is_private === false || current.isPrivate === false ||
                current.visibility === 'public';
              const runtime = current.type === 'repository' && publicRepository &&
                String(current.full_name || '').toLowerCase() ===
                  `${route.workspace}/${route.repository}`.toLowerCase();
              const application = document.querySelector('meta[name="application-name"]');
              const branded = /^Bitbucket$/i.test((application && application.content || '').trim());
              const asset = Array.from(document.querySelectorAll('script[src], link[href]')).some((node) => {
                const value = node.getAttribute('src') || node.getAttribute('href') || '';
                return /(?:frontbucket|bbc-frontbucket-static|bitbucket)[^/]*\/(?:assets|static)\//i.test(value) ||
                  /\/(?:assets|static)\/[^?#]*(?:frontbucket|bitbucket)/i.test(value);
              });
              const header = document.querySelector('[data-testid="pr-header"]');
              if (!(runtime && branded && (header || asset))) return { product: false };

              const apiMeta = document.querySelector('meta[name="bb-api-canon-url"]');
              let apiOrigin;
              try { apiOrigin = new URL(apiMeta && apiMeta.content || '', location.href); } catch (_error) {
                return { product: true, route, error: 'missing Bitbucket API metadata route' };
              }
              if (!/^https?:$/.test(apiOrigin.protocol) || apiOrigin.username || apiOrigin.password) {
                return { product: true, route, error: 'invalid Bitbucket API metadata route' };
              }
              const proxyPrefix = '/!api/2.0';
              const metadataUrl = location.origin + proxyPrefix + '/repositories/' +
                encodeURIComponent(route.workspace) + '/' + encodeURIComponent(route.repository) +
                '/pullrequests/' + route.number;
              return { product: true, route, metadataUrl, proxyPrefix };
            };
          JS
        end
      end
    end
  end
end
