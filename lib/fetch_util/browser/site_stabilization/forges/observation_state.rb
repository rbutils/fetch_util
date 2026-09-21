# frozen_string_literal: true

module FetchUtil
  class Browser
    module SiteStabilization
      class ForgeObservationState
        REQUIRED_STABLE_OBSERVATIONS = 3
        REQUIRED_INCOMPLETE_OBSERVATIONS = 10

        attr_reader :terminal_incomplete
        alias terminal_incomplete? terminal_incomplete

        def initialize(reset_stability_when_incomplete:)
          @reset_stability_when_incomplete = reset_stability_when_incomplete
          @last_signature = nil
          @stable_observations = 0
          @incomplete_signature = nil
          @incomplete_observations = 0
          @terminal_incomplete = false
        end

        def observe(state)
          return observe_incomplete(state) unless state["ready"]

          @incomplete_signature = nil
          @incomplete_observations = 0
          if state["signature"] == @last_signature
            @stable_observations += 1
          else
            @last_signature = state["signature"]
            @stable_observations = 1
          end
          @stable_observations >= REQUIRED_STABLE_OBSERVATIONS
        end

        private

        def observe_incomplete(state)
          reset_stability if @reset_stability_when_incomplete
          if state["loading"]
            @incomplete_signature = nil
            @incomplete_observations = 0
          elsif state["signature"] == @incomplete_signature
            @incomplete_observations += 1
          else
            @incomplete_signature = state["signature"]
            @incomplete_observations = 1
          end
          @terminal_incomplete = @incomplete_observations >= REQUIRED_INCOMPLETE_OBSERVATIONS
        end

        def reset_stability
          @last_signature = nil
          @stable_observations = 0
        end
      end
    end
  end
end
