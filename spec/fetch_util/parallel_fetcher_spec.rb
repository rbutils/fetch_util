# frozen_string_literal: true

RSpec.describe FetchUtil::ParallelFetcher do
  it "returns results in input order" do
    fake_fetcher = Class.new do
      def fetch(url)
        "done:#{url}"
      end

      def quit; end
    end

    results = described_class.new(fetcher_factory: -> { fake_fetcher.new }, concurrency: 2).fetch(%w[a b c])

    expect(results).to eq(%w[done:a done:b done:c])
  end

  it "re-raises worker errors wrapped in ParallelFetchError" do
    fake_fetcher = Class.new do
      def fetch(_url)
        raise FetchUtil::BrowserError, "boom"
      end

      def quit; end
    end

    expect do
      described_class.new(fetcher_factory: -> { fake_fetcher.new }).fetch(["https://example.com"])
    end.to raise_error(FetchUtil::ParallelFetcher::ParallelFetchError) { |error|
      expect(error.failures.length).to eq(1)
      expect(error.failures.first.url).to eq("https://example.com")
      expect(error.failures.first.error).to be_a(FetchUtil::BrowserError)
      expect(error.failures.first.error.message).to eq("boom")
      expect(error.results).to eq([nil])
    }
  end

  it "retains all worker failures when multiple urls fail" do
    fake_fetcher = Class.new do
      def fetch(url)
        raise FetchUtil::BrowserError, "boom for #{url}"
      end

      def quit; end
    end

    expect do
      described_class.new(fetcher_factory: -> { fake_fetcher.new }, concurrency: 2).fetch(%w[a b])
    end.to raise_error(FetchUtil::ParallelFetcher::ParallelFetchError) { |error|
      expect(error.failures.map(&:url)).to contain_exactly("a", "b")
      expect(error.errors.map(&:message)).to contain_exactly("boom for a", "boom for b")
      expect(error.message).to include("parallel fetch failed for 2 URLs")
      expect(error.results).to eq([nil, nil])
    }
  end

  it "surfaces fetcher factory initialization failures" do
    factory_calls = 0

    expect do
      described_class.new(fetcher_factory: lambda {
        factory_calls += 1
        raise FetchUtil::ExtractionError, "factory boom" if factory_calls == 1

        Class.new do
          def fetch(url)
            "done:#{url}"
          end

          def quit; end
        end.new
      }, concurrency: 2).fetch(%w[a b])
    end.to raise_error(FetchUtil::ParallelFetcher::ParallelFetchError) { |error|
      factory_failure = error.failures.find { |f| f.error.is_a?(FetchUtil::ExtractionError) }
      expect(factory_failure).not_to be_nil
      expect(factory_failure.error.message).to eq("factory boom")
    }
  end

  it "continues processing remaining urls after a per-url failure" do
    fake_fetcher = Class.new do
      def fetch(url)
        raise FetchUtil::BrowserError, "boom for #{url}" if url == "b"

        "done:#{url}"
      end

      def quit; end
    end

    # With concurrency 1, all jobs go through one thread sequentially
    expect do
      described_class.new(fetcher_factory: -> { fake_fetcher.new }, concurrency: 1).fetch(%w[a b c])
    end.to raise_error(FetchUtil::ParallelFetcher::ParallelFetchError) { |error|
      expect(error.failures.length).to eq(1)
      expect(error.failures.first.url).to eq("b")
      # Partial results are accessible: "a" and "c" succeeded, "b" is nil
      expect(error.results).to eq(["done:a", nil, "done:c"])
    }
  end

  it "returns successful results alongside failures when possible" do
    fetch_log = []
    fake_fetcher = Class.new do
      define_method(:initialize) do
        @log = fetch_log
      end

      define_method(:fetch) do |url|
        @log << url
        raise FetchUtil::BrowserError, "boom for #{url}" if url == "b"

        "done:#{url}"
      end

      def quit; end
    end

    # Use concurrency: 1 to ensure deterministic ordering through the queue
    error = nil
    begin
      described_class.new(fetcher_factory: -> { fake_fetcher.new }, concurrency: 1).fetch(%w[a b c])
    rescue FetchUtil::ParallelFetcher::ParallelFetchError => e
      error = e
    end

    # All three URLs should have been attempted (thread continues after error)
    expect(fetch_log).to eq(%w[a b c])
    # Partial results are available on the error
    expect(error).not_to be_nil
    expect(error.results).to eq(["done:a", nil, "done:c"])
    expect(error.failures.length).to eq(1)
    expect(error.failures.first.url).to eq("b")
  end

  it "calls quit on fetchers that support it" do
    quit_count = 0
    fake_fetcher = Class.new do
      define_method(:initialize) do
        @quit_tracker = -> { quit_count += 1 }
      end

      def fetch(url)
        "done:#{url}"
      end

      define_method(:quit) do
        @quit_tracker.call
      end
    end

    described_class.new(fetcher_factory: -> { fake_fetcher.new }, concurrency: 2).fetch(%w[a b c])

    expect(quit_count).to eq(2) # 2 workers, each calls quit
  end
end
