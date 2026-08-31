# frozen_string_literal: true

module FetchUtil
  class Browser
    module SiteStabilization
      module GiteaFamilyPullResources
        GITEA_FAMILY_PULL_RESOURCE_STABILIZATION_PROFILE = {
          host: true,
          path_query: lambda { |uri|
            uri.path.match?(%r{/(?:[^/]+/){2}pulls/\d+/(?:commits(?:/(?:list|[a-f\d]{4,64}))?|files(?:/(?:[a-f\d]{4,64}|[a-f\d]{7,64}\.\.?\.[a-f\d]{7,64}))?)/?\z}i)
          },
          strategy: :stabilize_gitea_family_pull_resource,
          fallthrough: true,
          notes: "Wait for host-agnostic Gitea and Forgejo pull-request resources.",
          tests: "spec/fetch_util/browser_stabilization_spec.rb"
        }.freeze

        private

        def stabilize_gitea_family_pull_resource(page)
          stabilize_gitea_family_state(
            page,
            gitea_family_pull_resource_product_state_script + gitea_family_pull_resource_state_script
          )
        end
      end
    end
  end
end
