# frozen_string_literal: true

module FetchUtil
  class Browser
    module SiteStabilization
      module GiteaFamilyPullResourceProductState
        private

        def gitea_family_pull_resource_product_state_script
          gitea_family_visibility_script + <<~'JS'
            const visibleNodes = (node) => [node, ...node.querySelectorAll('*')].filter(visible);
            const ownText = (node) => Array.from(node.childNodes)
              .filter((child) => child.nodeType === Node.TEXT_NODE)
              .map((child) => child.textContent || '').join(' ').trim();
            const visibleText = (node) => visibleNodes(node).map(ownText).filter(Boolean).join(' ');
            const visibleMaterial = (node, excluded) => !!node && visibleNodes(node).some((candidate) => {
              if (excluded && candidate.closest(excluded)) return false;
              return !!ownText(candidate) || candidate.matches('table, pre, code, img, ins, del, .diff-line');
            });
            const runtime = window.config || {};
            const prefix = String(runtime.appSubUrl || '').replace(/^\/+|\/+$/g, '');
            const routePrefix = prefix ? `/${prefix}` : '';
            const escaped = routePrefix.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
            const match = location.pathname.match(new RegExp(
              `^${escaped}/([^/]+)/([^/]+)/pulls/(\\d+)/(commits|files)(?:/([^/]+))?\\/?$`
            ));
            if (!match) return null;
            const routeSurface = match[4];
            const detail = match[5] || '';
            const validDetail = routeSurface === 'commits'
              ? (!detail || detail === 'list' || /^[a-f0-9]{4,64}$/i.test(detail))
              : (!detail || /^[a-f0-9]{4,64}$/i.test(detail) ||
                /^[a-f0-9]{7,64}\.\.?\.[a-f0-9]{7,64}$/i.test(detail));
            if (!validDetail) return null;
            const surface = routeSurface === 'commits' && detail && detail !== 'list' ? 'files' : routeSurface;
            let runtimeMatch = false;
            try {
              const app = new URL(runtime.appUrl || '', location.href);
              runtimeMatch = !!runtime.appUrl && app.origin === location.origin &&
                app.pathname.replace(/\/$/, '') === routePrefix;
            } catch (_error) { runtimeMatch = false; }
            const brandValues = Array.from(document.querySelectorAll(
              'meta[name="author"], meta[name="generator"], meta[property="og:site_name"]'
            )).map((node) => (node.content || '').trim());
            Array.from(document.querySelectorAll('footer a[href]')).forEach((node) => {
              const text = (node.textContent || '').trim();
              const href = node.getAttribute('href') || '';
              if (/powered by.*\b(?:forgejo|gitea)\b/i.test(text) || /\b(?:forgejo|gitea)\b/i.test(href)) {
                brandValues.push(`${text} ${href}`);
              }
            });
            brandValues.push((runtime.assetVersionEncoded || '').trim());
            const branded = /\b(?:forgejo|gitea)\b/i.test(brandValues.join(' '));
            let runtimeAsset = false;
            try {
              const assetUrl = new URL(runtime.assetUrlPrefix || '', location.href);
              const expectedPath = `${routePrefix}/assets`;
              runtimeAsset = !!runtime.assetUrlPrefix && assetUrl.origin === location.origin &&
                assetUrl.pathname.replace(/\/$/, '') === expectedPath &&
                Array.from(document.querySelectorAll('script[src], link[href]')).some((node) => {
                  const value = node.getAttribute('src') || node.getAttribute('href') || '';
                  const url = new URL(value, location.href);
                  return url.origin === location.origin && url.pathname.startsWith(`${expectedPath}/`);
                });
            } catch (_error) { runtimeAsset = false; }
            const rootSelectors = surface === 'commits'
              ? ['.page-content.repository.view.issue.pull.commits', '.repository.view.issue.pull.commits',
                '.page-content.repository.view.issue.pull']
              : ['.page-content.repository.view.issue.pull.files.diff', '.repository.view.issue.pull.files.diff',
                '.page-content.repository.view.issue.pull'];
            let root = null;
            rootSelectors.some((selector) => { root = document.querySelector(selector); return !!root; });
            const empty = root && Array.from(root.querySelectorAll(
              '.ui.message.empty, .empty-state, .nothing-here, .no-results, [data-testid="empty-state"]'
            )).find((node) => visible(node) && (node.textContent || '').trim());
            const structure = surface === 'commits'
              ? !!(root && (root.querySelector(
                '#commits-table > tbody.commit-list, .commit-group .commits .commit'
              ) || empty))
              : !!(root && (root.querySelector('#diff-container, #diff-file-boxes, #diff-file-tree') || empty));
            const product = runtimeMatch && structure && (branded || runtimeAsset);
            if (!product) return { product: false, ready: false, signature: '' };
          JS
        end
      end
    end
  end
end
