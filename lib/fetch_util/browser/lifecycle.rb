# frozen_string_literal: true

module FetchUtil
  class Browser
    module Lifecycle
      private

      # Register the navigator patch once per process; Ferrum applies it to
      # each new page. A failed startup stays owned until shutdown succeeds.
      def ensure_browser
        @mutex.synchronize do
          shutdown_pending_browser
          return @ferrum if @ferrum

          browser = Ferrum::Browser.new(
            headless: true,
            browser_path: @browser_path,
            timeout: @timeout,
            window_size: [@viewport.fetch(:width), @viewport.fetch(:height)],
            browser_options: @browser_options
          )
          browser.evaluate_on_new_document(navigator_patch)
          @ferrum = browser
        rescue StandardError
          if browser
            @pending_shutdown = browser
            begin
              shutdown_pending_browser
            rescue StandardError
              nil
            end
          end
          raise
        end
      end

      def shutdown_pending_browser
        return unless @pending_shutdown

        @pending_shutdown.quit
        @pending_shutdown = nil
      end

      # Cleanup must preserve the primary extraction/setup exception. Retire a
      # process whose tab could not be closed rather than reusing a leaked tab.
      def close_page(page, observation: nil, attempt: 1, browser: nil)
        return true unless page

        observation ||= PhaseObservation.disabled
        begin
          observation.measure(:cleanup, attempt: attempt) { page.close }
          true
        rescue StandardError
          retire_browser(browser)
          false
        end
      end

      def retire_browser(browser)
        return unless browser

        @mutex.synchronize do
          if @ferrum.equal?(browser)
            @ferrum = nil
            @pending_shutdown = browser
          end
          begin
            shutdown_pending_browser
          rescue StandardError
            nil
          end
        end
      end
    end
  end
end
