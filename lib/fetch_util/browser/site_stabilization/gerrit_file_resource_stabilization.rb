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

        def stabilize_gerrit_file_resource(page)
          ready = retry_until_timeout(capped_timeout(10.0), interval: 0.1) do
            state = gerrit_file_resource_state(page)
            return false if state.is_a?(Hash) && (state["product"] == false || state["status"] == "failed")

            state.is_a?(Hash) && state["status"] == "ready"
          end
          settle_after_stabilization(0.25) if ready
          ready
        end
      end
    end
  end
end
