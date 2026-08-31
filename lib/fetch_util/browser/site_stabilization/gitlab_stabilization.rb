# frozen_string_literal: true

module FetchUtil
  class Browser
    module SiteStabilization
      module GitlabStabilization
        private

        def stabilize_gitlab_state
          last_signature = nil
          stable_observations = 0
          ready = retry_until_timeout(capped_timeout(8.0), interval: 0.1) do
            state = yield
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
