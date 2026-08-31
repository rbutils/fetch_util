# frozen_string_literal: true

module FetchUtil
  class Browser
    module SiteStabilization
      module GiteaFamilyThreadProductState
        private

        def gitea_family_thread_product_state_script
          gitea_family_visibility_script + <<~'JS'
            const runtime = window.config || {};
            const prefix = String(runtime.appSubUrl || '').replace(/^\/+|\/+$/g, '');
            const routePrefix = prefix ? `/${prefix}` : '';
            const escaped = routePrefix.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
            const match = location.pathname.match(new RegExp(
              `^${escaped}/([^/]+)/([^/]+)/(issues|pulls)/(\\d+)\\/?$`
            ));
            if (!match) return null;
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
              const value = `${node.textContent || ''} ${node.getAttribute('href') || ''}`;
              if (/\b(?:forgejo|gitea)\b/i.test(value)) brandValues.push(value);
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
            const root = document.querySelector(
              '.page-content.repository.view.issue .issue-content, .repository.view.issue .issue-content, .page-content .issue-content'
            );
            const opening = root && root.querySelector(
              '.issue-content-left .timeline-item.comment.issue-content-comment[id^="issue-"], ' +
              '.issue-content-left .timeline-item.comment.issue-content-comment, ' +
              '.issue-content-left .timeline-item.comment.first[id^="issue-"], ' +
              '.issue-content-left .timeline-item.comment.first, ' +
              '.comment-list .timeline-item.comment.issue-content-comment, ' +
              '.comment-list .timeline-item.comment.first'
            );
            const openingBody = opening && opening.querySelector('.comment-body');
            const rendered = openingBody && openingBody.querySelector('.render-content.markup');
            const empty = openingBody && openingBody.querySelector('.no-content');
            const attachment = openingBody && Array.from(openingBody.querySelectorAll(
              '.dropzone-attachments a[href], .attachments a[href]'
            )).some(visible);
            const structure = !!(root && opening && openingBody &&
              root.querySelector('.issue-content-left .comment-list, .issue-content-left.comment-list') &&
              opening.querySelector('.content.comment-container, .comment-body') &&
              ((visible(rendered) && (rendered.innerText || '').trim()) || visible(empty) || attachment));
            const product = runtimeMatch && structure && (branded || runtimeAsset);
            if (!product) return { product: false, ready: false, signature: '' };
          JS
        end
      end
    end
  end
end
