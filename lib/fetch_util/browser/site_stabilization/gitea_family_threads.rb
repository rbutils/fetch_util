# frozen_string_literal: true

module FetchUtil
  class Browser
    module SiteStabilization
      module GiteaFamilyThreads
        GITEA_FAMILY_THREAD_STABILIZATION_PROFILE = {
          host: true,
          path_query: ->(uri) { uri.path.match?(%r{/(?:[^/]+/){2}(?:issues|pulls)/\d+/?\z}) },
          strategy: :stabilize_gitea_family_thread,
          fallthrough: true,
          notes: "Wait for host-agnostic Gitea and Forgejo issue and pull-request conversations.",
          tests: "spec/fetch_util/browser_stabilization_spec.rb"
        }.freeze

        private

        def stabilize_gitea_family_thread(page)
          stabilize_gitea_family_state(
            page,
            gitea_family_thread_product_state_script + gitea_family_thread_timeline_state_script
          )
        end
      end
    end
  end
end
