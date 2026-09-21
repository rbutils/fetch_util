# frozen_string_literal: true

module FetchUtil
  class Browser
    module SiteStabilization
      module GiteaFamilyStabilization
        private

        def stabilize_gitea_family_state(page, state_script, deadline: stabilization_deadline)
          observation = ForgeObservationState.new(reset_stability_when_incomplete: false)
          observed = retry_until_timeout(
            capped_timeout(6.0, deadline: deadline),
            interval: 0.1,
            deadline: deadline
          ) do
            state = safe_evaluate(page, state_script, default: nil)
            return false if state.is_a?(Hash) && state["product"] == false
            next false unless state.is_a?(Hash) && state["product"]

            observation.observe(state)
          end

          return false if observation.terminal_incomplete?

          settle_after_stabilization(0.5, deadline: deadline) if observed
          !!observed
        end
      end
    end
  end
end
