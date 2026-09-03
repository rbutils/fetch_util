# frozen_string_literal: true

module FetchUtil
  class Browser
    module InteractionHelpers
      module TimingHelpers
        private

        def monotonic_now
          Process.clock_gettime(Process::CLOCK_MONOTONIC)
        end

        def stabilization_deadline
          monotonic_now + @timeout
        end

        def retry_until_timeout(timeout, interval: 0.2, deadline: nil)
          now = monotonic_now
          poll_deadline = now + timeout
          poll_deadline = [poll_deadline, deadline].min if deadline
          attempted = false

          loop do
            now = attempted ? monotonic_now : now
            return false if now > poll_deadline || (attempted && now >= poll_deadline)

            attempted = true
            result = yield
            completed_at = monotonic_now
            return true if result == true && completed_at <= poll_deadline

            remaining = poll_deadline - completed_at
            return false unless remaining.positive?

            delay = result.is_a?(Numeric) ? result : interval
            sleep [delay, remaining].min
          end
        end

        def capped_timeout(max_timeout, deadline: nil)
          timeout = [@timeout, max_timeout].min
          timeout = [timeout, deadline - monotonic_now].min if deadline
          [timeout, 0].max
        end

        def stabilization_time_remaining?(deadline)
          monotonic_now < deadline
        end

        def sleep_before_deadline(duration, deadline:)
          duration = [duration, deadline - monotonic_now].min
          sleep duration if duration.positive?
        end

        def settle_after_stabilization(max_wait, deadline: stabilization_deadline)
          sleep_before_deadline([@wait, max_wait].min, deadline: deadline) if @wait.positive?
        end

        def social_login_phase_pause(deadline: stabilization_deadline)
          duration = @wait.positive? ? [@wait, SOCIAL_LOGIN_PHASE_WAIT].min : SOCIAL_LOGIN_PHASE_WAIT
          sleep_before_deadline(duration, deadline: deadline)
        end
      end
    end
  end
end
