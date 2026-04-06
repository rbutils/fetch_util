# frozen_string_literal: true

module FetchUtil
  class Browser
    module InteractionHelpers
      # rubocop:disable Metrics/ModuleLength
      module DomInteraction
        private

        def click_visible_button_by_text(page, primary_labels, fallback_labels = [], selectors: 'button, [role="button"]')
          groups = [Array(primary_labels), Array(fallback_labels)].reject(&:empty?)

          safe_evaluate(page, <<~JS)
            (() => {
              const labelGroups = #{JSON.generate(groups)};
              const queryAllRoots = (selectors) => {
                const matches = [];
                const queue = [document];
                while (queue.length) {
                  const root = queue.shift();
                  if (!root || !root.querySelectorAll) continue;
                  root.querySelectorAll(selectors).forEach((el) => matches.push(el));
                  root.querySelectorAll('*').forEach((el) => {
                    if (el.shadowRoot) queue.push(el.shadowRoot);
                  });
                }
                return matches;
              };
              const buttons = queryAllRoots(#{selectors.to_json});

              const visible = (el) => {
                const rect = el.getBoundingClientRect();
                const style = window.getComputedStyle(el);
                return rect.width > 0 && rect.height > 0 && style.visibility !== 'hidden' && style.display !== 'none';
              };

              const textFor = (el) => [el.innerText, el.textContent, el.value, el.getAttribute('aria-label'), el.getAttribute('title')]
                .filter(Boolean)
                .join(' ')
                .replace(/\s+/g, ' ')
                .trim()
                .toLowerCase();

              for (const labels of labelGroups) {
                const allowed = new Set(labels.map((label) => String(label).toLowerCase()));
                for (const button of buttons) {
                  if (!visible(button) || !allowed.has(textFor(button))) continue;
                  button.click();
                  return true;
                }
              }

              return false;
            })()
          JS
        end

        def dismiss_overlay_dialog(page, close_selectors:, dialog_selectors:, dialog_pattern:, overlay_selectors: [], close_label_pattern: nil,
                                   allow_empty_close_label: false)
          config = {
            closeSelectors: Array(close_selectors),
            dialogSelectors: Array(dialog_selectors),
            overlaySelectors: Array(overlay_selectors),
            dialogPattern: dialog_pattern,
            closeLabelPattern: close_label_pattern,
            allowEmptyCloseLabel: allow_empty_close_label
          }

          safe_evaluate(page, <<~JS)
            (() => {
              const config = #{JSON.generate(config)};
              const dialogPattern = new RegExp(config.dialogPattern || '', 'i');
              const closeLabelPattern = config.closeLabelPattern ? new RegExp(config.closeLabelPattern, 'i') : null;
              const queryAllRoots = (selectors) => {
                const matches = [];
                const queue = [document];
                while (queue.length) {
                  const root = queue.shift();
                  if (!root || !root.querySelectorAll) continue;
                  root.querySelectorAll(selectors).forEach((el) => matches.push(el));
                  root.querySelectorAll('*').forEach((el) => {
                    if (el.shadowRoot) queue.push(el.shadowRoot);
                  });
                }
                return matches;
              };

              const visible = (el) => {
                const rect = el.getBoundingClientRect();
                const style = window.getComputedStyle(el);
                return rect.width > 0 && rect.height > 0 && style.visibility !== 'hidden' && style.display !== 'none';
              };

              const textFor = (el) => (el && (el.innerText || el.textContent || el.getAttribute('aria-label') || '') || '')
                .replace(/\s+/g, ' ')
                .trim();

              const restoreScroll = () => {
                if (document.body) document.body.style.overflow = 'auto';
                if (document.documentElement) document.documentElement.style.overflow = 'auto';
              };

              const matchingNodes = [];
              const collectMatchingNodes = (selectors, requireOverlayPrompt) => {
                const selectorText = (selectors || []).join(', ');
                if (!selectorText) return;

                queryAllRoots(selectorText).forEach((node) => {
                  const text = textFor(node).slice(0, 2000);
                  if (!dialogPattern.test(text)) return;
                  if (requireOverlayPrompt && !/log in|sign up/i.test(text)) return;
                  if (!matchingNodes.includes(node)) matchingNodes.push(node);
                });
              };

              collectMatchingNodes(config.dialogSelectors, false);
              collectMatchingNodes(config.overlaySelectors, true);

              const withinMatchingNode = (node) => {
                if (!node || matchingNodes.length === 0) return true;
                return matchingNodes.some((container) => container === node || container.contains(node));
              };

              const clickCloseButton = () => {
                const selectorText = (config.closeSelectors || []).join(', ');
                if (!selectorText) return false;
                const candidates = queryAllRoots(selectorText);

                for (const candidate of candidates) {
                  const button = candidate.closest('button, [role="button"]') || candidate;
                  if (!button || !visible(button)) continue;
                  if (!withinMatchingNode(candidate) && !withinMatchingNode(button)) continue;

                  const label = textFor(button).toLowerCase();
                  const labelMatches = !closeLabelPattern || closeLabelPattern.test(label) || (config.allowEmptyCloseLabel && label === '');
                  if (!labelMatches) continue;

                  button.click();
                  restoreScroll();
                  return true;
                }

                return false;
              };

              if (clickCloseButton()) return true;

              let removed = false;
              matchingNodes.forEach((node) => {
                node.remove();
                removed = true;
              });

              if (removed) restoreScroll();
              return removed;
            })()
          JS
        end

        def safe_evaluate(page, script, default: false)
          page.evaluate(script)
        rescue Ferrum::JavaScriptError, Ferrum::TimeoutError
          default
        end

        def symbolize_hash(hash)
          result = {}
          hash.each do |key, value|
            result[key.to_sym] = value
          end
          result
        end
      end
      # rubocop:enable Metrics/ModuleLength
    end
  end
end
