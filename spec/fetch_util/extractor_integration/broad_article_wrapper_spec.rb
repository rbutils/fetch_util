# frozen_string_literal: true

RSpec.describe "broad article wrapper extraction" do
  include_context "extractor integration helpers"

  let(:story_cards) do
    Array.new(4) do |index|
      number = index + 1
      heading = if index.even?
                  %(<a href="/politics/story-#{number}"><h2>Policy report headline number #{number}</h2></a>)
                else
                  %(<h2><a href="/politics/story-#{number}">Policy report headline number #{number}</a></h2>)
                end
      <<~HTML
        <section class="story-card">
          #{heading}
          <p>Detailed summary for policy report number #{number} and its public impact.</p>
        </section>
      HTML
    end.join
  end

  it "does not give a broad category wrapper focal article ownership" do
    result = extract_result("https://example.com/politics/") do
      <<~HTML
        <html><head><title>Politics</title></head><body>
          <main>
            <article class="page-section">
              <h1>Politics</h1>
              <p>Current reporting and analysis from across the public policy desk.</p>
              #{story_cards}
            </article>
          </main>
        </body></html>
      HTML
    end

    expect(result["contentType"]).to eq("list")
    expect(result["markdown"].scan(%r{https://example\.com/politics/story-\d})).to eq(
      (1..4).map { |number| "https://example.com/politics/story-#{number}" }
    )
  end

  it "preserves explicit semantic article ownership on a list-like route" do
    result = extract_result("https://example.com/news/") do
      <<~HTML
        <html><head><title>Public policy investigation</title></head><body>
          <main>
            <article role="main">
              <h1>Public policy investigation</h1>
              <p>This investigation follows one policy over several years and explains its consequences.</p>
              <p>The reporting is based on public records, interviews, and direct observations.</p>
              #{story_cards}
            </article>
          </main>
        </body></html>
      HTML
    end

    expect(result["contentType"]).to eq("article")
    expect(result["markdown"]).to include("This investigation follows one policy")
  end

  it "preserves a sole article wrapper on a detail route" do
    result = extract_result("https://example.com/stories/a-detailed-policy-report") do
      <<~HTML
        <html><head><title>A detailed policy report</title></head><body>
          <main>
            <article class="page-section">
              <h1>A detailed policy report</h1>
              <p>This report explains the policy history and the evidence behind its conclusions.</p>
              <p>Each section gives readers the context needed to understand the final recommendation.</p>
              #{story_cards}
            </article>
          </main>
        </body></html>
      HTML
    end

    expect(result["contentType"]).to eq("article")
    expect(result["markdown"]).to include("This report explains the policy history")
  end

  it "preserves a sole live article on an article-shaped list route" do
    result = extract_result("https://example.com/news/live") do
      updates = Array.new(4) do |index|
        number = index + 1
        <<~HTML
          <section class="story-card live-update">
            <h2><a href="/news/live#update-#{number}">Policy development update #{number}</a></h2>
            <p>Update #{number} records a substantive development and explains its immediate consequences.</p>
          </section>
        HTML
      end.join
      <<~HTML
        <html><head><title>Policy decision live updates</title></head><body>
          <main>
            <article class="live-updates">
              <h1>Policy decision live updates</h1>
              <p>This live article follows one policy decision and explains each development in context.</p>
              <p>Reporting is updated as public records and statements become available.</p>
              #{updates}
            </article>
          </main>
        </body></html>
      HTML
    end

    expect(result["contentType"]).to eq("article")
    expect(result["markdown"]).to include("This live article follows one policy decision")
    expect(result["markdown"]).to include("Policy development update 4")
  end

  it "ignores hidden records and unsafe linked headings at the threshold" do
    result = extract_result("https://example.com/politics/") do
      <<~HTML
        <html><head><title>Policy briefing</title></head><body>
          <main>
            <article class="page-section">
              <h1>Policy briefing</h1>
              <p>This briefing is a single report with supporting references for interested readers.</p>
              <section class="story-card">
                <a href="/reference/one"><h2>Supporting reference headline one</h2></a>
                <p>Background material for the first supporting reference in this report.</p>
              </section>
              <section class="story-card">
                <a href="/reference/two"><h2>Supporting reference headline two</h2></a>
                <p>Background material for the second supporting reference in this report.</p>
              </section>
              <section class="story-card" style="display: none">
                <a href="/reference/hidden"><h2>Hidden supporting reference headline</h2></a>
                <p>This record is not visible and cannot establish broad list ownership.</p>
              </section>
              <section class="story-card">
                <a href="javascript:alert(1)"><h2>Unsafe supporting reference headline</h2></a>
                <p>This unsafe destination cannot establish broad list ownership either.</p>
              </section>
            </article>
          </main>
        </body></html>
      HTML
    end

    expect(result["contentType"]).to eq("article")
    expect(result["markdown"]).to include("This briefing is a single report")
  end

  it "does not combine unrelated record and linked-heading evidence" do
    result = extract_result("https://example.com/politics/") do
      <<~HTML
        <html><head><title>Policy briefing</title></head><body>
          <main>
            <article class="page-section">
              <h1>Policy briefing</h1>
              <p>This briefing is a single report with supporting records and references.</p>
              #{Array.new(3) do |index|
                  "<section class=\"story-card\"><p>Supporting record #{index + 1} gives additional context without defining a separate story.</p></section>"
                end.join}
              #{Array.new(3) do |index|
                  "<h2><a href=\"/reference/#{index + 1}\">Supporting reference headline number #{index + 1}</a></h2>"
                end.join}
            </article>
          </main>
        </body></html>
      HTML
    end

    expect(result["contentType"]).to eq("article")
    expect(result["markdown"]).to include("This briefing is a single report")
  end

  def extract_result(url)
    result = nil
    extract_from_url(url, yield) { |payload| result = payload }
    result
  end
end
