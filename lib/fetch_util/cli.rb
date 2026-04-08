# frozen_string_literal: true

require "json"
require "thor"

module FetchUtil
  class CLI < Thor
    DEFAULT_FETCH_FIELDS = %i[
      url
      final_url
      canonical_url
      title
      byline
      site_name
      published_time
      markdown
      content_type
      suspect
      warnings
    ].freeze

    class_option :log_path, type: :string, desc: "Append-only request log path"
    class_option :format, type: :string, default: "json", enum: %w[json jsonl], desc: "Output format"
    class_option :timeout, type: :numeric, default: 20
    class_option :wait, type: :numeric, default: 0.75
    class_option :concurrency, type: :numeric, default: 4
    class_option :reader_mode, type: :boolean, default: true
    class_option :wait_for_idle, type: :boolean, default: true
    class_option :include_html, type: :boolean, default: false, desc: "Include raw html in fetch output"

    desc "version", "Display fetch_util version"
    def version
      puts FetchUtil::VERSION
    end

    desc "fetch URL [URL...]", "Fetch one or more URLs"
    def fetch(*urls)
      raise ArgumentError, "at least one URL is required" if urls.empty?

      results = if urls.length == 1
                  [FetchUtil.fetch(urls.first, **fetch_options, request_log: request_log)]
                else
                  FetchUtil.fetch_many(urls, **fetch_options, request_log: request_log, concurrency: options[:concurrency])
                end

      emit(urls.length == 1 && options[:format] == "json" ? result_payload(results.first) : results.map { |result| result_payload(result) })
    end

    desc "search QUERY", "Search across configured engines and aggregate results"
    option :source, type: :array, default: FetchUtil::Searcher::DEFAULT_SOURCES, desc: "Search sources"
    option :limit, type: :numeric, default: 10
    option :verbose_search, type: :boolean, default: false, desc: "Include per-result search provenance"
    def search(*terms)
      query = terms.join(" ").strip
      raise ArgumentError, "query is required" if query.empty?

      payload = Searcher.new(
        request_log: request_log,
        sources: options[:source],
        limit: options[:limit],
        concurrency: [options[:concurrency], options[:source].length].min,
        verbose: options[:verbose_search],
        **fetch_options
      ).search(query)

      emit(payload)
    end

    desc "regulatory URL", "Inspect regulatory crawl, index, and TDM signals for one URL"
    option :sources, type: :string, default: "machine", desc: "Comma-separated source selectors, e.g. machine,-robotstxt or human,machine,-human"
    option :cache_path, type: :string, desc: "Structured regulatory cache directory"
    def regulatory(url)
      raise ArgumentError, "url is required" if url.to_s.strip.empty?

      request_log.append("regulatory://#{url}?sources=#{options[:sources]}")
      payload = FetchUtil.regulatory(
        url,
        cache_path: options[:cache_path],
        sources: options[:sources],
        timeout: options[:timeout]
      )

      emit(payload)
    end

    no_commands do
      def request_log
        @request_log ||= RequestLog.new(path: options[:log_path] || ENV.fetch("FETCH_UTIL_REQUEST_LOG", RequestLog::DEFAULT_PATH))
      end

      def fetch_options
        {
          timeout: options[:timeout],
          wait: options[:wait],
          wait_for_idle: options[:wait_for_idle],
          reader_mode: options[:reader_mode]
        }
      end

      def result_payload(result)
        payload = result.to_h
        payload = payload.select { |key, _value| DEFAULT_FETCH_FIELDS.include?(key) }
        payload[:html] = result.html if options[:include_html]

        payload.reject { |_key, value| value.nil? || value == "" }
      end

      def emit(payload)
        if options[:format] == "jsonl" && payload.is_a?(Array)
          payload.each { |item| puts JSON.generate(item) }
        else
          puts JSON.generate(payload)
        end
      end
    end
  end
end
