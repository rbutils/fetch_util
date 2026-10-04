# frozen_string_literal: true

module FetchUtil
  class Browser
    module Lifecycle
      private

      # Keep ownership of a partially initialized browser until it is shut down.
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

      # A failed tab close poisons the owned process. Keep the operation's
      # primary result/error while preventing the leaked tab from being reused.
      def close_page(page, browser: nil)
        return true unless page

        page.close
        true
      rescue StandardError
        retire_browser(browser)
        false
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
