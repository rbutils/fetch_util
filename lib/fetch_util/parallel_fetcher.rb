# frozen_string_literal: true

require "uri"

module FetchUtil
  class ParallelFetcher
    Failure = Struct.new(:index, :url, :error, keyword_init: true)

    class ParallelFetchError < Error
      attr_reader :failures, :results

      def initialize(failures, results = nil)
        @failures = ordered_failures(failures).freeze
        @results = results&.freeze
        super(self.class.build_message(@failures))
      end

      def errors
        @failures.map(&:error)
      end

      def self.build_message(failures)
        preview = failures.first(3).map do |failure|
          label = if failure.index.nil?
                    "<initialization>"
                  elsif failure.url.empty?
                    "<blank>"
                  else
                    failure.url
                  end
          "#{label} (#{failure.error.class}: #{failure.error.message})"
        end.join(", ")
        suffix = failures.length > 3 ? ", +#{failures.length - 3} more" : ""
        "parallel fetch failed for #{failures.length} URLs: #{preview}#{suffix}"
      end

      private

      def ordered_failures(failures)
        initialization_failures, url_failures = failures.partition { |failure| failure.index.nil? }
        initialization_failures.sort_by! { |failure| [failure.error.class.name.to_s, failure.error.message] }
        url_failures.sort_by!(&:index)
        initialization_failures + url_failures
      end
    end

    DEFAULT_CONCURRENCY = 4
    FETCHER_COLLABORATOR_OPTIONS = %i[browser extractor raw_docs_fallback request_log pdf_header_probe].freeze
    private_constant :FETCHER_COLLABORATOR_OPTIONS

    def initialize(fetcher_factory: nil, concurrency: DEFAULT_CONCURRENCY, **fetch_options)
      unless concurrency.is_a?(Integer) && concurrency.positive?
        raise InputError, "concurrency must be a positive Integer"
      end

      @fetcher_factory = fetcher_factory || default_fetcher_factory(fetch_options)
      @concurrency = concurrency
    end

    def fetch(urls)
      work = Array(urls).map { |url| url.to_s.dup.freeze }
      return [] if work.empty?

      results = Array.new(work.length)
      failures = []
      pending_indices = []
      work.each_with_index do |url, index|
        if url.empty?
          error = URI::InvalidURIError.new("unsupported url: #{url}")
          failures << Failure.new(index: index, url: url, error: error)
        else
          pending_indices << index
        end
      end

      worker_count = [@concurrency, pending_indices.length].min
      next_index = 0
      mutex = Mutex.new
      stopping = false
      threads = []

      begin
        worker_count.times do
          threads << Thread.new do
            fetcher = @fetcher_factory.call

            begin
              loop do
                index = mutex.synchronize do
                  if !stopping && next_index < pending_indices.length
                    current = pending_indices[next_index]
                    next_index += 1
                    current
                  end
                end
                break if index.nil?

                url = work[index]

                begin
                  results[index] = fetcher.fetch(url)
                rescue StandardError => e
                  mutex.synchronize { failures << Failure.new(index: index, url: url, error: e) }
                end
              end
            ensure
              begin
                fetcher.quit if fetcher.respond_to?(:quit)
              rescue Ferrum::Error
                nil
              end
            end
          rescue StandardError => e
            mutex.synchronize { failures << Failure.new(index: nil, url: nil, error: e) }
          end
        end
      rescue ThreadError
        mutex.synchronize { stopping = true }
        threads.each(&:join)
        raise
      end

      threads.each(&:join)
      raise_for_failures(failures, results)

      results
    end

    private

    def default_fetcher_factory(fetch_options)
      owned_options = immutable_fetch_options(fetch_options)
      -> { Fetcher.new(**immutable_fetch_options(owned_options)) }
    end

    def immutable_fetch_options(fetch_options)
      memo = {}.compare_by_identity
      owned = {}
      memo[fetch_options] = owned

      fetch_options.each do |key, value|
        owned_key = immutable_fetch_option(key, memo)
        owned[owned_key] = if FETCHER_COLLABORATOR_OPTIONS.include?(key)
                             value
                           else
                             immutable_fetch_option(value, memo)
                           end
      end
      owned.freeze
    end

    def immutable_fetch_option(value, memo)
      return memo[value] if memo.key?(value)

      case value
      when String
        memo[value] = value.dup.freeze
      when Array
        owned = value.dup
        memo[value] = owned
        owned.map! { |item| immutable_fetch_option(item, memo) }
        owned.freeze
      when Hash
        owned = value.dup
        memo[value] = owned
        owned.clear
        owned.default = immutable_fetch_option(value.default, memo) unless value.default_proc
        value.each do |key, item|
          owned_key = value.compare_by_identity? ? key : immutable_fetch_option(key, memo)
          owned[owned_key] = immutable_fetch_option(item, memo)
        end
        owned.freeze unless owned.default_proc
        owned
      else
        value
      end
    end

    def raise_for_failures(failures, results)
      return if failures.empty?

      raise ParallelFetchError.new(failures, results)
    end
  end
end
