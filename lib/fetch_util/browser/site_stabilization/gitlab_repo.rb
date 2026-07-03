# frozen_string_literal: true

module FetchUtil
  class Browser
    module SiteStabilization
      module GitlabRepo
        private

        def gitlab_repo_url?(url)
          uri = URI.parse(url)
          host = uri.host.to_s.downcase
          (host == "gitlab.com" || host.end_with?(".gitlab.com")) && uri.path.split("/").reject(&:empty?).length == 2
        rescue URI::InvalidURIError
          false
        end

        def stabilize_gitlab_repo(page)
          retry_until_timeout(capped_timeout(8.0), interval: 0.2) do
            safe_evaluate(page, <<~JS, default: 0).to_i >= 300
              (() => {
                const readme = document.querySelector('[data-testid="blob-viewer-content"] .blob-viewer[data-path="README.md"] .file-content.md, .blob-viewer[data-path="README.md"] .file-content.md');
                return readme ? (readme.innerText || readme.textContent || '').replace(/\s+/g, ' ').trim().length : 0;
              })()
            JS
          end

          settle_after_stabilization(0.25)
        end
      end
    end
  end
end
