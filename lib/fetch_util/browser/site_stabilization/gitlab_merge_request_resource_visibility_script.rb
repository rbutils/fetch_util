# frozen_string_literal: true

module FetchUtil
  class Browser
    module SiteStabilization
      module GitlabMergeRequestResourceVisibilityScript
        private

        def gitlab_merge_request_resource_visibility_script
          <<~JS
            const subtreeHidden = (node) => {
              let current = node;
              while (current && current !== document) {
                const style = getComputedStyle(current);
                if (current.hidden || style.display === 'none') return true;
                current = current.parentElement;
              }
              return false;
            };
            const materialText = (node) => {
              if (!node || subtreeHidden(node)) return '';
              const collect = (current) => {
                if (current.nodeType === Node.TEXT_NODE) {
                  const style = getComputedStyle(current.parentElement);
                  return /^(?:hidden|collapse)$/.test(style.visibility) ? '' : current.nodeValue;
                }
                if (current.nodeType !== Node.ELEMENT_NODE) return '';
                const style = getComputedStyle(current);
                if (current.hidden || style.display === 'none') return '';
                return Array.from(current.childNodes).map(collect).join('');
              };
              return collect(node).trim();
            };
            const material = (node) => {
              if (subtreeHidden(node)) return false;
              return !/^(?:hidden|collapse)$/.test(getComputedStyle(node).visibility) || !!materialText(node);
            };
          JS
        end
      end
    end
  end
end
