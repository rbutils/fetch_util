# frozen_string_literal: true

module FetchUtil
  class Browser
    module SiteStabilization
      module GitlabMergeRequestResourceStateScript
        include GitlabMergeRequestResourceVisibilityScript

        private

        def gitlab_merge_request_resource_state_script
          <<~JS
            (() => {
              const match = location.pathname.match(/\/-\/merge_requests\/\d+\/(commits|pipelines|reports(?:\/[^/]+)?|diffs)\/?$/);
              if (!match) return null;
              const surface = match[1].split('/')[0];
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

              const root = document.querySelector('main') ||
                document.querySelector('.content-wrapper') ||
                document.querySelector('.merge-request') ||
                document.querySelector('[data-page]') ||
                document.body;
              #{gitlab_merge_request_resource_visibility_script}
              const selectors = {
                commits: '[data-testid="commit-content"], [data-testid="commit-row"], .commit-row, li.commit',
                pipelines: '[data-testid="pipeline-table-row"], .pipeline-row, .ci-table tbody tr, table.pipelines tbody tr',
                reports: '[data-testid*="report"], .report-block, .mr-widget-reports > *, .report-section',
                diffs: 'diff-file[data-testid="rd-diff-file"], .diff-file, .file-holder, [data-testid="diff-file"]'
              };
              const candidates = Array.from(root.querySelectorAll(selectors[surface])).filter(material);
              const rows = candidates.filter((row, index) => !candidates.some(
                (other, otherIndex) => otherIndex < index && other.contains(row)
              ));
              const empty = Array.from(root.querySelectorAll(
                '[data-testid="empty-state"], .gl-empty-state, .empty-state, .nothing-here-block, .blank-state'
              )).find((node) => material(node) && materialText(node));
              const loading = Array.from(document.querySelectorAll('[aria-busy="true"], .gl-spinner, .loading, .is-loading'))
                .some(material);
              let selectedId = '';
              if (surface === 'diffs') {
                try { selectedId = decodeURIComponent((location.hash || '').replace(/^#/, '')); } catch (_error) { selectedId = ''; }
              }
              const explicit = (row) => row.id || row.getAttribute('data-diff-id') ||
                row.getAttribute('data-file-id') || row.getAttribute('data-file-path') || '';
              const reserved = new Set(rows.map(explicit).filter(Boolean));
              const assigned = new Set();
              const rowIds = rows.map((row, index) => {
                const value = explicit(row);
                if (value && !assigned.has(value)) {
                  assigned.add(value);
                  return value;
                }
                let identity = value
                  ? `${value}-fetch-util-${index + 1}`
                  : `fetch-util-diff-${index + 1}`;
                while (reserved.has(identity) || assigned.has(identity)) identity += '-';
                assigned.add(identity);
                return identity;
              });
              const selectedIndex = selectedId ? rowIds.indexOf(selectedId) : -1;
              const selected = !selectedId || selectedIndex >= 0 || !!empty;
              const bodySelector = [
                '[data-testid="rd-diff-file-body"]', '[data-testid="diff-file-body"]', '.diff-content',
                '.file-content', '.diff-table', 'table.diff-table', '.diff-line', '.line_content'
              ].join(', ');
              const selectedBody = !selectedId || !!empty || (selectedIndex >= 0 &&
                Array.from(rows[selectedIndex].querySelectorAll(bodySelector)).some((node) => materialText(node)));
              const textSize = rows.reduce((sum, row) => sum + materialText(row).length, 0);
              return {
                product: true,
                ready: !loading && selected && selectedBody && (rows.length > 0 || !!empty),
                signature: [surface, rows.length, !!empty, selected, selectedBody, textSize].join(':')
              };
            })()
          JS
        end
      end
    end
  end
end
