# frozen_string_literal: true

module FetchUtil
  class Browser
    module SiteStabilization
      module GitlabStabilization
        private

        def stabilize_gitlab_state(deadline: stabilization_deadline)
          last_signature = nil
          stable_observations = 0
          ready = retry_until_timeout(capped_timeout(8.0, deadline: deadline), interval: 0.1, deadline: deadline) do
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

          settle_after_stabilization(0.5, deadline: deadline) if ready
          !!ready
        end
      end
    end
  end
end
