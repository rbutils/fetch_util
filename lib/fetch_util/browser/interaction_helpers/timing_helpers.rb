# frozen_string_literal: true

module FetchUtil
  class Browser
    module InteractionHelpers
      module TimingHelpers
        private

        def retry_until_timeout(timeout, interval: 0.2)
          deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + timeout

          loop do
            result = yield
            return true if result == true
            return false if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline

            sleep(result.is_a?(Numeric) ? result : interval)
          end
        end

        def capped_timeout(max_timeout)
          [@timeout, max_timeout].min
        end

        def settle_after_stabilization(max_wait)
          sleep [@wait, max_wait].min if @wait.positive?
        end

        def social_login_phase_pause
          if @wait.positive?
            settle_after_stabilization(SOCIAL_LOGIN_PHASE_WAIT)
          else
            sleep SOCIAL_LOGIN_PHASE_WAIT
          end
        end
      end
    end
  end
end
