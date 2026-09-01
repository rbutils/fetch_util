# frozen_string_literal: true

module FetchUtil
  class Browser
    module SiteStabilization
      module BitbucketCloudThreadState
        private

        def bitbucket_cloud_thread_state_script
          <<~'JS'
            (() => {
              const match = location.pathname.match(/^\/([^/]+)\/([^/]+)\/pull-requests\/(\d+)(?:\/overview)?\/?$/);
              if (!match) return { product: false, ready: false, loading: false, signature: '' };

              const decoded = (value) => {
                try { return decodeURIComponent(value); } catch (_error) { return value; }
              };
              const community = `${decoded(match[1])}/${decoded(match[2])}`.toLowerCase();
              const state = window.__initial_state__ || {};
              const repository = (((state.section || {}).repository || {}).currentRepository) || null;
              const publicRepository = !!repository && (
                repository.is_private === false || repository.isPrivate === false || repository.visibility === 'public'
              );
              const runtime = publicRepository && repository.type === 'repository' &&
                String(repository.full_name || '').trim().toLowerCase() === community;
              const application = document.querySelector('meta[name="application-name"]');
              const branded = /^Bitbucket$/i.test((application && application.content || '').trim());
              const asset = Array.from(document.querySelectorAll('script[src], link[href]')).some((node) => {
                const value = node.getAttribute('src') || node.getAttribute('href') || '';
                return /(?:frontbucket|bbc-frontbucket-static|bitbucket)[^/]*\/(?:assets|static)\//i.test(value) ||
                  /\/(?:assets|static)\/[^?#]*(?:frontbucket|bitbucket)/i.test(value);
              });
              const header = document.querySelector('[data-testid="pr-header"]');
              const root = header && (header.closest('main') || document.querySelector('main') || header.parentElement) ||
                document.querySelector('main');
              const opening = root && root.querySelector(
                '#pull-request-description-panel, section[aria-label="Pull request description"], section[aria-label="Description"]'
              );
              const product = runtime && branded && !!(header || asset);
              if (!product) return { product: false, ready: false, loading: false, signature: '' };

              const nodeVisible = (node) => {
                let current = node;
                while (current && current !== document) {
                  const style = getComputedStyle(current);
                  if (current.hidden || style.display === 'none') return false;
                  current = current.parentElement;
                }
                const visibility = getComputedStyle(node).visibility;
                return visibility !== 'hidden' && visibility !== 'collapse';
              };
              const subtreeVisible = (node) => {
                if (nodeVisible(node)) return true;
                return Array.from(node.querySelectorAll('*')).some((child) => {
                  const material = (child.textContent || '').trim() ||
                    child.matches('img[src], video, pre, table, ul, ol');
                  return material && nodeVisible(child);
                });
              };
              const comments = Array.from(root.querySelectorAll('[data-testid="comment"]')).filter(subtreeVisible);
              const owned = (node, selector) => Array.from(node.querySelectorAll(selector)).find(
                (candidate) => candidate.closest('[data-testid="comment"]') === node
              );
              const loading = Array.from(root.querySelectorAll(
                '[aria-busy="true"], [data-testid*="loading" i], [data-testid*="spinner" i], .spinner, .loading'
              )).some(subtreeVisible);
              const openingReady = !!opening && subtreeVisible(opening) && !!(
                (opening.textContent || '').trim() || opening.querySelector('img[src], video, pre, table, ul, ol')
              );
              const commentBodies = comments.filter((node) => {
                const body = owned(node, '[data-testid="comment-content"], comment-content');
                return body && subtreeVisible(body) && !!((body.textContent || '').trim() || body.querySelector('img[src], pre, table'));
              });
              const explicitZero = /\b0\s+comments?\b/i.test(root.textContent || '');
              const rowSignatures = commentBodies.map((node, index) => {
                const link = owned(node, 'a[href*="#comment-"]');
                return node.id || node.getAttribute('data-comment-id') || (link && link.href) ||
                  `${index}:${(node.textContent || '').trim().slice(0, 120)}`;
              });
              return {
                product: true,
                ready: !!header && openingReady && !loading && (commentBodies.length > 0 || explicitZero),
                loading: loading,
                signature: [openingReady, commentBodies.length, explicitZero, loading, rowSignatures.join('|')].join(':')
              };
            })()
          JS
        end
      end
    end
  end
end
