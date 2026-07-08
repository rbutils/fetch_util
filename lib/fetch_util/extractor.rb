# frozen_string_literal: true

require "json"

module FetchUtil
  class Extractor
    INLINE_ASSET_PATHS = %w[vendor/readability.js vendor/turndown.js extract.js].freeze

    def initialize(reader_mode: true, asset_root: nil)
      @reader_mode = reader_mode
      @asset_root = asset_root || File.join(__dir__, "assets")
      @inline_asset_scripts = nil
      @extraction_call = nil
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
      inline_asset_scripts.each do |script|
        page.evaluate("#{script}\ntrue")
      end
    end

    def extract_payload(page)
      original_timeout = page.timeout
      page.timeout = [original_timeout.to_f, 60].max

      inject_assets(page)
      page.evaluate(extraction_call)
    rescue Ferrum::TimeoutError
      begin
        page.evaluate("window.stop && window.stop()")
      rescue Ferrum::Error
      end
      inject_assets_inline(page)
      page.evaluate(extraction_call)
    ensure
      page.timeout = original_timeout if original_timeout
    end

    def extraction_call
      @extraction_call ||= "window.FetchUtilExtract.extract(#{JSON.generate(reader_mode: @reader_mode)})"
    end

    def inline_asset_scripts
      @inline_asset_scripts ||= INLINE_ASSET_PATHS.map do |relative_path|
        File.read(asset_path(relative_path), encoding: "UTF-8")
      end
    end

    def asset_path(relative_path)
      File.join(@asset_root, relative_path)
    end
  end
end
