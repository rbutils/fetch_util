# frozen_string_literal: true

module FetchUtil
  class Browser
    module SiteStabilization
      module GitlabMergeRequestResources
        include GitlabMergeRequestResourceState

        GITLAB_MERGE_REQUEST_RESOURCE_STABILIZATION_PROFILE = {
          host: true,
          path_query: lambda { |uri|
            uri.path.match?(%r{/-/merge_requests/\d+/(?:commits|pipelines|reports(?:/[^/]+)?|diffs)/?\z})
          },
          strategy: :stabilize_gitlab_merge_request_resource,
          fallthrough: true,
          notes: "Wait for host-agnostic GitLab merge-request resource pages.",
          tests: "spec/fetch_util/browser_stabilization_spec.rb"
        }.freeze

        private

        def stabilize_gitlab_merge_request_resource(page)
          last_signature = nil
          stable_observations = 0
          ready = retry_until_timeout(capped_timeout(8.0), interval: 0.1) do
            state = gitlab_merge_request_resource_state(page)
            return false if state.is_a?(Hash) && state["product"] == false
            next false unless state.is_a?(Hash) && state["product"] && state["ready"]

            if state["signature"] == last_signature
              stable_observations += 1
              stable_observations >= 3
            else
              last_signature = state["signature"]
              stable_observations = 1
              false
            end
          end

          settle_after_stabilization(0.5) if ready
          !!ready
        end
      end
    end
  end
end
