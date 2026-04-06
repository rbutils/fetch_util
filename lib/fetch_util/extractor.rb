# frozen_string_literal: true

require "json"

module FetchUtil
  class Extractor
    def initialize(reader_mode: true, asset_root: nil)
      @reader_mode = reader_mode
      @asset_root = asset_root || File.join(__dir__, "assets")
    end

    def extract(page)
      payload = extract_payload(page)
      raise ExtractionError, "Page extraction returned no content" unless payload.is_a?(Hash)

      payload
    rescue Ferrum::JavaScriptError, Ferrum::StatusError, Ferrum::TimeoutError => e
      raise ExtractionError, e.message
    end

    private

    def inject_assets(page)
      page.add_script_tag(path: asset_path("vendor/readability.js"))
      page.add_script_tag(path: asset_path("vendor/turndown.js"))
      page.add_script_tag(path: asset_path("extract.js"))
    end

    def inject_assets_inline(page)
      %w[vendor/readability.js vendor/turndown.js extract.js].each do |relative_path|
        script = File.read(asset_path(relative_path), encoding: "UTF-8")
        page.evaluate("#{script}\ntrue")
      end
    end

    def extract_payload(page)
      inject_assets(page)
      page.evaluate(extraction_call)
    rescue Ferrum::TimeoutError
      begin
        page.evaluate("window.stop && window.stop()")
      rescue Ferrum::Error
      end
      inject_assets_inline(page)
      page.evaluate(extraction_call)
    end

    def extraction_call
      "window.FetchUtilExtract.extract(#{JSON.generate(reader_mode: @reader_mode)})"
    end

    def asset_path(relative_path)
      File.join(@asset_root, relative_path)
    end
  end
end
