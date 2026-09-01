# frozen_string_literal: true

module FetchUtil
  class Browser
    module SiteStabilization
      module GerritChangeStabilization
        GERRIT_CHANGE_STABILIZATION_PROFILE = {
          host: true,
          path_query: ->(uri) { uri.path.match?(%r{/\+/\d+(?:/\d+)?/?\z}) },
          strategy: :stabilize_gerrit_change,
          fallthrough: true,
          notes: "Prepare product-matched Gerrit change REST resources.",
          tests: "spec/fetch_util/browser_stabilization_spec.rb"
        }.freeze

        private

        def stabilize_gerrit_change(page)
          ready = retry_until_timeout(capped_timeout(10.0), interval: 0.1) do
            state = gerrit_change_state(page)
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
