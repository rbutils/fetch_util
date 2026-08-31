# frozen_string_literal: true

module FetchUtil
  class Browser
    module SiteStabilization
      module GiteaFamilyVisibilityScript
        private

        def gitea_family_visibility_script
          <<~'JS'
            (() => {
              const subtreeHidden = (node) => {
                let current = node;
                while (current && current !== document) {
                  const style = getComputedStyle(current);
                  if (current.hidden || style.display === 'none') return true;
                  current = current.parentElement;
                }
                return false;
              };
              const visible = (node) => !!node && !subtreeHidden(node) &&
                !['hidden', 'collapse'].includes(getComputedStyle(node).visibility);
          JS
        end
      end
    end
  end
end
