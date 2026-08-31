# frozen_string_literal: true

module FetchUtil
  class Browser
    module SiteStabilization
      module GiteaFamilyStabilization
        private

        def stabilize_gitea_family_state(page, state_script)
          last_signature = nil
          stable_observations = 0
          incomplete_signature = nil
          incomplete_observations = 0
          terminal_incomplete = false
          observed = retry_until_timeout(capped_timeout(6.0), interval: 0.1) do
            state = safe_evaluate(page, state_script, default: nil)
            return false if state.is_a?(Hash) && state["product"] == false
            next false unless state.is_a?(Hash) && state["product"]

            unless state["ready"]
              if state["loading"]
                incomplete_signature = nil
                incomplete_observations = 0
              elsif state["signature"] == incomplete_signature
                incomplete_observations += 1
              else
                incomplete_signature = state["signature"]
                incomplete_observations = 1
              end
              if incomplete_observations >= 10
                terminal_incomplete = true
                next true
              end
              next false
            end

            incomplete_signature = nil
            incomplete_observations = 0
            if state["signature"] == last_signature
              stable_observations += 1
            else
              last_signature = state["signature"]
              stable_observations = 1
            end
            stable_observations >= 3
          end

          return false if terminal_incomplete

          settle_after_stabilization(0.5) if observed
          !!observed
        end
      end
    end
  end
end
