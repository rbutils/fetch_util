# frozen_string_literal: true

module FetchUtil
  class Browser
    module SiteStabilization
      module GitlabRepo
        private

        def stabilize_gitlab_repo(page, deadline: stabilization_deadline)
          retry_until_timeout(capped_timeout(8.0, deadline: deadline), interval: 0.2, deadline: deadline) do
            safe_evaluate(page, <<~JS, default: 0).to_i >= 300
              (() => {
                const readme = document.querySelector('[data-testid="blob-viewer-content"] .blob-viewer[data-path="README.md"] .file-content.md, .blob-viewer[data-path="README.md"] .file-content.md');
                return readme ? (readme.innerText || readme.textContent || '').replace(/\s+/g, ' ').trim().length : 0;
              })()
            JS
          end

          settle_after_stabilization(0.25, deadline: deadline)
        end
      end
    end
  end
end
