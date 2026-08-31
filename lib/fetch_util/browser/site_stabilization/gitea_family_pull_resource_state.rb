# frozen_string_literal: true

module FetchUtil
  class Browser
    module SiteStabilization
      module GiteaFamilyPullResourceState
        private

        def gitea_family_pull_resource_state_script
          <<~'JS'
              const loading = Array.from(root.querySelectorAll(
                '[aria-busy="true"], .is-loading, .tw-loading, .ui.active.loader'
              )).some(visible);
              const rows = surface === 'commits'
                ? Array.from(root.querySelectorAll(
                  '#commits-table > tbody.commit-list > tr, .commit-group .commits .commit'
                ))
                  .filter((row) => visibleMaterial(row))
                : [];
              const rowSignatures = rows.map((row) => [
                row.querySelector('.copy-commit-id[data-clipboard-text]')?.getAttribute('data-clipboard-text') || '',
                row.querySelector('a[href*="/commit/"]')?.getAttribute('href') || '',
                visibleText(row)
              ].join('|'));
              const pageData = runtime.pageData || {};
              const treeData = pageData.DiffFileTree || pageData.diffFileTree || [];
              const treeRoots = treeData.TreeRoot || treeData.treeRoot || treeData;
              const treeIds = [];
              const visit = (nodes) => (Array.isArray(nodes) ? nodes : [nodes]).filter(Boolean).forEach((node) => {
                const children = node.Children || node.children || [];
                if (children.length) return visit(children);
                const identity = String(node.NameHash || node.nameHash || '');
                if (identity) treeIds.push(identity.startsWith('diff-') ? identity : `diff-${identity}`);
              });
              const forgejoFiles = (pageData.diffFileInfo || {}).files || [];
              if (forgejoFiles.length) {
                forgejoFiles.forEach((file) => {
                  const identity = String(file.NameHash || file.nameHash || '');
                  if (identity) treeIds.push(identity.startsWith('diff-') ? identity : `diff-${identity}`);
                });
              } else {
                visit(treeRoots);
              }
              const boxes = surface === 'files'
                ? Array.from(root.querySelectorAll(
                  '#diff-file-boxes > .diff-file-box, .diff-file-box.file-content[id^="diff-"]'
                )).filter((box, index, all) => box.id !== 'diff-incomplete' && visibleMaterial(box) &&
                  !all.some((other, otherIndex) => otherIndex < index && other.contains(box)))
                : [];
              const boxSignatures = boxes.map((box) => [
                box.id || '',
                box.getAttribute('data-new-filename') || '',
                box.getAttribute('data-old-filename') || '',
                visibleText(box)
              ].join('|'));
              const deferred = surface === 'files'
                ? Array.from(root.querySelectorAll(
                  '#diff-show-more-files[data-href], .diff-load-button[data-href], ' +
                  '[data-global-click="diffLoadFileBody"][data-href]'
                )).filter(visible).map((node) => node.getAttribute('data-href') || '')
                : [];
              let selectedId = '';
              if (surface === 'files') {
                try { selectedId = decodeURIComponent((location.hash || '').replace(/^#/, '')); }
                catch (_error) { selectedId = ''; }
              }
              const selected = selectedId && boxes.find((box) => box.id === selectedId);
              const selectedBody = selected && selected.querySelector(
                '.diff-file-body, .file-body, .diff-rendered, .image-diff, .binary'
              );
              const excluded = 'button, [role="button"], .diff-load-button, [data-global-click="diffLoadFileBody"]';
              const selectedDeferred = !!(selected && Array.from(selected.querySelectorAll(
                '.diff-load-button[data-href], [data-global-click="diffLoadFileBody"][data-href]'
              )).find(visible));
              const selectedStructured = !!selectedBody && visibleNodes(selectedBody).some((candidate) => {
                if (candidate.closest(excluded)) return false;
                return candidate.matches('table, pre, code, img, ins, del, .diff-line');
              });
              const selectedLoaded = !!selectedBody && visibleMaterial(selectedBody, excluded) &&
                (!selectedDeferred || selectedStructured);
              const selectedIndexed = !!selectedId && treeIds.includes(selectedId);
              const selectedTerminal = !selectedId || selectedLoaded || selectedDeferred || (!selected && selectedIndexed);
              const material = surface === 'commits'
                ? rows.length > 0 || !!empty
                : treeIds.length > 0 || boxes.length > 0 || !!empty;
              return {
                product: true,
                ready: !loading && material && selectedTerminal,
                loading,
                signature: [
                  surface,
                  rowSignatures.join('\u001e'),
                  treeIds.join('\u001e'),
                  boxSignatures.join('\u001e'),
                  deferred.join('\u001e'),
                  selectedId,
                  selectedLoaded,
                  selectedDeferred,
                  !!empty,
                  loading
                ].join(':')
              };
            })()
          JS
        end
      end
    end
  end
end
