# frozen_string_literal: true

module FetchUtil
  class ParallelFetcher
    Failure = Struct.new(:index, :url, :error, keyword_init: true)

    class ParallelFetchError < Error
      attr_reader :failures, :results

      def initialize(failures, results = nil)
        @failures = failures.freeze
        @results = results&.freeze
        super(self.class.build_message(@failures))
      end

      def errors
        @failures.map(&:error)
      end

      def self.build_message(failures)
        preview = failures.first(3).map do |failure|
          label = failure.url || "<initialization>"
          "#{label} (#{failure.error.class}: #{failure.error.message})"
        end.join(", ")
        suffix = failures.length > 3 ? ", +#{failures.length - 3} more" : ""
        "parallel fetch failed for #{failures.length} URLs: #{preview}#{suffix}"
      end
    end

    DEFAULT_CONCURRENCY = 4

    def initialize(fetcher_factory: nil, concurrency: DEFAULT_CONCURRENCY, **fetch_options)
      @fetcher_factory = fetcher_factory || -> { Fetcher.new(**fetch_options) }
      @concurrency = [concurrency.to_i, 1].max
    end

    def fetch(urls)
      work = Array(urls).compact.map(&:to_s).reject(&:empty?)
      return [] if work.empty?

      jobs = Queue.new
      failures = Queue.new
      work.each_with_index { |url, index| jobs << [index, url] }
      results = Array.new(work.length)
      worker_count = [@concurrency, work.length].min

      threads = Array.new(worker_count) do
        Thread.new do
          fetcher = @fetcher_factory.call

          begin
            loop do
              begin
                index, url = jobs.pop(true)
              rescue ThreadError
                break
              end

              begin
                results[index] = fetcher.fetch(url)
              rescue StandardError => e
                failures << Failure.new(index: index, url: url, error: e)
              end
            end
          ensure
            fetcher.quit if fetcher.respond_to?(:quit)
          end
        rescue StandardError => e
          failures << Failure.new(index: nil, url: nil, error: e)
        end
      end

      threads.each(&:join)
      raise_for_failures(drain_queue(failures), results)

      results
    end

    private

    def drain_queue(queue)
      items = []
      loop do
        items << queue.pop(true)
      rescue ThreadError
        break
      end
      items
    end

    def raise_for_failures(failures, results)
      return if failures.empty?

      raise ParallelFetchError.new(failures, results)
    end
  end
end
