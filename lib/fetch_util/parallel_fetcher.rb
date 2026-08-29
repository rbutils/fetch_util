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

    def initialize(fetcher_factory: nil, concurrency: DEFAULT_CONCURRENCY, **fetch_options)
      unless concurrency.is_a?(Integer) && concurrency.positive?
        raise ArgumentError, "concurrency must be a positive Integer"
      end

      @fetcher_factory = fetcher_factory || -> { Fetcher.new(**fetch_options) }
      @concurrency = concurrency
    end

    def fetch(urls)
      work = Array(urls).map(&:to_s)
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

      threads = Array.new(worker_count) do
        Thread.new do
          fetcher = @fetcher_factory.call

          begin
            loop do
              index = mutex.synchronize do
                if next_index < pending_indices.length
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

      threads.each(&:join)
      raise_for_failures(failures, results)

      results
    end

    private

    def raise_for_failures(failures, results)
      return if failures.empty?

      raise ParallelFetchError.new(failures, results)
    end
  end
end
