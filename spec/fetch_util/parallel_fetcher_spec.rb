# frozen_string_literal: true

RSpec.describe FetchUtil::ParallelFetcher do
  it "requires a positive integer concurrency" do
    [0, -1, 2.5, "2", nil].each do |concurrency|
      expect { described_class.new(concurrency: concurrency) }
        .to raise_error(ArgumentError, "concurrency must be a positive Integer")
    end

    expect { described_class.new(concurrency: 1) }.not_to raise_error
  end

  it "rejects one browser shared across multiple default workers" do
    parallel_fetcher = described_class.new(browser: instance_double(FetchUtil::Browser), concurrency: 2)

    expect { parallel_fetcher.fetch(%w[first second]) }
      .to raise_error(
        FetchUtil::InputError,
        "browser cannot be shared across parallel workers; use fetcher_factory"
      )
  end

  it "allows one default worker to own an injected browser" do
    fetcher = instance_double(FetchUtil::Fetcher, fetch: "done", quit: nil)
    allow(FetchUtil::Fetcher).to receive(:new).and_return(fetcher)

    result = described_class.new(browser: instance_double(FetchUtil::Browser), concurrency: 2).fetch(["one"])

    expect(result).to eq(["done"])
  end

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

  it "owns queued urls before workers consume them" do
    first_started = Queue.new
    release_first = Queue.new
    fetched_urls = []
    second_url = +"https://second.example.test"
    fake_fetcher = Class.new do
      define_method(:fetch) do |url|
        if url == "https://first.example.test"
          first_started << true
          release_first.pop
        end
        fetched_urls << url
        "done:#{url}"
      end

      def quit; end
    end
    fetch_thread = Thread.new do
      described_class.new(fetcher_factory: -> { fake_fetcher.new }, concurrency: 1)
                     .fetch(["https://first.example.test", second_url])
    end

    first_started.pop
    second_url.replace("https://mutated.example.test")
    release_first << true

    expect(fetch_thread.value).to eq(
      ["done:https://first.example.test", "done:https://second.example.test"]
    )
    expect(fetched_urls).to eq(["https://first.example.test", "https://second.example.test"])
    expect(second_url).to eq("https://mutated.example.test")
  ensure
    release_first << true if release_first
    fetch_thread&.join
  end

  it "joins started workers when a later worker cannot start" do
    original_thread_new = Thread.method(:new)
    first_started = Queue.new
    second_attempted = Queue.new
    release_first = Queue.new
    fetched_urls = []
    fake_fetcher = Class.new do
      define_method(:fetch) do |url|
        fetched_urls << url
        first_started << true
        release_first.pop
        "done:#{url}"
      end

      def quit; end
    end
    spawn_count = 0
    allow(Thread).to receive(:new) do |&block|
      spawn_count += 1
      if spawn_count == 2
        first_started.pop
        second_attempted << true
        raise ThreadError, "worker unavailable"
      end

      original_thread_new.call(&block)
    end
    fetch_thread = original_thread_new.call do
      Thread.current.abort_on_exception = false
      Thread.current.report_on_exception = false
      described_class.new(fetcher_factory: -> { fake_fetcher.new }, concurrency: 2).fetch(%w[first second])
    end

    second_attempted.pop
    expect(fetch_thread).to be_alive
    release_first << true

    expect { fetch_thread.value }.to raise_error(ThreadError, "worker unavailable")
    expect(fetched_urls).to eq(["first"])
  ensure
    release_first << true if release_first
    begin
      fetch_thread&.join
    rescue ThreadError
      nil
    end
  end

  it "owns mutable fetch options before default workers start" do
    option_key = +"browser_path"
    browser_path = +"/original/chromium"
    extension = +"/original/extension"
    browser_options = { option_key => browser_path, extensions: [extension] }
    user_agent = +"Original Agent"
    shared_viewport_value = ["original"]
    default_viewport_value = ["default"]
    viewport = Class.new(Hash).new(default_viewport_value)
    viewport.update(
      width: 1280,
      height: 720,
      first: shared_viewport_value,
      second: shared_viewport_value,
      default_alias: default_viewport_value
    )
    viewport[:self] = viewport
    auto_config = Hash.new { |hash, key| hash[key] = [] }
    auto_config[:existing] = ["original"]
    identity_key = +"identity"
    identity_config = {}.compare_by_identity
    identity_config[identity_key] = +"original"
    viewport[:auto_config] = auto_config
    viewport[:identity_config] = identity_config
    raw_docs_fallback = Class.new(Hash).new
    pdf_header_probe = ->(_url) { nil }
    fetcher = instance_double(FetchUtil::Fetcher, fetch: "done", quit: nil)
    parallel_fetcher = described_class.new(
      concurrency: 1,
      browser_options: browser_options,
      user_agent: user_agent,
      viewport: viewport,
      raw_docs_fallback: raw_docs_fallback,
      pdf_header_probe: pdf_header_probe
    )

    option_key.replace("changed")
    browser_path.replace("/changed/chromium")
    extension.replace("/changed/extension")
    browser_options.clear
    user_agent.replace("Changed Agent")
    viewport[:width] = 640
    shared_viewport_value[0] = "changed"
    default_viewport_value[0] = "changed default"
    auto_config[:existing][0] = "changed"
    identity_config[identity_key].replace("changed")

    expect(FetchUtil::Fetcher).to receive(:new) do |**options|
      expect(options[:browser_options]).to eq(
        "browser_path" => "/original/chromium",
        extensions: ["/original/extension"]
      )
      expect(options[:user_agent]).to eq("Original Agent")
      expect(options[:viewport]).to be_instance_of(viewport.class)
      expect(options[:viewport][:width]).to eq(1280)
      expect(options[:viewport].default).to eq(["default"])
      expect(options[:viewport].default).to equal(options[:viewport][:default_alias])
      expect(options[:viewport][:self]).to equal(options[:viewport])
      expect(options[:viewport][:first]).to equal(options[:viewport][:second])
      expect(options[:viewport][:first]).to eq(["original"])
      expect(options[:viewport][:auto_config][:existing]).to eq(["original"])
      expect(options[:viewport][:auto_config][:created]).to eq([])
      expect(auto_config).not_to have_key(:created)
      expect(options[:viewport][:identity_config]).to be_compare_by_identity
      expect(options[:viewport][:identity_config]).to have_key(identity_key)
      expect(options[:viewport][:identity_config][identity_key]).to eq("original")
      expect(options[:raw_docs_fallback]).to equal(raw_docs_fallback)
      expect(options[:pdf_header_probe]).to equal(pdf_header_probe)
      fetcher
    end
    expect(parallel_fetcher.fetch(["https://example.test"])).to eq(["done"])
    expect(browser_options).to be_empty
    expect(user_agent).to eq("Changed Agent")
    expect(viewport[:width]).to eq(640)
    expect(shared_viewport_value).to eq(["changed"])
  end

  it "isolates mutable default-proc options between default workers" do
    auto_config = Hash.new { |hash, key| hash[key] = [] }
    captured_configs = Queue.new
    fetcher = instance_double(FetchUtil::Fetcher, fetch: "done", quit: nil)
    parallel_fetcher = described_class.new(
      concurrency: 2,
      viewport: { auto_config: auto_config }
    )

    allow(FetchUtil::Fetcher).to receive(:new) do |**options|
      config = options[:viewport][:auto_config]
      config[:created] << "worker"
      captured_configs << config
      fetcher
    end

    expect(parallel_fetcher.fetch(%w[first second])).to eq(%w[done done])
    configs = 2.times.map { captured_configs.pop }
    expect(configs.map(&:object_id).uniq.length).to eq(2)
    expect(configs.map { |config| config[:created] }).to eq([%w[worker], %w[worker]])
    expect(auto_config).not_to have_key(:created)
  end

  it "preserves blank input positions as failures" do
    fetched_urls = []
    fake_fetcher = Class.new do
      define_method(:initialize) do
        @fetched_urls = fetched_urls
      end

      def fetch(url)
        @fetched_urls << url
        "done:#{url}"
      end

      def quit; end
    end

    expect do
      described_class.new(fetcher_factory: -> { fake_fetcher.new }, concurrency: 1).fetch(["a", nil, "", "b"])
    end.to raise_error(FetchUtil::ParallelFetcher::ParallelFetchError) { |error|
      expect(error.failures.map { |failure| [failure.index, failure.url] }).to eq([[1, ""], [2, ""]])
      expect(error.errors).to all(be_a(URI::InvalidURIError))
      expect(error.errors.map(&:message)).to eq(["unsupported url: ", "unsupported url: "])
      expect(error.results).to eq(["done:a", nil, nil, "done:b"])
      expect(error.message).to include("<blank> (URI::InvalidURIError: unsupported url: )")
    }
    expect(fetched_urls).to eq(%w[a b])
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

  it "orders initialization and URL failures deterministically" do
    failures = [
      described_class::Failure.new(index: 2, url: "c", error: FetchUtil::BrowserError.new("boom for c")),
      described_class::Failure.new(index: nil, url: nil, error: FetchUtil::ExtractionError.new("factory z")),
      described_class::Failure.new(index: 0, url: "a", error: FetchUtil::BrowserError.new("boom for a")),
      described_class::Failure.new(index: nil, url: nil, error: FetchUtil::ExtractionError.new("factory a"))
    ]

    error = described_class::ParallelFetchError.new(failures)

    expect(error.failures.map { |failure| [failure.index, failure.url, failure.error.message] }).to eq(
      [
        [nil, nil, "factory a"],
        [nil, nil, "factory z"],
        [0, "a", "boom for a"],
        [2, "c", "boom for c"]
      ]
    )
    expect(error.errors.map(&:message)).to eq(["factory a", "factory z", "boom for a", "boom for c"])
    expect(error.message).to end_with(
      "<initialization> (FetchUtil::ExtractionError: factory a), " \
      "<initialization> (FetchUtil::ExtractionError: factory z), " \
      "a (FetchUtil::BrowserError: boom for a), +1 more"
    )
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
    quit_mutex = Mutex.new
    fake_fetcher = Class.new do
      define_method(:initialize) do
        @quit_tracker = -> { quit_mutex.synchronize { quit_count += 1 } }
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

  it "preserves successful results when worker cleanup fails" do
    fake_fetcher = Class.new do
      def fetch(url)
        "done:#{url}"
      end

      def quit
        raise Ferrum::Error, "shutdown failed"
      end
    end

    results = described_class.new(fetcher_factory: -> { fake_fetcher.new }, concurrency: 2).fetch(%w[a b c])

    expect(results).to eq(%w[done:a done:b done:c])
  end
end
