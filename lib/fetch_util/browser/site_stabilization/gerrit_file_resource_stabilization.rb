# frozen_string_literal: true

module FetchUtil
  class Browser
    module SiteStabilization
      module GerritFileResourceStabilization
        GERRIT_FILE_RESOURCE_STABILIZATION_PROFILE = {
          host: true,
          path_query: ->(uri) { uri.path.match?(%r{/\+/\d+/(?:-?\d+\.\.)?\d+/.+}) },
          strategy: :stabilize_gerrit_file_resource,
          fallthrough: true,
          notes: "Prepare product-matched Gerrit file diff REST resources.",
          tests: "spec/fetch_util/browser_stabilization_spec.rb"
        }.freeze

        private

        def stabilize_gerrit_file_resource(page, deadline: stabilization_deadline)
          state = nil
          ready = retry_until_timeout(
            capped_timeout(10.0, deadline: deadline),
            interval: 0.1,
            deadline: deadline
          ) do
            state = gerrit_file_resource_state(page)
            return false if state.is_a?(Hash) && (state["product"] == false || state["status"] == "failed")

            state.is_a?(Hash) && state["status"] == "ready"
          end
          fail_gerrit_file_resource_preparation(page) if !ready && state.is_a?(Hash) && state["status"] == "loading"
          settle_after_stabilization(0.25, deadline: deadline) if ready
          ready
        end
      end
    end
  end
end
