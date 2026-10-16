# frozen_string_literal: true

module FetchUtil
  class Extractor
    class OwnedEvaluation
      def initialize(page, script, budget:)
        @page = page
        @script = script
        @budget = budget
        @group = "fetch-util-owned-#{object_id}"
      end

      def call
        @deadline = monotonic_time + @budget
        response = command(
          "Runtime.callFunctionOn",
          functionDeclaration: "function() { return #{@script}; }",
          executionContextId: @page.main_frame.execution_id!,
          objectGroup: @group,
          returnByValue: false
        ).fetch("result")
        @object_id = response["objectId"]
        return response["value"] unless @object_id

        properties = command("Runtime.getProperties", objectId: @object_id, ownProperties: true).fetch("result")
        values = properties.to_h { |property| [property.fetch("name"), property["value"]] }
        unless values.dig("owned", "type") == "boolean" && values.dig("finish", "type") == "function" &&
               (!values.key?("prepare") || values.dig("prepare", "type") == "function")
          raise ExtractionError, "Invalid owned extraction work descriptor"
        end

        if values.dig("owned", "value") == true
          if values.key?("prepare")
            collect_completed_work
            command(
              "Runtime.callFunctionOn",
              objectId: @object_id,
              functionDeclaration: "function() { return this.prepare(); }",
              returnByValue: false
            )
          end
          collect_completed_work
        end
        command(
          "Runtime.callFunctionOn",
          objectId: @object_id,
          functionDeclaration: "function() { return this.finish(); }",
          returnByValue: true
        ).fetch("result")["value"]
      ensure
        release_work
      end

      private

      def monotonic_time
        Process.clock_gettime(Process::CLOCK_MONOTONIC)
      end

      def command(method, **parameters)
        remaining = @deadline - monotonic_time
        raise Ferrum::TimeoutError, "Owned extraction deadline exceeded" unless remaining.positive?

        @page.timeout = remaining if @page.respond_to?(:timeout=)
        response = @page.command(method, **parameters)
        details = response["exceptionDetails"]
        result = response["result"]
        if details || result.is_a?(Hash) && result["subtype"] == "error"
          error = details && details["exception"]
          error ||= result if result.is_a?(Hash)
          error ||= { "className" => "Error", "description" => details && details["text"] }
          raise Ferrum::JavaScriptError.new(error, details && details["stackTrace"])
        end

        response
      end

      def collect_completed_work
        command("HeapProfiler.collectGarbage")
      rescue Ferrum::BrowserError
        # Older injected transports can lack this optional browser command.
        # The complete owned work still runs; no extraction is retried.
        nil
      end

      def release_work
        if @object_id
          @page.command(
            "Runtime.callFunctionOn",
            objectId: @object_id,
            functionDeclaration: "function() { if (typeof this.dispose === 'function') this.dispose(); }",
            returnByValue: true,
            async: true
          )
        end
      rescue Ferrum::Error
        nil
      ensure
        begin
          @page.command("Runtime.releaseObjectGroup", objectGroup: @group, async: true)
        rescue Ferrum::Error
          nil
        end
      end
    end
  end
end
