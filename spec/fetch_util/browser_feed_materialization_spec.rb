# frozen_string_literal: true

require "spec_helper"

RSpec.describe "finite initial publication acquisition" do
  def feed_document(missing: nil, append: false)
    slots = (1..20).map { |number| "<section class='publication-slot' id='entry-#{number}'></section>" }.join
    <<~HTML
      <!doctype html><html><head><meta charset="utf-8"><title>Community publication collection</title>
      <style>.publication-slot { min-height: 220px; padding: 4px; } article { height: 200px; }</style></head>
      <body><main><h1>Community publication collection</h1><div id="collection">#{slots}</div></main>
      <script>
      window.ticks = 0; setInterval(() => window.ticks++, 20);
      function populate(slot) {
        const number = Number(slot.id.split('-')[1]);
        if (number === #{missing || "null"} || !Number.isInteger(number)) return;
        slot.innerHTML = '<aside data-score="' + number + '">' + number + '</aside><article>' +
          '<header><span rel="author">élise 名' + number + '</span><time datetime="2026-01-02T12:00:00Z">today</time></header>' +
          '<h2><a href="/entry/' + number + '">Published record ' + number + '</a></h2>' +
          '<p>Authored reporting for record ' + number + ' preserves this complete original paragraph.</p></article>';
        if (#{append} && number === 20 && !document.getElementById('appended-slot')) {
          const next = document.createElement('section'); next.id = 'appended-slot';
          next.className = 'publication-slot'; document.getElementById('collection').appendChild(next);
        }
      }
      Array.from(document.querySelectorAll('.publication-slot')).slice(0, 3).forEach(populate);
      const observer = new IntersectionObserver(entries => entries.forEach(entry => {
        if (entry.isIntersecting) populate(entry.target);
        else if (Number(entry.target.id.split('-')[1]) > 3) entry.target.replaceChildren();
      }));
      document.querySelectorAll('.publication-slot').forEach(slot => observer.observe(slot));
      </script></body></html>
    HTML
  end

  def with_feed(missing: nil, append: false, **options)
    server = LocalAcquisitionServer.new(routes: { "/feed" => feed_document(missing: missing, append: append) })
    browser = FetchUtil::Browser.new(timeout: 10, wait: 0.2, wait_for_idle: false, **options)
    yield browser, server
  ensure
    browser&.quit
    server&.close
  end

  it "retains all initial records despite destructive offscreen virtualization" do
    with_feed(append: true) do |browser, server|
      browser.with_page(server.url("/feed")) do |page|
        original = page.evaluate("({width: innerWidth, height: innerHeight})")
        initial = page.evaluate_func(FetchUtil::Browser::FeedMaterialization::SLOT_PROBE, nil)
        expect(initial.fetch("ids")).to eq((1..20).map { |number| "entry-#{number}" })
        payload = browser.send(:with_materialized_feed, page) do
          expect(page.evaluate("({width: innerWidth, height: innerHeight})")).to eq(original)
          FetchUtil::Extractor.new.extract(page)
        end
        expect(payload.fetch("warnings")).not_to include("unmaterialized_feed_entries")
        offsets = (1..20).map { |number| payload.fetch("markdown").index("Published record #{number}]") }
        expect(offsets).to all(be_a(Integer))
        expect(offsets).to eq(offsets.sort)
        expect(payload.fetch("markdown")).to include("élise 名20")
        expect(page.evaluate("document.getElementById('appended-slot') !== null")).to be(true)
        expect(page.evaluate("({width: innerWidth, height: innerHeight})")).to eq(original)
        ticks = page.evaluate("window.ticks")
        sleep 0.1
        expect(page.evaluate("window.ticks")).to be > ticks
      end
    end
  end

  it "warns when an initial entry does not materialize before the deadline" do
    with_feed(missing: 15, feed_hydration_timeout: 0.4) do |browser, server|
      browser.with_page(server.url("/feed")) do |page|
        payload = browser.send(:with_materialized_feed, page) { FetchUtil::Extractor.new.extract(page) }
        expect(payload.fetch("warnings")).to include("unmaterialized_feed_entries")
        expect(payload.fetch("markdown")).to include("Published record 1]")
        expect(payload.fetch("markdown")).not_to include("Published record 15]")
        expect(page.evaluate("innerHeight")).to eq(900)
      end
    end
  end

  it "reports a height-bound partial collection without dropping available records" do
    with_feed(feed_hydration_max_height: 1_000, feed_hydration_timeout: 0.4) do |browser, server|
      browser.with_page(server.url("/feed")) do |page|
        payload = browser.send(:with_materialized_feed, page) { FetchUtil::Extractor.new.extract(page) }
        expect(payload.fetch("warnings")).to include("unmaterialized_feed_entries")
        expect(payload.fetch("markdown")).to include("Published record 1]", "Published record 3]")
        expect(page.evaluate("innerHeight")).to eq(900)
      end
    end
  end

  it "resumes lifecycle and restores viewport when extraction raises" do
    with_feed do |browser, server|
      browser.with_page(server.url("/feed")) do |page|
        error = FetchUtil::ExtractionError.new("original extraction failure")
        expect { browser.send(:with_materialized_feed, page) { raise error } }.to(raise_error { |raised| expect(raised).to equal(error) })
        expect(page.evaluate("innerHeight")).to eq(900)
        ticks = page.evaluate("window.ticks")
        sleep 0.1
        expect(page.evaluate("window.ticks")).to be > ticks
      end
    end
  end

  it "materializes through the owned Fetcher without changing injected-browser callbacks" do
    server = LocalAcquisitionServer.new(routes: { "/feed" => feed_document })
    fetcher = FetchUtil::Fetcher.new(timeout: 10, wait: 0.2, wait_for_idle: false)
    result = fetcher.fetch(server.url("/feed"))
    expect(result.markdown).to include("Published record 20]")
    expect(result.warnings).not_to include("unmaterialized_feed_entries")
  ensure
    fetcher&.quit
    server&.close
  end

  it "rejects invalid resource budgets" do
    expect { FetchUtil::Browser.new(feed_hydration_timeout: -1) }.to raise_error(FetchUtil::InputError, /nonnegative/)
    expect { FetchUtil::Browser.new(feed_hydration_max_height: 0) }.to raise_error(FetchUtil::InputError, /positive integer/)
    expect { FetchUtil::Browser.new(feed_hydration_max_height: 1.5) }.to raise_error(FetchUtil::InputError, /positive integer/)
  end

  it "preserves an extraction error while retiring an unrestorable browser" do
    browser = FetchUtil::Browser.new
    original = { "ids" => ["initial"], "remaining" => ["initial"], "targetHeight" => 1_500,
                 "width" => 1_366, "height" => 900, "scale" => 1 }
    page = double("materialized page")
    allow(page).to receive(:evaluate_func).and_return(original, original.merge("remaining" => []))
    viewport_calls = 0
    allow(page).to receive(:command) do |method, **|
      if method == "Emulation.setDeviceMetricsOverride"
        viewport_calls += 1
        raise Ferrum::TimeoutError if viewport_calls == 3
      end
      {}
    end
    allow(browser).to receive(:retire_browser)
    error = FetchUtil::ExtractionError.new("primary extraction failure")

    expect { browser.send(:with_materialized_feed, page) { raise error } }.to(raise_error { |raised| expect(raised).to equal(error) })
    expect(page).to have_received(:command).with("Page.setWebLifecycleState", state: "active")
    expect(browser).to have_received(:retire_browser)
  end

  it "attempts restoration when lifecycle freezing fails before extraction" do
    browser = FetchUtil::Browser.new
    original = { "ids" => ["initial"], "remaining" => ["initial"], "targetHeight" => 1_500,
                 "width" => 1_366, "height" => 900, "scale" => 1 }
    page = double("freezing page")
    allow(page).to receive(:evaluate_func).and_return(original, original.merge("remaining" => []))
    allow(page).to receive(:command).and_return({})
    allow(page).to receive(:command).with("Page.setWebLifecycleState", state: "frozen").and_raise(Ferrum::TimeoutError)

    expect { browser.send(:with_materialized_feed, page) { raise "extraction must not run" } }.to raise_error(Ferrum::TimeoutError)
    expect(page).to have_received(:command).with("Page.setWebLifecycleState", state: "active")
    expect(page).to have_received(:command).with(
      "Emulation.setDeviceMetricsOverride",
      width: 1_366,
      height: 900,
      deviceScaleFactor: 1,
      mobile: false
    )
  end
end
