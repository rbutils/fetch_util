# frozen_string_literal: true

require "English"

module FetchUtil
  class Browser
    module FeedMaterialization
      SLOT_PROBE = File.read(File.expand_path("feed_materialization/slots.js", __dir__)).freeze
      PARTIAL_WARNING = "unmaterialized_feed_entries"

      private

      def positive_feed_height(value)
        height = Integer(value.to_s, 10)
        return height if height.positive?

        raise ArgumentError
      rescue ArgumentError, TypeError
        raise InputError, "feed_hydration_max_height must be a positive integer"
      end

      # Only Fetcher's extraction block uses this adapter. Ordinary with_page
      # callbacks retain the original live page and viewport semantics.
      def with_materialized_feed(page)
        original = page.evaluate_func(SLOT_PROBE, nil)
        return yield unless original

        state = original
        deadline = monotonic_now + @feed_hydration_timeout
        expanded = false
        frozen = false
        begin
          while state.fetch("remaining").any? && monotonic_now < deadline
            height = [state.fetch("targetHeight"), @feed_hydration_max_height].min
            break if height <= state.fetch("height")

            expanded = true
            set_feed_viewport(page, original, height)
            loop do
              sleep 0.1
              state = page.evaluate_func(SLOT_PROBE, original.fetch("ids"))
              break if state.fetch("remaining").empty? || monotonic_now >= deadline || state.fetch("targetHeight") > height
            end
            break if height == @feed_hydration_max_height
          end
          if expanded
            frozen = true
            page.command("Page.setWebLifecycleState", state: "frozen")
            set_feed_viewport(page, original, original.fetch("height"))
            state = page.evaluate_func(SLOT_PROBE, original.fetch("ids"))
          end
          payload = yield
          if state.fetch("remaining").any?
            payload = payload.merge("warnings" => (Array(payload["warnings"]) + [PARTIAL_WARNING]).uniq)
          end
          payload
        ensure
          restore_feed_page(page, original, expanded: expanded, frozen: frozen)
        end
      end

      def set_feed_viewport(page, original, height)
        page.command(
          "Emulation.setDeviceMetricsOverride",
          width: original.fetch("width"),
          height: height,
          deviceScaleFactor: original.fetch("scale"),
          mobile: false
        )
      end

      def restore_feed_page(page, original, expanded:, frozen:)
        active_error = $ERROR_INFO
        cleanup_error = nil
        begin
          set_feed_viewport(page, original, original.fetch("height")) if expanded
        rescue Ferrum::Error => e
          cleanup_error = e
        ensure
          begin
            page.command("Page.setWebLifecycleState", state: "active") if frozen
          rescue Ferrum::Error => e
            cleanup_error ||= e
          end
        end
        return unless cleanup_error

        retire_browser(@ferrum)
        raise cleanup_error unless active_error
      end
    end
  end
end
