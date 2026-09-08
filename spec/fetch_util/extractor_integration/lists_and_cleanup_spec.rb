# frozen_string_literal: true

RSpec.describe 'FetchUtil extractor integration' do
  include_context 'extractor integration helpers'

  it "collapses list pages into agent-friendly bullets" do
    html = <<~HTML
      <html>
        <head><title>Example News</title></head>
        <body>
          <main>
            <table class="itemlist">
              <tr class="athing"><td><a href="https://example.com/a">First story about Ruby agents</a></td></tr>
              <tr><td>120 points | 45 comments</td></tr>
              <tr class="athing"><td><a href="https://example.com/b">Second story about fetch pipelines</a></td></tr>
              <tr><td>98 points | 18 comments</td></tr>
              <tr class="athing"><td><a href="https://example.com/c">Third story about browser automation</a></td></tr>
              <tr><td>75 points | 9 comments</td></tr>
              <tr class="athing"><td><a href="https://example.com/d">Fourth story about markdown cleanup</a></td></tr>
              <tr><td>40 points | 5 comments</td></tr>
              <tr class="athing"><td><a href="https://example.com/e">Fifth story about structured extraction</a></td></tr>
              <tr><td>21 points | 2 comments</td></tr>
              <tr class="athing"><td><a href="https://example.com/f">Sixth story about heuristics</a></td></tr>
              <tr><td>19 points | 1 comment</td></tr>
              <tr class="athing"><td><a href="https://example.com/g">Seventh story about ranking content</a></td></tr>
              <tr><td>11 points | discuss</td></tr>
              <tr class="athing"><td><a href="https://example.com/h">Eighth story about content types</a></td></tr>
              <tr><td>8 points | discuss</td></tr>
              <tr class="athing"><td><a href="javascript:openStory()">Script action story</a></td></tr>
              <tr class="athing"><td><a href="javascript:firstRepeatedAction()">Repeated action story</a><span>First action context</span></td></tr>
              <tr class="athing"><td><a href="javascript:secondRepeatedAction()">Repeated action story</a><span>Second action context</span></td></tr>
              <tr class="athing"><td><a href="mailto:news@example.test">Email action story</a></td></tr>
              <tr class="athing"><td><a href="ftp://files.example.test/story">FTP download action story</a></td></tr>
              <tr class="athing"><td><a href="https://reader:secret@example.com/private-story">Credential action story</a></td></tr>
            </table>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://www.ft.com/", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["contentType"]).to eq("list")
      expect(payload["readerMode"]).to eq(false)
      expect(payload["markdown"]).to include("- [First story about Ruby agents](https://example.com/a)")
      expect(payload["markdown"]).to include("- Script action story", "- Email action story", "- FTP download action story", "- Credential action story")
      expect(payload["markdown"].scan(/Repeated action story/).length).to eq(2)
      expect(payload["markdown"]).to include("First action context", "Second action context")
      expect(payload["markdown"]).not_to include("javascript:", "mailto:", "ftp:", "reader:secret@")
      expect(payload["html"]).to include("Script action story", "Email action story", "FTP download action story")
      expect(payload["html"]).not_to include("javascript:", "mailto:", "ftp:", "reader:secret@")
      expect(payload["markdown"]).not_to include("<table")
    end
  end

  it "does not let a sibling homepage card date suppress the page list" do
    cards = 8.times.map do |index|
      <<~HTML
        <div class="story-card">
          <h2><a href="/stories/#{index + 1}">University research story #{index + 1}</a></h2>
          <p>Research summary #{index + 1} with enough substantive context for a visible homepage record.</p>
          #{index.zero? ? "<span class=\"publish-date\">Aug 31, 2026</span>" : ""}
        </div>
      HTML
    end.join
    html = <<~HTML
      <html><head><title>Example University</title></head><body>
        <div role="main">
          <h1>Research that changes the world</h1>
          <p>Explore current discoveries, education, and public service across the university.</p>
          <div class="story-grid">#{cards}</div>
        </div>
      </body></html>
    HTML

    with_url_page("https://university.example/", html) do |page|
      payload = FetchUtil::Extractor.new(reader_mode: false).extract(page)

      expect(payload["contentType"]).to eq("list")
      expect(payload["markdown"].scan(/^- \[/).length).to eq(8)
      expect(payload["publishedTime"]).to be_nil
    end
  end

  it "retains a focal article publication date on a homepage route" do
    html = <<~HTML
      <html><head><title>Research announcement</title></head><body>
        <article role="main">
          <h1>Research announcement</h1>
          <time datetime="2026-08-30T12:00:00Z">August 30, 2026</time>
          <div itemprop="articleBody">
            <p>This focal report explains a significant research result with enough substantive detail to remain an article.</p>
            <p>It documents the evidence, methods, and implications for readers across the university community.</p>
          </div>
        </article>
      </body></html>
    HTML

    with_url_page("https://university.example/", html) do |page|
      payload = FetchUtil::Extractor.new(reader_mode: false).extract(page)

      expect(payload["contentType"]).to eq("article")
      expect(payload["publishedTime"]).to eq("2026-08-30T12:00:00Z")
    end
  end

  it "keeps headings owned by nested list regions" do
    headings = ["Popular books", "Latest books", "Editors' choices", "Free books"]
    overview_cards = 4.times.map do |index|
      <<~HTML
        <article>
          <h3><a href="/books/#{index + 1}">Complete catalog record #{index + 1}</a></h3>
          <p>Catalog summary #{index + 1} with enough local context for this record.</p>
        </article>
      HTML
    end.join
    sections = headings.map.with_index do |heading, section_index|
      cards = 4.times.map do |card_index|
        number = (section_index * 4) + card_index + 5
        <<~HTML
          <article>
            <h3><a href="/books/#{number}">Complete catalog record #{number}</a></h3>
            <p>Catalog summary #{number} with enough local context for this record.</p>
          </article>
        HTML
      end.join
      "<section><h2>#{heading}</h2>#{cards}</section>"
    end
    mixed_nested = 4.times.map do |index|
      number = index + 21
      <<~HTML
        <article>
          <h3><a href="/books/#{number}">Complete catalog record #{number}</a></h3>
          <p>Catalog summary #{number} with enough local context for this record.</p>
        </article>
      HTML
    end.join
    mixed_direct = 4.times.map do |index|
      number = index + 25
      <<~HTML
        <article>
          <h3><a href="/books/#{number}">Complete catalog record #{number}</a></h3>
          <p>Catalog summary #{number} with enough local context for this record.</p>
        </article>
      HTML
    end.join
    unheaded_nested = 4.times.map do |index|
      number = index + 33
      <<~HTML
        <article>
          <a href="/books/#{number}">Complete catalog record #{number}</a>
          <p>Catalog summary #{number} with enough local context for this record.</p>
        </article>
      HTML
    end.join
    html = <<~HTML
      <html><head><title>Complete book catalog</title></head><body>
        <main>
          <h1>Complete book catalog</h1>
          <div class="catalog-content">
            <section class="heading-only"><h2>Archive overview</h2></section>
            #{overview_cards}
          </div>
          <div class="catalog-content">#{sections.first(2).join}</div>
          <div class="catalog-content">#{sections.last(2).join}</div>
          <div class="catalog-content">
            <section><h2>New releases</h2>#{mixed_nested}</section>
            #{mixed_direct}
          </div>
          <div class="catalog-content">
            <section>
              <h2>Community picks</h2>
              <article><h3><a href="/books/29">Complete catalog record 29</a></h3></article>
              <article><h3><a href="/books/30">Complete catalog record 30</a></h3></article>
              <article><h3><a href="/books/31">Complete catalog record 31</a></h3></article>
              <article><h3><a href="/books/32">Complete catalog record 32</a></h3></article>
            </section>
            <section class="unheaded">#{unheaded_nested}</section>
          </div>
        </main>
      </body></html>
    HTML

    with_url_page("https://catalog.example/", html) do |page|
      payload = FetchUtil::Extractor.new(reader_mode: false).extract(page)

      expect(payload["contentType"]).to eq("list")
      expect(payload["markdown"].scan(/^## (.+)$/).flatten).to eq(
        ["Archive overview"] + headings + ["New releases", "Community picks"]
      )
      expect(payload["markdown"].scan(%r{\]\(https://catalog\.example/books/(\d+)\)}).flatten.map(&:to_i)).to eq((1..36).to_a)
    end
  end

  it "keeps all material direct list regions, including unheaded and related records" do
    cards = lambda do |range|
      range.map do |number|
        <<~HTML
          <article>
            <a href="/festival/#{number}">Festival archive record #{number}</a>
            <p>Program details for archive record #{number}.</p>
          </article>
        HTML
      end.join
    end
    html = <<~HTML
      <html><head><title>Festival archive</title></head><body>
        <main>
          <h1>Festival archive</h1>
          <div class="push-slider">#{cards.call(1..4)}</div>
          <section class="program-section">#{cards.call(5..8)}</section>
          <section>#{cards.call(9..10)}</section>
          <section><h2>Official selection</h2>#{cards.call(9..12)}</section>
          <div class="content-wrapper"><p>Background information about the complete festival program.</p></div>
          <div class="content-section related-list">#{cards.call(13..16)}</div>
        </main>
      </body></html>
    HTML

    with_url_page("https://festival.example/", html) do |page|
      payload = FetchUtil::Extractor.new(reader_mode: false).extract(page)

      expect(payload["contentType"]).to eq("list")
      expect(payload["markdown"].scan(/^## (.+)$/).flatten).to eq(["Official selection"])
      expect(payload["markdown"].scan(%r{\]\(https://festival\.example/festival/(\d+)\)}).flatten.map(&:to_i)).to eq((1..16).to_a)
      expect(payload["markdown"]).not_to include("## Festival archive record")
      expect(payload["markdown"]).to include("Program details for archive record 13.", "Program details for archive record 16.")
    end
  end

  it "does not let action links turn substantive prose into a list" do
    html = <<~HTML
      <html><head><title>Automation safety report</title></head><body><main><article>
        <h1>Automation safety report</h1>
        <p>This substantive report explains why user-visible actions require careful handling while preserving the surrounding article and its complete explanatory context.</p>
        <p>It documents classification evidence, output boundaries, and the behavior expected when browser-only controls appear beside ordinary prose.</p>
        <a href="javascript:firstAction()">Open interactive comparison</a>
        <a href="mailto:review@example.test">Email the review team</a>
        <a href="ftp://files.example.test/archive">Download the legacy archive</a>
        <a href="data:text/plain,report">Open embedded report data</a>
      </article></main></body></html>
    HTML

    with_url_page("https://example.test/reports/automation-safety", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["contentType"]).to eq("article")
      expect(payload["markdown"]).to include("Open interactive comparison", "Email the review team", "Download the legacy archive", "Open embedded report data")
      expect(payload["markdown"]).not_to include("javascript:", "mailto:", "ftp:", "data:text")
    end
  end

  it "keeps polling dashboard rows visible, local, and complete" do
    visible_rows = 8.times.map do |index|
      research_name = { 6 => "CBOS", 7 => "OGB" }.fetch(index, "Current Research #{index + 1}")
      <<~ROW
        <tr>
          <td>
            <a href="/poll/current-#{index}">#{research_name}</a>
            <span>Sample: #{1_000 + index}</span>
            <span>Fieldwork: #{index + 1}-#{index + 2} July</span>
          </td>
          <td class="poll-result">#{30 + index}.1</td>
          <td class="poll-result">#{12 + index}.4</td>
        </tr>
      ROW
    end.join
    historical_rows = 4.times.map do |index|
      <<~ROW
        <tr>
          <td><a href="/poll/historical-#{index}">Historical Research #{index + 1}</a></td>
          <td class="poll-result">20.0</td>
          <td class="poll-result">10.0</td>
        </tr>
      ROW
    end.join
    html = <<~HTML
      <html>
        <head>
          <title>National polling dashboard</title>
          <style>.year-panel { display: none; } .year-panel.current { display: block; }</style>
        </head>
        <body>
          <nav>
            <a href="/methodology">Polling methodology and fieldwork guide</a>
            <a href="/seat-model">Parliamentary seat projection model</a>
          </nav>
          <main>
            <h1>National polling dashboard</h1>
            <p>Current survey results with sample sizes, fieldwork dates, party support, averages, and projections.</p>
            <div class="polls-date">July 2026</div>
            <section class="year-panel current" id="current-year">
              <table>
                <thead><tr><th>Pollster</th><th>Civic</th><th>Green</th></tr></thead>
                <tbody>#{visible_rows}</tbody>
              </table>
            </section>
            <section class="year-panel" id="historical-year">
              <table>
                <thead><tr><th>Pollster</th><th>Civic</th><th>Green</th></tr></thead>
                <tbody>#{historical_rows}</tbody>
              </table>
            </section>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://example.test/polls/archive", html) do |page|
      payload = FetchUtil::Extractor.new(reader_mode: false).extract(page)
      markdown = payload["markdown"]

      expect(payload["contentType"]).to eq("list")
      expect(payload["publishedTime"]).to be_nil
      expect(markdown.scan(/^- \[/).length).to eq(8)
      expect(markdown).to include(
        "Current Research 1",
        "Sample: 1000",
        "Fieldwork: 1-2 July",
        "Civic: 30.1",
        "Green: 12.4",
        "CBOS",
        "OGB"
      )
      expect(markdown).not_to include(
        "Historical Research",
        "Polling methodology and fieldwork guide",
        "Parliamentary seat projection model"
      )
      expect(markdown.index("Current Research 1")).to be < markdown.index("OGB")
    end
  end

  it "keeps list records that restore inherited visibility" do
    visible_records = 8.times.map do |index|
      <<~HTML
        <article style="visibility: visible">
          <h2><a href="/records/#{index + 1}">Visible archive record #{index + 1}</a></h2>
          <p>Record #{index + 1} retains its rendered summary and local context.</p>
        </article>
      HTML
    end.join
    html = <<~HTML
      <html>
        <head><title>Record archive</title></head>
        <body>
          <main class="items">
            <h1>Record archive</h1>
            <section style="visibility: hidden" aria-label="Hidden archive label" title="Hidden archive title">
              <p>Inherited hidden introduction</p>
              #{visible_records}
              <article>
                <h2><a href="/records/inherited-hidden">Inherited hidden record</a></h2>
              </article>
            </section>
            <section style="display: none">
              <article style="visibility: visible">
                <h2><a href="/records/display-hidden">Display hidden record</a></h2>
              </article>
            </section>
            <section hidden>
              <article style="visibility: visible">
                <h2><a href="/records/attribute-hidden">Attribute hidden record</a></h2>
              </article>
            </section>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://example.test/records/archive", html) do |page|
      payload = FetchUtil::Extractor.new(reader_mode: false).extract(page)
      markdown = payload["markdown"]

      expect(payload["contentType"]).to eq("list")
      expect(markdown.scan(/^- \[/).length).to eq(8)
      expect(markdown).to include("Visible archive record 1", "Visible archive record 8")
      expect(markdown.index("Visible archive record 1")).to be < markdown.index("Visible archive record 8")
      expect(markdown).not_to include(
        "Inherited hidden introduction",
        "Inherited hidden record",
        "Display hidden record",
        "Attribute hidden record"
      )
      expect(payload["html"]).not_to include("Hidden archive label", "Hidden archive title")
    end
  end

  it "preserves distinct table observations that share a record URL" do
    rows = 8.times.map do |index|
      <<~ROW
        <tr>
          <td><a href="/pollster/shared">Shared Research Group</a></td>
          <td>#{index + 1}-#{index + 2} August</td>
          <td class="poll-result">#{24 + index}.0</td>
        </tr>
      ROW
    end.join
    html = <<~HTML
      <html><head><title>Polling archive</title></head><body><main>
        <h1>Polling archive</h1>
        <table>
          <thead><tr><th>Pollster</th><th>Fieldwork</th><th>Result</th></tr></thead>
          <tbody>#{rows}</tbody>
        </table>
      </main></body></html>
    HTML

    with_url_page("https://example.test/polls", html) do |page|
      payload = FetchUtil::Extractor.new(reader_mode: false).extract(page)
      markdown = payload["markdown"]

      expect(payload["contentType"]).to eq("list")
      expect(markdown.scan(/^- \[/).length).to eq(8)
      expect(markdown.scan("Shared Research Group").length).to eq(8)
      expect(markdown).to include("Fieldwork: 1-2 August", "Fieldwork: 8-9 August")
    end
  end

  it "keeps every compact target row in linked build tables" do
    targets = %w[
      fedora-43-aarch64
      fedora-43-x86_64
      fedora-44-aarch64
      fedora-44-x86_64
      fedora-rawhide-aarch64
      fedora-rawhide-x86_64
    ]
    rows = targets.map.with_index do |target, index|
      state = index.even? ? "failed" : "running"
      <<~ROW
        <tr>
          <td><a href="/results/#{target}/">#{target}</a></td>
          <td>revision-#{index + 1}</td>
          <td>#{index + 2} minutes</td>
          <td><a href="/logs/#{index}/builder">builder.log</a>, <a href="/logs/#{index}/backend">backend.log</a></td>
          <td>#{state}</td>
        </tr>
      ROW
    end.join
    html = <<~HTML
      <html><head><title>Build 4512 in example project</title></head><body>
        <nav><a href="/projects">All projects and build systems</a></nav>
        <main><h1>Build 4512</h1><table>
          <thead><tr><th>Chroot Name</th><th>Source Revision</th><th>Build Time</th><th>Logs</th><th>State</th></tr></thead>
          <tbody>#{rows}</tbody>
        </table></main>
      </body></html>
    HTML

    with_url_page("https://example.test/projects/sample/build/4512", html) do |page|
      payload = FetchUtil::Extractor.new(reader_mode: false).extract(page)
      markdown = payload["markdown"]

      expect(payload["contentType"]).to eq("list")
      expect(markdown.scan(/^- \[/).length).to eq(6)
      expect(markdown).to include(
        "fedora-43-aarch64",
        "fedora-44-x86_64",
        "fedora-rawhide-x86_64",
        "Source Revision: revision-1",
        "State: failed",
        "State: running"
      )
      expect(markdown).not_to include("All projects and build systems")
    end
  end

  it "preserves numeric record links and row-local fields in build indexes" do
    rows = 7.times.map do |index|
      build_id = 45_000 + index
      <<~ROW
        <tr>
          <td><a href="/controls/#{index}">view logs</a></td>
          <td><a href="/build/#{build_id}/">#{build_id}</a><a href="javascript:openDiagnostic(#{build_id})">launch diagnostic console</a></td>
          <td>package-#{index + 1}</td>
          <td>2.#{index}.0-1</td>
          <td>#{index + 1} hours ago</td>
          <td>#{index + 2} minutes</td>
          <td>succeeded</td>
        </tr>
      ROW
    end.join
    html = <<~HTML
      <html><head><title>Builds for example project</title></head><body><main>
        <h1>Builds</h1><table>
          <thead><tr><th>Control</th><th>Build ID</th><th>Package Name</th><th>Package Version</th><th>Submitted</th><th>Build Time</th><th>Status</th></tr></thead>
          <tbody>#{rows}</tbody>
        </table>
      </main></body></html>
    HTML

    with_url_page("https://example.test/projects/sample/builds", html) do |page|
      payload = FetchUtil::Extractor.new(reader_mode: false).extract(page)
      markdown = payload["markdown"]

      expect(payload["contentType"]).to eq("list")
      expect(markdown.scan(/^- \[/).length).to eq(7)
      expect(markdown).to include(
        "[45000]",
        "[45006]",
        "Package Name: package-1",
        "Package Version: 2.6.0-1",
        "Status: succeeded"
      )
      expect(markdown).not_to include("- [view logs]")
      expect(markdown).not_to include("javascript:", "- [launch diagnostic console]")
    end
  end

  it "resolves hierarchical monitor headers for every linked package row" do
    packages = %w[gsettings-desktop-schemas kde-settings nobara-login gcc zlib] + 7.times.map { |index| "library-#{index}" }
    rows = packages.map.with_index do |package, index|
      <<~ROW
        <tr>
          <td><a href="/packages/#{package}">#{package}</a></td>
          <td><a href="/builds/#{index}-43-a">succeeded</a></td>
          <td><a href="/builds/#{index}-43-x"><span title="running"></span></a></td>
          <td><a href="/builds/#{index}-44-a">failed</a></td>
          <td><a href="/builds/#{index}-44-x">succeeded</a></td>
          <td><a href="/builds/#{index}-raw-a">waiting</a></td>
          <td><a href="/builds/#{index}-raw-x">succeeded</a></td>
        </tr>
      ROW
    end.join
    html = <<~HTML
      <html><head><title>Project build monitor</title></head><body>
        <main><h1>Build monitor</h1>
          <details><summary>Possible states</summary><div>Legend-only state descriptions</div></details>
          <table>
            <thead>
              <tr><td colspan="7">Filters for current targets</td></tr>
              <tr><th rowspan="2">Package</th><th colspan="2">Fedora 43</th><th colspan="2">Fedora 44</th><th colspan="2">Rawhide</th></tr>
              <tr><th>aarch64</th><th>x86_64</th><th>aarch64</th><th>x86_64</th><th>aarch64</th><th>x86_64</th></tr>
            </thead>
            <tbody><tr class="data-table-spacer"></tr>#{rows}</tbody>
          </table>
        </main>
      </body></html>
    HTML

    with_url_page("https://example.test/projects/sample/monitor", html) do |page|
      payload = FetchUtil::Extractor.new(reader_mode: false).extract(page)
      markdown = payload["markdown"]

      expect(payload["contentType"]).to eq("list")
      expect(payload["warnings"]).not_to include("truncated_content")
      expect(markdown.scan(/^- \[/).length).to eq(12)
      expect(markdown).to include(
        "gsettings-desktop-schemas",
        "kde-settings",
        "nobara-login",
        "gcc",
        "zlib",
        "library-6",
        "Fedora 43 / aarch64: succeeded",
        "Fedora 43 / x86_64: running",
        "Fedora 44 / aarch64: failed",
        "Rawhide / aarch64: waiting"
      )
      expect(markdown).not_to include("Legend-only state descriptions", "Filters for current targets")
      expect(markdown.index("gsettings-desktop-schemas")).to be < markdown.index("library-6")
    end
  end

  it "aligns body rowspans with hierarchical table labels" do
    rows = 6.times.flat_map do |batch|
      number = batch + 1
      [
        <<~ROW,
          <tr>
            <td rowspan="2">Batch #{number}</td>
            <td><div class="entry"><a href="/packages/package-#{number}-a">package-#{number}-a</a></div></td>
            <td><span aria-label="passed"></span></td>
            <td>failed</td>
            <td><a href="/logs/#{number}-a">view logs</a></td>
          </tr>
        ROW
        <<~ROW
          <tr>
            <td><div class="entry"><a href="/packages/package-#{number}-b">package-#{number}-b</a></div></td>
            <td><span aria-label="running"></span></td>
            <td>queued</td>
            <td><a href="/logs/#{number}-b">view logs</a></td>
          </tr>
        ROW
      ]
    end.join
    expected = 6.times.flat_map do |batch|
      number = batch + 1
      [
        "- [package-#{number}-a](https://example.test/packages/package-#{number}-a) - " \
          "Batch: Batch #{number} | Build Status / aarch64: passed | " \
          "Build Status / x86_64: failed | Action: view logs",
        "- [package-#{number}-b](https://example.test/packages/package-#{number}-b) - " \
          "Batch: Batch #{number} | Build Status / aarch64: running | " \
          "Build Status / x86_64: queued | Action: view logs"
      ]
    end
    html = <<~HTML
      <html><head><title>Project build monitor</title></head><body><main>
        <h1>Build monitor</h1>
        <table>
          <thead>
            <tr>
              <th rowspan="2">Batch</th>
              <th rowspan="2">Package</th>
              <th colspan="2">Build Status</th>
              <th rowspan="2">Action</th>
            </tr>
            <tr><th>aarch64</th><th>x86_64</th></tr>
          </thead>
          <tbody>#{rows}</tbody>
        </table>
      </main></body></html>
    HTML

    with_url_page("https://example.test/projects/sample/monitor", html) do |page|
      payload = FetchUtil::Extractor.new(reader_mode: false).extract(page)
      markdown = payload["markdown"]

      expect(payload["contentType"]).to eq("list")
      expect(payload["warnings"]).not_to include("truncated_content")
      expect(markdown.scan(/^- \[/).length).to eq(12)
      expect(markdown).to eq(expected.join("\n"))
      expect(markdown).not_to include("- [view logs]")
    end
  end

  it "keeps logical columns after hidden rowspan rows are pruned" do
    rows = 6.times.map do |index|
      number = index + 1
      hidden_style = number.odd? ? "display: none" : "opacity: 0"
      <<~ROWS
        <tr style="#{hidden_style}">
          <td rowspan="2">Hidden batch #{number}</td>
          <td>helper package #{number}</td>
          <td>helper state</td>
          <td>helper state</td>
          <td>helper action</td>
        </tr>
        <tr>
          <td><a href="/packages/package-#{number}">package-#{number}</a></td>
          <td><span aria-label="passed"></span></td>
          <td>queued</td>
          <td><a href="/logs/#{number}">view logs</a></td>
        </tr>
      ROWS
    end.join
    expected = 6.times.map do |index|
      number = index + 1
      "- [package-#{number}](https://example.test/packages/package-#{number}) - " \
        "Build Status / aarch64: passed | Build Status / x86_64: queued | Action: view logs"
    end
    html = <<~HTML
      <html><head><title>Project build monitor</title></head><body><main>
        <h1>Build monitor</h1>
        <table>
          <thead>
            <tr>
              <th rowspan="2">Batch</th>
              <th rowspan="2">Package</th>
              <th colspan="2">Build Status</th>
              <th rowspan="2">Action</th>
            </tr>
            <tr><th>aarch64</th><th>x86_64</th></tr>
          </thead>
          <tbody>#{rows}</tbody>
        </table>
      </main></body></html>
    HTML

    with_url_page("https://example.test/projects/sample/monitor", html) do |page|
      payload = FetchUtil::Extractor.new(reader_mode: false).extract(page)
      markdown = payload["markdown"]

      expect(payload["contentType"]).to eq("list")
      expect(payload["warnings"]).not_to include("truncated_content")
      expect(markdown.scan(/^- \[/).length).to eq(6)
      expect(markdown).to eq(expected.join("\n"))
      expect(markdown).not_to include("Hidden batch", "- [view logs]")
    end
  end

  it "keeps operational reference tables inside prose articles" do
    rows = 7.times.map do |index|
      <<~ROW
        <tr>
          <td><a href="/reference/version-#{index}">Version #{index + 1}</a></td>
          <td>Architecture #{index + 1}</td>
          <td>Supported</td>
        </tr>
      ROW
    end.join
    paragraph = "This article explains how maintainers interpret build status, architecture support, release readiness, " \
                "and compatibility evidence before changing a published package reference. The linked matrix is " \
                "supporting material, not a record index, and the surrounding prose supplies operational context."
    html = <<~HTML
      <html><head><title>Understanding build status references</title></head><body><main>
        <h1>Understanding build status references</h1>
        <p class="byline">Release documentation team</p><time datetime="2026-07-21">21 July 2026</time>
        <p>#{paragraph}</p><p>#{paragraph}</p>
        <table>
          <thead><tr><th>Version</th><th>Architecture</th><th>Status</th></tr></thead>
          <tbody>#{rows}</tbody>
        </table>
      </main></body></html>
    HTML

    with_url_page("https://example.test/articles/build-status-reference", html) do |page|
      payload = FetchUtil::Extractor.new(reader_mode: false).extract(page)

      expect(payload["contentType"]).to eq("article")
      expect(payload["markdown"]).to include("Understanding build status references", "Version 1", "Architecture 7")
      expect(payload["markdown"]).not_to include("- [Version 1]")
    end
  end

  it "keeps explanatory polling articles with reference tables as articles" do
    rows = 8.times.map do |index|
      <<~ROW
        <tr>
          <td><a href="/reference/#{index}">Reference source #{index + 1}</a></td>
          <td>Method #{index + 1}</td>
          <td>Comparison note #{index + 1}</td>
        </tr>
      ROW
    end.join
    paragraph = "This explanatory section describes how survey design, weighting, fieldwork, uncertainty, and publication choices affect interpretation. " \
                "It provides narrative context for readers and uses the comparison table only as supporting reference material rather than as the primary page index."
    html = <<~HTML
      <html><head><title>Understanding polling methods</title></head><body><main><article>
        <h1>Understanding polling methods</h1>
        <p class="byline">Research desk</p>
        <time datetime="2026-07-20">20 July 2026</time>
        <p>#{paragraph}</p><p>#{paragraph}</p><p>#{paragraph}</p>
        <table>
          <thead><tr><th>Reference</th><th>Method</th><th>Comment</th></tr></thead>
          <tbody>#{rows}</tbody>
        </table>
      </article></main></body></html>
    HTML

    with_url_page("https://example.test/polling", html) do |page|
      payload = FetchUtil::Extractor.new(reader_mode: false).extract(page)

      expect(payload["contentType"]).to eq("article")
      expect(payload["markdown"]).to include("Understanding polling methods", "Reference source 1", "Comparison note 8")
      expect(payload["markdown"]).not_to include("- [Reference source 1]")
    end
  end

  it "does not render generic ranking scores as list detail" do
    first_title = "Ruby #{"a" * 104}"
    second_title = "Ruby #{"b" * 118}"
    cards = [first_title, second_title, "Ruby candidate gamma", "Ruby candidate delta", "Ruby candidate epsilon"].map.with_index do |title, index|
      "<article><h2><a href=\"/ruby/#{index}\">#{title}</a></h2></article>"
    end.join
    html = "<html><head><title>Ruby</title></head><body><main>#{cards}</main></body></html>"

    with_url_page("https://example.test/ruby", html) do |page|
      markdown = extract_payload(page, reader_mode: false)["markdown"]

      expect(markdown).not_to include("699", "713")
    end
  end

  it "renders evidence-bound card-local community metadata without chrome" do
    %w[reply replies comment comments].each do |reply_class|
      html = <<~HTML
        <html><head><title>Community cards</title></head><body><main>
          <article class="card"><h2><a href="/thread">Community thread</a></h2>
            <a rel="author">Ada</a><time>2h</time><span class="score">18 points</span>
            <span class="reply-count variant-#{reply_class}">4 replies</span><span class="community">dev.to</span>
          </article>
        </main><footer>Privacy Account</footer></body></html>
      HTML

      with_url_page("https://example.test/community", html) do |page|
        markdown = FetchUtil::Extractor.new(reader_mode: false).extract(page)["markdown"]
        expect(markdown).to include("Community thread", "Ada", "18 points", "4 replies", "dev.to")
        expect(markdown).not_to include("Privacy Account")
      end
    end
  end

  it "keeps opaque id detail pages as articles and collapses duplicated responsive prose" do
    plot = "After a banker is sentenced to life in Shawshank Prison, " \
           "he forms an unlikely friendship with a seasoned inmate and clings to hope amid cruelty and corruption."
    html = <<~HTML
      <html>
        <head><title>The Shawshank Redemption - Example Movies</title></head>
        <body>
          <main>
            <h1>The Shawshank Redemption</h1>
            <p data-testid="plot">
              <span role="presentation" data-testid="plot-xs_to_m"><span>#{plot}</span></span>
              <span role="presentation" data-testid="plot-l"><span>#{plot}</span></span>
              <span role="presentation" data-testid="plot-xl"><span>#{plot}</span></span>
            </p>
            <section>
              <h2>Top Cast</h2>
              <a href="/name/nm0000209/">Tim Robbins</a>
              <a href="/name/nm0000151/">Morgan Freeman</a>
              <a href="/name/nm0348409/">Bob Gunton</a>
            </section>
            <section>
              <h2>User Reviews</h2>
              <a href="/title/tt0111161/reviews/?featured=rw1">Prepare to be moved</a>
              <a href="/title/tt0111161/reviews/?featured=rw2">This is how movies should be made</a>
              <a href="/title/tt0111161/reviews/?featured=rw3">Eternal Hope</a>
            </section>
            <section>
              <h2>More Like This</h2>
              <a href="/title/tt0068646/">The Godfather</a>
              <a href="/title/tt0108052/">Schindler's List</a>
              <a href="/title/tt0110912/">Pulp Fiction</a>
            </section>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://www.example-movies.test/title/tt0111161/", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["contentType"]).to eq("article")
      expect(payload["markdown"].scan(plot).length).to eq(1)
      expect(payload["markdown"]).to include("Top Cast")
    end
  end

  it "removes cookie dialog chrome when real pinterest results are present" do
    html = <<~HTML
      <html>
        <head><title>Pinterest</title></head>
        <body>
          <div role="dialog" aria-modal="true" class="cookie-modal">
            <h2>Cookie Settings</h2>
            <p>We use cookies to personalize advertising and measure performance.</p>
            <button>Accept all cookies</button>
          </div>
          <main>
            <a href="/pin/1/" aria-label="ruby programming poster with examples"></a>
            <a href="/pin/2/" aria-label="ruby cheatsheet for arrays and hashes"></a>
            <a href="/pin/3/" aria-label="ruby metaprogramming diagram and notes"></a>
            <a href="/pin/4/" aria-label="ruby on rails guide for forms"></a>
            <a href="/pin/5/" aria-label="ruby blocks and enumerators visual guide"></a>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://www.pinterest.com/search/pins/?q=ruby+programming", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["contentType"]).to eq("list")
      expect(payload["markdown"]).to include("ruby programming poster with examples")
      expect(payload["warnings"]).not_to include("consent_interstitial")
      expect(payload["markdown"]).not_to include("Cookie Settings")
    end
  end

  it "prefers repeated homepage cards over footer stubs on portal-like homepages" do
    html = <<~HTML
      <html>
        <head><title>CalcioMercato</title></head>
        <body>
          <main>
            <section class="hero-grid">
              <article class="news-card"><h2><a href="/news/a">Milan prepara il prossimo incontro</a></h2><p>Note brevi sul lavoro della settimana.</p></article>
              <article class="news-card"><h2><a href="/news/b">Inter aggiorna il piano per il centrocampo</a></h2><p>I dettagli saranno discussi domani.</p></article>
              <article class="news-card"><h2><a href="/news/c">Napoli valuta due novità per la difesa</a></h2><p>Le opzioni restano in elenco.</p></article>
              <article class="news-card"><h2><a href="/news/d">Juventus, proseguono i colloqui per il rinnovo</a></h2><p>Nuove informazioni in arrivo.</p></article>
            </section>
          </main>
          <footer>
            <p>Copyright 2026 CalcioMercato</p>
            <a href="/privacy">Privacy</a>
          </footer>
        </body>
      </html>
    HTML

    with_url_page("https://www.calciomercato.com/", html) do |page|
      payload = FetchUtil::Extractor.new(reader_mode: false).extract(page)

      expect(payload["contentType"]).to eq("list")
      expect(payload["markdown"]).to include("Milan prepara il prossimo incontro")
      expect(payload["markdown"]).not_to include("Copyright 2026")
    end
  end

  it "keeps short CJK card titles when building list markdown" do
    html = <<~HTML
      <html>
        <head><title>中国社会科学网</title></head>
        <body>
          <main>
            <article><h2><a href="/a">记录城市生活的新观察</a></h2><p>日常经验值得整理。</p></article>
            <article><h2><a href="/b">推动社区服务的细节改进</a></h2><p>实践讨论逐步展开。</p></article>
            <article><h2><a href="/c">整理公共研究的新材料</a></h2><p>近期成果陆续发布。</p></article>
            <article><h2><a href="/d">让传统工艺融入当代生活</a></h2><p>旧方法与新需求结合。</p></article>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://cjk-list.example/", html) do |page|
      payload = FetchUtil::Extractor.new(reader_mode: false).extract(page)

      expect(payload["contentType"]).to eq("list")
      expect(payload["markdown"]).to include("记录城市生活的新观察")
      expect(payload["markdown"]).to include("让传统工艺融入当代生活")
    end
  end

  it "removes multilingual related and sharing chrome from generic article bodies" do
    html = <<~HTML
      <html lang="ja">
        <head><title>地域の学校で新しい給食計画</title></head>
        <body>
          <main>
            <article>
              <h1>地域の学校で読書週間が始まる</h1>
              <p>市内の小学校では、地域の図書館と協力した読書週間が始まりました。</p>
              <p>教室には季節の本を並べ、児童が感想を記録する時間も設けます。</p>
              <p>教育委員会は、学びと地域交流の両方を支える取り組みにしたいと説明しています。</p>
              <section class="share-buttons"><a href="/share">共有</a></section>
              <section>
                <h2>関連記事</h2>
                <a href="/other-a">観光イベントの日程</a>
                <a href="/other-b">週末の交通規制</a>
              </section>
            </article>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://example.jp/news/school-lunch-plan", html) do |page|
      payload = FetchUtil::Extractor.new(reader_mode: false).extract(page)
      markdown = payload["markdown"]

      expect(payload["contentType"]).to eq("article")
      expect(markdown).to include("読書週間が始まる")
      expect(markdown).not_to include("関連記事")
      expect(markdown).not_to include("観光イベント")
      expect(markdown).not_to include("共有")
      expect(payload["warnings"]).not_to include("multi_topic_page")
    end
  end

  it "downgrades homepage card grids to list mode even when about text is long" do
    html = <<~HTML
      <html>
        <head><title>Calciomercato Live: News, Trattative e Trasferimenti</title></head>
        <body>
          <header>
            <nav>
              <a href="/privacy">Privacy</a>
              <a href="/chi-siamo">Chi siamo</a>
            </nav>
          </header>
          <section class="news-grid">
            <article class="news-card"><h2><a href="/news/a">Marotta manda un messaggio alla squadra</a></h2><p>Ultime dichiarazioni e retroscena.</p></article>
            <article class="news-card"><h2><a href="/news/b">Milan, cessione da 24 milioni a un passo</a></h2><p>Accordo vicino per il trasferimento.</p></article>
            <article class="news-card"><h2><a href="/news/c">Lukaku verso l'addio: spunta una nuova destinazione</a></h2><p>Il club valuta la prossima mossa.</p></article>
            <article class="news-card"><h2><a href="/news/d">Kessie torna nel mirino di Inter e Juve</a></h2><p>Le ultime sul duello di mercato.</p></article>
          </section>
          <section class="about-box">
            <h2>Chi siamo</h2>
            <p>Calciomercato.it e' una testata giornalistica dedicata all'informazione calcistica con news, approfondimenti, video e aggiornamenti sul mercato italiano ed estero.</p>
            <p>Il sito e' il prodotto di punta di una realta' editoriale digitale specializzata nella copertura quotidiana di Serie A, coppe e trasferimenti.</p>
            <p>Il gruppo sviluppa contenuti editoriali, social e multimediali rivolti a tifosi, appassionati e addetti ai lavori.</p>
            <p>La redazione segue club italiani e campionati internazionali con focus su trattative, interviste e analisi.</p>
            <p>Copyright 2026 - Tutti i diritti riservati.</p>
          </section>
        </body>
      </html>
    HTML

    with_url_page("https://www.calciomercato.it/", html) do |page|
      payload = FetchUtil::Extractor.new(reader_mode: false).extract(page)

      expect(payload["contentType"]).to eq("list")
      expect(payload["markdown"]).to include("Marotta manda un messaggio alla squadra")
      expect(payload["markdown"]).to include("Kessie torna nel mirino di Inter e Juve")
      expect(payload["markdown"]).to include("Calciomercato.it e' una testata")
      expect(payload["markdown"].scan("Chi siamo")).to eq(["Chi siamo"])
      expect(payload["markdown"]).not_to include("/chi-siamo")
    end
  end

  it "cleans malformed markdown from image-led card grids" do
    html = <<~HTML
      <html>
        <head><title>Daily Section</title></head>
        <body>
          <main>
            <article>
              <h1>Daily Section</h1>
              <p>Lead coverage and analysis from the day.</p>
              <ul class="card-grid">
                <li>
                  <a href="/world/one">
                    <img src="/one.jpg" alt="">
                    <h3>First headline from the card grid</h3>
                  </a>
                </li>
                <li>
                  <a href="/world/two">
                    <img src="/two.jpg" alt="Reporter at border [US side.]">
                    <h3>Second headline from the card grid</h3>
                  </a>
                </li>
              </ul>
            </article>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://example.test/international", html) do |page|
      payload = FetchUtil::Extractor.new(reader_mode: false).extract(page)

      expect(payload["markdown"]).to include("- [First headline from the card grid](https://example.test/world/one)")
      expect(payload["markdown"]).to include("- [Second headline from the card grid](https://example.test/world/two)")
      expect(payload["markdown"]).not_to include("- !###")
      expect(payload["markdown"]).not_to match(/\]\([^)]*\)\]/)
    end
  end

  it "cleans orphan bracket fragments from nested card-grid links" do
    html = <<~HTML
      <html>
        <head><title>Mission Cards</title></head>
        <body>
          <main>
            <article>
              <h1>Mission Cards</h1>
              <section class="card-grid">
                <div class="card">
                  <a href="/facts"><img src="/folding.jpg" alt=""></a>
                  <div>
                    <a href="/facts"><h3>Folding Design</h3></a>
                    <p>So big it has to fold origami-style to fit in the rocket.</p>
                  </div>
                </div>
                <div class="card">
                  <a href="/blog/one"><figure><img src="/one.jpg" alt=""></figure></a>
                  <div>
                    <a href="/blog/one"><p>Webb Detects Methane on Interstellar Comet</p></a>
                    <p>A short science update from the observatory.</p>
                  </div>
                </div>
              </section>
            </article>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://science.example/mission/webb/", html) do |page|
      payload = FetchUtil::Extractor.new(reader_mode: false).extract(page)
      markdown = payload["markdown"]

      expect(markdown).to include("### [Folding Design](https://science.example/facts)")
      expect(markdown).to include("[Webb Detects Methane on Interstellar Comet](https://science.example/blog/one)")
      expect(markdown).not_to match(/^\s*\[\s*$/)
      expect(markdown).not_to match(%r{^\s*\]\(https?://[^)]+\)\[?\s*$})
    end
  end

  it "does not repeat sibling docs card text in every list item" do
    html = <<~HTML
      <html>
        <head><title>Hugo Documentation</title></head>
        <body>
          <main>
            <section class="docs-grid">
                <a class="a--block group border" href="/about/"><h3>About</h3><p>Learn about Hugo and its features, privacy protections, and security model.</p></a>
                <a class="a--block group border" href="/commands/"><h3>CLI</h3><p>Use the command line interface (CLI) to manage your project.</p></a>
                <a class="a--block group border" href="/configuration/"><h3>Configuration</h3><p>Configure your site.</p></a>
                <a class="a--block group border" href="/content-management/"><h3>Content management</h3><p>Hugo makes managing large static sites easy with support for archetypes, content types, menus, cross references, summaries, and more.</p></a>
                <a class="a--block group border" href="/contribute/"><h3>Contribute</h3><p>Contribute to development, documentation, and themes.</p></a>
                <a class="a--block group border" href="/tools/"><h3>Developer tools</h3><p>Third-party tools to help you create and manage sites.</p></a>
                <a class="a--block group border" href="/functions/"><h3>Functions</h3><p>Use these functions within your templates and archetypes.</p></a>
                <a class="a--block group border" href="/getting-started/"><h3>Getting started</h3><p>How to get started with Hugo.</p></a>
                <a class="a--block group border" href="/host-and-deploy/"><h3>Host and deploy</h3><p>Services and tools to host and deploy your site.</p></a>
                <a class="a--block group border" href="/hugo-modules/"><h3>Hugo modules</h3><p>Use Hugo modules to manage the content, presentation, and behavior of your site.</p></a>
                <a class="a--block group border" href="/hugo-pipes/"><h3>Hugo Pipes</h3><p>Use asset pipelines to transform and optimize images, stylesheets, and JavaScript.</p></a>
                <a class="a--block group border" href="/installation/"><h3>Installation</h3><p>Install Hugo on macOS, Linux, Windows, BSD, and on any machine that can run the Go compiler tool chain.</p></a>
                <a class="a--block group border" href="/methods/"><h3>Methods</h3><p>Use these methods within your templates.</p></a>
                <a class="a--block group border" href="/quick-reference/"><h3>Quick reference</h3><p>Use these quick reference guides for quick access to key information.</p></a>
                <a class="a--block group border" href="/render-hooks/"><h3>Render hooks</h3><p>Create render hook templates to override the rendering of Markdown to HTML.</p></a>
                <a class="a--block group border" href="/shortcodes/"><h3>Shortcodes</h3><p>Insert elements such as videos, images, and social media embeds into your content using Hugo's embedded shortcodes.</p></a>
                <a class="a--block group border" href="/templates/"><h3>Templates</h3><p>Create templates to render your content, resources, and data.</p></a>
            </section>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://gohugo.io/", html) do |page|
      payload = FetchUtil::Extractor.new(reader_mode: false).extract(page)
      markdown = payload["markdown"]

      expect(markdown).to include("Content management")
      expect(markdown).to include("Hugo makes managing large static sites easy")
      expect(markdown.scan("Content management").length).to be <= 2
      expect(markdown.scan("Hugo modules").length).to be <= 2
      expect(markdown).not_to include("AboutLearn about Hugo")
    end
  end

  it "cleans duplicated ASP.NET data-table labels and footnote markers" do
    html = <<~HTML
      <html>
        <head><title>Convention declarations</title></head>
        <body>
          <main>
            <h1>Declarations and Reservations</h1>
            <table id="ctl00_ContentPlaceHolder1_dgDec">
              <tr>
                <td>
                  <p>Austria <sup><a href="#15">15</a></sup></p>
                  <div id="ctl00_ContentPlaceHolder1_dgDec_ctl03_divText">
                    <p>Austria<superscript>15</superscript></p>
                    <p><i>Declaration:</i></p>
                    <p>Austria regards article 15 as the legal basis for inadmissibility.</p>
                  </div>
                </td>
              </tr>
              <tr>
                <td>
                  <p>Bangladesh <sup><a href="#17">17</a>, <a href="#18">18</a></sup></p>
                  <div id="ctl00_ContentPlaceHolder1_dgDec_ctl04_divText">
                    <p>Bangladesh<superscript>17,18</superscript></p>
                    <p><i>Declaration:</i></p>
                    <p>The Government makes this declaration upon ratification.</p>
                  </div>
                </td>
              </tr>
              <tr>
                <td>
                  <p>Bahamas (The)</p>
                  <div id="ctl00_ContentPlaceHolder1_dgDec_ctl05_divText">
                    <p>Bahamas (The)</p>
                    <p><i>Reservations:</i></p>
                    <p>The Government does not recognize article 20 competence.</p>
                  </div>
                </td>
              </tr>
            </table>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://treaties.un.org/pages/ViewDetails.aspx?src=TREATY&mtdsg_no=IV-9&chapter=4", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)
      markdown = payload["markdown"]

      expect(markdown).to include("Austria 15 Declaration:")
      expect(markdown).to include("Bangladesh 17, 18 Declaration:")
      expect(markdown).to include("Bahamas (The) Reservations:")
      expect(markdown).not_to include("Austria 15 Austria15")
      expect(markdown).not_to include("Bangladesh 17, 18 Bangladesh17,18")
      expect(markdown).not_to include("Bahamas (The) Bahamas (The)")
    end
  end

  it "removes empty headings and inline subscription promo modules from articles" do
    html = <<~HTML
      <html>
        <head><title>Physics Overview</title></head>
        <body>
          <main>
            <article>
              <h1>Physics Overview</h1>
              <section>
                <h2>Top Questions</h2>
                <h3><span class="anchor"></span></h3>
                <p>Why does physics use SI units?</p>
              </section>
              <p>Physics studies matter, motion, and energy through observation and experiment.</p>
              <section class="inline-subscription-promo marketing-module">
                <p>The trusted destination for professionals, college students, and lifelong learners.</p>
                <p>Save 30% on annual subscriptions this July Fourth!</p>
                <img src="/marketing/inline-left.webp" alt="Penguin, ship, mountain, atlas">
                <img src="/marketing/inline-right.webp" alt="Shohei Ohtani, plants, and art">
              </section>
              <p>Explore 30% SUBSCRIBE</p>
              <p>Reference AIchevron_right AI-generated answers from reference articles. AI makes mistakes, so verify using source articles.</p>
              <p>Classical mechanics describes forces and motion at everyday scales.</p>
            </article>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://reference.example/science/physics", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)
      markdown = payload["markdown"]

      expect(payload["contentType"]).to eq("article")
      expect(markdown).to include("Top Questions")
      expect(markdown).to include("Why does physics use SI units?")
      expect(markdown).to include("Classical mechanics describes forces")
      expect(markdown).not_to match(/^###\s*$/)
      expect(markdown).not_to include("Save 30%")
      expect(markdown).not_to include("trusted destination")
      expect(markdown).not_to include("marketing/inline-left")
      expect(markdown).not_to include("Explore 30% SUBSCRIBE")
      expect(markdown).not_to include("AI-generated answers")
    end
  end

  it "removes reference article left-rail toc and quiz chrome before body text" do
    html = <<~HTML
      <html>
        <head><title>Physics | Reference</title></head>
        <body>
          <main>
            <article class="topic-desktop article-content">
              <div class="topic-left-rail md-article-drawer">
                <div class="toc">
                  <a href="/science/physics-science">Introduction &amp; Top Questions</a>
                  <a href="/science/physics-science#mechanics">Mechanics</a>
                  <a href="/science/physics-science#optics">Optics</a>
                  <a href="/science/physics-science/additional-info">References &amp; Edit History</a>
                </div>
                <section class="tlr-quiz-sidebar">
                  <h2>Quizzes</h2>
                  <a href="/quiz/faces-of-science">Faces of Science</a>
                  <a href="/quiz/all-about-physics">All About Physics Quiz</a>
                </section>
              </div>
              <div class="topic-content">
                <h1>Physics</h1>
                <p>Physics is the branch of science that deals with the structure of matter and how the fundamental constituents of the universe interact.</p>
                <p>Classical mechanics describes the motion of bodies under the action of forces.</p>
              </div>
            </article>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://reference.example/science/physics-science", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)
      markdown = payload["markdown"]

      expect(payload["contentType"]).to eq("article")
      expect(markdown).to include("Physics is the branch of science")
      expect(markdown).to include("Classical mechanics describes")
      expect(markdown).not_to include("Introduction & Top QuestionsMechanicsOptics")
      expect(markdown).not_to include("Faces of Science")
      expect(markdown).not_to include("All About Physics Quiz")
    end

    flattened_html = <<~HTML
      <html>
        <head><title>Physics | Reference</title></head>
        <body>
          <main>
            <article>
              <h1>Physics</h1>
              <p>physics Introduction &amp; Top QuestionsThe scope of physicsMechanicsOptics References &amp; Edit History Related Topics Images &amp; Videos At a Glance physics summary Quizzes Faces of Science All About Physics Quiz physics science Written by Example Author Fact-checked by Reference Editors Last updated June 4, 2026 •History Top Questions What is physics?Physics is the branch of science that deals with the structure of matter and how the fundamental constituents of the universe interact. Why does physics work in SI units? Physics uses defined units for measurement.</p>
            </article>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://reference.example/science/physics-science", flattened_html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)
      markdown = payload["markdown"]

      expect(markdown).to include("Top Questions What is physics? Physics is the branch of science")
      expect(markdown).not_to include("Introduction & Top QuestionsThe scope")
      expect(markdown).not_to include("All About Physics Quiz")
      expect(markdown).not_to include("Written by Example Author")
    end
  end

  it "removes trailing AI summaries and related legal marketing after case bodies" do
    html = <<~HTML
      <html>
        <head><title>Example v. Board, 347 U.S. 483</title></head>
        <body>
          <main>
            <article>
              <h1>Example v. Board</h1>
              <p>MR. CHIEF JUSTICE WARREN delivered the opinion of the Court.</p>
              <p>Separate educational facilities are inherently unequal.</p>
              <p>It is so ordered.</p>
              <section class="feedback-summary related-content">
                <p>Was this summary helpful? Thank you for feedback!</p>
                <h2>AI Summary</h2>
                <p>AI-generated summaries may contain mistakes and should be verified.</p>
                <h2>You May Also Like</h2>
                <a href="/related">Understanding this case</a>
                <h2>Need Find Attorney?</h2>
                <p>Search our directory by legal issue.</p>
                <p>For Legal Professionals Sign Up Get updates.</p>
              </section>
            </article>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://case.example/court/supreme/347/483.html", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)
      markdown = payload["markdown"]

      expect(payload["contentType"]).to eq("article")
      expect(markdown).to include("MR. CHIEF JUSTICE WARREN")
      expect(markdown).to include("It is so ordered.")
      expect(markdown).not_to include("Was this summary helpful")
      expect(markdown).not_to include("AI-generated summaries")
      expect(markdown).not_to include("You May Also Like")
      expect(markdown).not_to include("Need Find Attorney")
      expect(markdown).not_to include("For Legal Professionals")
    end
  end

  it "removes leading legal case table navigation before judgment bodies" do
    html = <<~HTML
      <html>
        <head><title>White v Chief Constable [1998] UKHL 45</title></head>
        <body>
          <table>
            <tr>
              <td rowspan="2"><a href="/"><img alt="BAILII" src="/logo.jpg"></a></td>
              <td>[<a href="/">Home</a>] [<a href="/databases.html">Databases</a>] [<a href="/world/">World Law</a>] [<a href="/search">Multidatabase Search</a>] [<a href="/help">Help</a>] [<a href="/donate">DONATE</a>]</td>
            </tr>
            <tr><td><h2>United Kingdom House of Lords Decisions</h2></td></tr>
            <tr><td colspan="3"><p><b>THE FUTURE OF BAILII DEPENDS ON USERS LIKE YOU</b></p><p>Please consider making a donation to support free access to law.</p></td></tr>
            <tr><td colspan="3"><small><b>You are here:</b> BAILII &gt;&gt; Databases &gt;&gt; United Kingdom House of Lords Decisions<br>URL: https://www.bailii.org/uk/cases/UKHL/1998/45.html<br>Cite as: [1998] UKHL 45</small></td></tr>
          </table>
          <p>[<a href="/form/search_cases.html">New search</a>] [Buy ICLR report: <a href="/report">[1998] 3 WLR 1509</a>] [<a href="/help">Help</a>]</p>
          <p>JISCBAILII_CASE_TORT</p>
          <h2>White and Others v. Chief Constable of South Yorkshire and Others [1998] UKHL 45 (3 December, 1998)</h2>
          <p><b>HOUSE OF LORDS</b></p>
          <p><b>OPINIONS OF THE LORDS OF APPEAL FOR JUDGMENT IN THE CAUSE</b></p>
          <p><b>LORD BROWNE-WILKINSON</b></p>
          <p>My Lords, I have read in draft the speeches of my noble and learned friends.</p>
          <p><b>LORD GRIFFITHS</b></p>
          <p>I have had the advantage of reading the speeches of your Lordships before giving my own opinion.</p>
        </body>
      </html>
    HTML

    with_url_page("https://www.bailii.org/uk/cases/UKHL/1998/45.html", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)
      markdown = payload["markdown"]

      expect(payload["contentType"]).to eq("article")
      expect(markdown).to start_with("# White v Chief Constable [1998] UKHL 45\n\n## White and Others")
      expect(markdown).to include("My Lords, I have read in draft")
      expect(markdown).not_to include("Multidatabase Search")
      expect(markdown).not_to include("THE FUTURE OF BAILII")
      expect(markdown).not_to include("New search")
    end
  end

  it "does not duplicate nested layout table content when converting comments" do
    html = <<~HTML
      <html>
        <head><title>Example thread</title></head>
        <body>
          <center>
            <table id="hnmain">
              <tr><td>
                <table><tr><td><span class="pagetop"><b>Hacker News</b><a href="/newest">new</a> | <a href="/front">past</a></span></td></tr></table>
              </td></tr>
              <tr><td>
                <table class="fatitem">
                  <tr class="athing submission" id="1"><td class="title"><span class="titleline"><a href="http://ycombinator.com/">Y Combinator</a></span></td></tr>
                  <tr><td class="subtext"><span class="score">57 points</span> by <a class="hnuser">pg</a> <span class="age">on Oct 9, 2006</span> | <a>3 comments</a></td></tr>
                </table>
                <table class="comment-tree">
                  <tr class="athing comtr" id="15"><td><table><tr><td class="default"><span class="comhead">sama on Oct 9, 2006 | next [–]</span><div class="comment"><div class="commtext c00">the rising star of venture capital</div></div></td></tr></table></td></tr>
                  <tr class="athing comtr" id="17"><td><table><tr><td class="default"><span class="comhead">pg on Oct 9, 2006 | parent | next [–]</span><div class="comment"><div class="commtext c00">Is there anywhere to eat on Sandhill Road?</div></div></td></tr></table></td></tr>
                  <tr class="athing comtr" id="1079"><td><table><tr><td class="default"><span class="comhead">dmon on Feb 25, 2007 | root | parent | next [–]</span><div class="comment"><div class="commtext c00">sure</div></div></td></tr></table></td></tr>
                </table>
              </td></tr>
            </table>
          </center>
        </body>
      </html>
    HTML

    with_url_page("https://news.ycombinator.com/item?id=1", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["markdown"].scan("the rising star of venture capital").length).to eq(1)
      expect(payload["markdown"].scan("Is there anywhere to eat on Sandhill Road?").length).to eq(1)
      expect(payload["markdown"]).not_to include("Hacker Newsnew | past")
    end
  end
end
