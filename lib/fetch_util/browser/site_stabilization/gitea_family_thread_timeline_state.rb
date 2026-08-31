# frozen_string_literal: true

module FetchUtil
  class Browser
    module SiteStabilization
      module GiteaFamilyThreadTimelineState
        private

        def gitea_family_thread_timeline_state_script
          <<~JS
              const candidates = Array.from(root.querySelectorAll([
                '.issue-content-left .timeline-item-group',
                '.issue-content-left .timeline-item',
                '.comment-list .timeline-item-group',
                '.comment-list .timeline-item'
              ].join(', ')));
              const rows = [];
              candidates.forEach((node) => {
                const group = node.closest('.timeline-item-group');
                const row = group && root.contains(group) ? group : node;
                if (subtreeHidden(row) || row.matches(
                  '.pull-merge-box, .timeline-item.comment.merge.box, .form, #timeline-comments-end'
                )) return;
                if (rows.some((existing) => existing === row || existing.contains(row))) return;
                rows.push(row);
              });
              const author = opening.querySelector(
                '.comment-header .author, .timeline-avatar + * .author, ' +
                '.comment-header-left a.tw-font-semibold, .comment-header-left span.tw-font-semibold, ' +
                '.comment-header a.tw-font-semibold, a.tw-font-semibold, .author'
              );
              const comments = rows.filter((row) => !!row.querySelector('.comment-body'));
              const events = rows.length - comments.length;
              const loading = Array.from(root.querySelectorAll(
                '[aria-busy="true"], .is-loading, .tw-loading, .ui.active.loader'
              )).some(visible);
              const openingBody = opening.querySelector('.comment-body');
              const rendered = openingBody && openingBody.querySelector('.render-content.markup');
              const openingReady = visible(openingBody) && !!(
                (rendered && (rendered.innerText || '').trim()) ||
                (openingBody && openingBody.querySelector('.no-content')) ||
                Array.from(openingBody.querySelectorAll('.dropzone-attachments, .attachments')).some(visible)
              );
              const rowSignatures = rows.map((row) => [
                row.id || '',
                row.className || '',
                Array.from(row.querySelectorAll('relative-time[datetime], time[datetime]'))
                  .map((time) => time.getAttribute('datetime') || '').join(','),
                (row.innerText || '').trim()
              ].join('|')).join('\u001e');
              return {
                product: true,
                ready: !loading && openingReady,
                loading,
                signature: [
                  rows.length,
                  comments.length,
                  events,
                  visible(author) ? (author.textContent || '').trim() : '',
                  openingReady,
                  loading,
                  rowSignatures
                ].join(':')
              };
            })()
          JS
        end
      end
    end
  end
end
