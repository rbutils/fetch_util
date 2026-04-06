# frozen_string_literal: true

RSpec.describe FetchUtil::ParallelFetcher do
  it "returns results in input order" do
    fake_fetcher = Class.new do
      def fetch(url)
        "done:#{url}"
      end
    end

    results = described_class.new(fetcher_factory: -> { fake_fetcher.new }, concurrency: 2).fetch(%w[a b c])

    expect(results).to eq(%w[done:a done:b done:c])
  end

  it "re-raises worker errors" do
    fake_fetcher = Class.new do
      def fetch(_url)
        raise FetchUtil::BrowserError, "boom"
      end
    end

    expect do
      described_class.new(fetcher_factory: -> { fake_fetcher.new }).fetch(["https://example.com"])
    end.to raise_error(FetchUtil::BrowserError, "boom")
  end

  it "retains all worker failures when multiple urls fail" do
    fake_fetcher = Class.new do
      def fetch(url)
        raise FetchUtil::BrowserError, "boom for #{url}"
      end
    end

    expect do
      described_class.new(fetcher_factory: -> { fake_fetcher.new }, concurrency: 2).fetch(%w[a b])
    end.to raise_error(FetchUtil::ParallelFetcher::ParallelFetchError) { |error|
      expect(error.failures.map(&:url)).to contain_exactly("a", "b")
      expect(error.errors.map(&:message)).to contain_exactly("boom for a", "boom for b")
      expect(error.message).to include("parallel fetch failed for 2 URLs")
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
        end.new
      }, concurrency: 2).fetch(%w[a b])
    end.to raise_error(FetchUtil::ExtractionError, "factory boom")
  end
end
