# frozen_string_literal: true

require "json"

module FetchUtil
  class Extractor
    INLINE_ASSET_PATHS = %w[vendor/readability.js vendor/turndown.js extract.js].freeze
    VENDOR_ASSET_PATHS = INLINE_ASSET_PATHS.first(2).freeze
    VENDOR_GLOBAL_NAMES = %w[Readability TurndownService].freeze
    PRIVATE_DELIVERY_SENTINEL = '"fetch-util:standalone-api:v1"'
    @asset_cache = {}
    @cache_mutex = Mutex.new

    class << self
      def inline_asset_scripts(asset_root)
        @cache_mutex.synchronize do
          @asset_cache[asset_root] ||= INLINE_ASSET_PATHS.map do |relative_path|
            File.read(File.join(asset_root, relative_path), encoding: "UTF-8").freeze
          end.freeze
        end
      end
    end

    def initialize(reader_mode: true, asset_root: nil)
      @reader_mode = reader_mode
      @asset_root = (asset_root || File.join(__dir__, "assets")).dup.freeze
      @extraction_call = nil
      @private_asset_script = nil
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
      INLINE_ASSET_PATHS.each do |relative_path|
        page.add_script_tag(path: asset_path(relative_path))
      end
    end

    def inject_vendor_assets(page)
      VENDOR_ASSET_PATHS.each do |relative_path|
        page.add_script_tag(path: asset_path(relative_path))
      end
    end

    def inject_vendor_assets_inline(page)
      inline_asset_scripts.first(2).zip(VENDOR_GLOBAL_NAMES).each do |script, global_name|
        page.evaluate(<<~JAVASCRIPT)
          (() => {
            #{script}
            window.#{global_name} = #{global_name};
            return true;
          })()
        JAVASCRIPT
      end
    end

    def extract_payload(page)
      timeout_supported = page.respond_to?(:timeout) && page.respond_to?(:timeout=)
      original_timeout = page.timeout if timeout_supported
      page.timeout = [original_timeout.to_f, 60].max if timeout_supported

      inject_vendor_assets(page)
      page.evaluate(extraction_call)
    rescue Ferrum::TimeoutError
      begin
        page.evaluate("window.stop && window.stop()")
      rescue Ferrum::Error
      end
      inject_vendor_assets_inline(page)
      page.evaluate(extraction_call)
    ensure
      restore_page_timeout(page, original_timeout) if timeout_supported
    end

    def restore_page_timeout(page, timeout)
      page.timeout = timeout
    rescue Ferrum::Error
      nil
    end

    def extraction_call
      @extraction_call ||= begin
        options = JSON.generate(reader_mode: @reader_mode)
        <<~JAVASCRIPT
          (() => {
            let __fetchUtilPrivateApi = null;
            const __fetchUtilDeliverExtractApi = api => { __fetchUtilPrivateApi = api; };
            #{private_asset_script}
            if (!__fetchUtilPrivateApi || typeof __fetchUtilPrivateApi.extract !== "function") return null;
            return __fetchUtilPrivateApi.extract(#{options});
          })()
        JAVASCRIPT
      end
    end

    def private_asset_script
      @private_asset_script ||= begin
        source = inline_asset_scripts.last
        marker_index = source.index(PRIVATE_DELIVERY_SENTINEL)
        duplicate_index = source.index(PRIVATE_DELIVERY_SENTINEL, marker_index.to_i + PRIVATE_DELIVERY_SENTINEL.length)
        raise ExtractionError, "Private extraction delivery sentinel is missing or duplicated" if marker_index.nil? || duplicate_index

        source.sub(PRIVATE_DELIVERY_SENTINEL, "__fetchUtilDeliverExtractApi").freeze
      end
    end

    def inline_asset_scripts
      self.class.inline_asset_scripts(@asset_root)
    end

    def asset_path(relative_path)
      File.join(@asset_root, relative_path)
    end
  end
end
