# frozen_string_literal: true

module FetchUtil
  class Browser
    module SiteStabilization
      module BitbucketCloudPullResources
        BITBUCKET_CLOUD_PULL_RESOURCE_STABILIZATION_PROFILE = {
          host: true,
          path_query: ->(uri) { uri.path.match?(%r{\A/[^/]+/[^/]+/pull-requests/\d+/(?:commits|diff)/?\z}) },
          strategy: :stabilize_bitbucket_cloud_pull_resource,
          fallthrough: true,
          notes: "Wait for product-matched Bitbucket Cloud pull-request commit or diff resources.",
          tests: "spec/fetch_util/browser_stabilization_spec.rb"
        }.freeze

        private

        def stabilize_bitbucket_cloud_pull_resource(page, deadline: stabilization_deadline)
          observation = ForgeObservationState.new(reset_stability_when_incomplete: true)
          observed = retry_until_timeout(
            capped_timeout(6.0, deadline: deadline),
            interval: 0.1,
            deadline: deadline
          ) do
            state = safe_evaluate(page, bitbucket_cloud_pull_resource_state_script, default: nil)
            return false if state.is_a?(Hash) && state["product"] == false
            next false unless state.is_a?(Hash) && state["product"]

            observation.observe(state)
          end

          return false if observation.terminal_incomplete?

          fail_bitbucket_cloud_pull_diff_preparation(page) unless observed

          settle_after_stabilization(0.5, deadline: deadline) if observed
          !!observed
        end
      end
    end
  end
end
