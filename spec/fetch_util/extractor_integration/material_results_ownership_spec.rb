RSpec.describe "source-owned material search results" do
  include_context 'extractor integration helpers'

  def material_result_card(index, title, summary, image: true)
    media = image ? %(<img src="/covers/#{index}.jpg" alt="#{title} cover">) : ""
    %(<div role="article"><h3><a href="/gallery/#{index}"><span class="project-title">#{title}</span></a></h3>#{media}<p>#{summary}</p></div>)
  end

  def material_results_page(query, feed, count:, before: "", after: "", feed_attributes: "")
    <<~HTML
      <html><head><title>Search results for #{query}</title></head><body>
        <main>#{before}
          <section role="region" aria-label="Search Results">
            <div id="result-count" role="region" aria-label="Search Result Count and Filters">
              <h2>#{count} Results for #{query}</h2>
            </div>
            <div aria-describedby="result-count">
              <div role="feed" aria-label="Projects" #{feed_attributes}>#{feed}</div>
            </div>
          </section>
          #{after}
        </main>
      </body></html>
    HTML
  end

  def with_material_search(query, html)
    with_url_page("https://results.example/search?q=#{query.tr(" ", "+")}", html) do |page|
      before = page.evaluate("document.body.outerHTML")
      payload = FetchUtil::Extractor.new.extract(page)
      yield page, payload, before
    end
  end

  it "keeps complete query-owned cards and excludes proved promotion and related rails" do
    html = <<~HTML
      <html>
        <head>
          <title>Graphic Design Search</title>
          <link rel="canonical" href="https://results.example/topics/brand-identity">
        </head>
        <body>
          <main>
            <section role="region" aria-label="Search Results">
              <div id="design-result-count" role="region" aria-label="Search Result Count and Filters">
                <h2>10,000+ Results for graphic design</h2>
              </div>
              <div aria-describedby="design-result-count">
                <section role="feed" aria-label="Projects">
                  <div role="article">
                    <h3><a href="/gallery/249299349/identity-study">Identity Study 404</a></h3>
                    <span>404 appreciations for Identity Study</span>
                    <p>Creative studio portfolio and editorial work</p>
                  </div>
                  <div role="article">
                    <h3><a href="/gallery/231794739/type-system"><span class="project-title">Shift</span></a></h3>
                    <img src="/covers/shift.jpg" alt="Shift project cover">
                    <p>Research, typography, and visual identity</p>
                  </div>
                  <div role="article">
                    <h3><a href="/gallery/252102421/printed-matter">Printed Matter and Image Making</a></h3>
                    <p>Independent design publication</p>
                  </div>
                  <div role="article">
                    <h3><a href="/gallery/255319945/visual-systems">Visual Systems for Civic Spaces</a></h3>
                    <p>Community research and a public identity system</p>
                  </div>
                  <div role="article">
                    <h3>Do more with Design Pro</h3>
                    <a href="/pro">Start Free Trial</a>
                    <a href="/pro">Learn more</a>
                  </div>
                </section>
              </div>
              <h3>Log in or sign up to view more projects</h3>
            </section>
            <aside aria-label="Related image library">
              <div role="feed" aria-label="Image library projects">
                #{(1..5).map do |index|
                  %(<div role="article"><a href="/image/#{index}"><img src="/image-#{index}.jpg" alt=""><span class="image-title">Image library project #{index} preview</span></a></div>)
                end.join("\n")}
              </div>
            </aside>
          </main>
        </body>
      </html>
    HTML

    with_material_search("graphic design", html) do |page, payload, before|
      expect(payload["contentType"]).to eq("list")
      expect(payload["warnings"]).not_to include("not_found_interstitial")
      expect(payload["markdown"]).to include(
        "Identity Study 404", "Creative studio portfolio", "Shift", "Research, typography",
        "Printed Matter and Image Making", "Visual Systems for Civic Spaces"
      )
      expect(payload["markdown"]).not_to include("Start Free Trial", "Image library project")
      expect(payload["html"]).to include("https://results.example/covers/shift.jpg")
      expect(page.evaluate("document.body.outerHTML")).to eq(before)
    end
  end

  it "retains all twenty-four results including a source-owned text-only final card" do
    query = "design projects"
    cards = (1..23).map do |index|
      material_result_card(
        index,
        "Visual project #{index} in the source portfolio",
        "Source-owned context for visual project #{index} and its complete presentation."
      )
    end
    cards << material_result_card(
      24,
      "Plain structured project record number twenty four",
      "This source-owned text-only project remains part of the visible query results.",
      image: false
    )
    html = material_results_page(query, cards.join, count: "24")

    with_material_search(query, html) do |page, payload, before|
      expect(payload["contentType"]).to eq("list")
      titles = (1..23).map { |index| "Visual project #{index} in the source portfolio" }
      titles << "Plain structured project record number twenty four"
      positions = titles.map do |title|
        expect(payload["markdown"]).to include(title)
        payload["markdown"].index(title)
      end
      expect(positions).to eq(positions.sort)
      expect(page.evaluate("document.body.outerHTML")).to eq(before)
    end
  end

  it "declines the entire list candidate when a visible result child is unrecognized" do
    query = "design projects"
    cards = (1..23).map do |index|
      material_result_card(
        index,
        "Visual project #{index} in the source portfolio",
        "Source-owned context for visual project #{index} and its complete presentation."
      )
    end.join
    unknown = '<div role="article"><p>Unmapped visible material belongs to this query owner and cannot be discarded.</p></div>'
    html = material_results_page(query, cards + unknown, count: "24")

    with_material_search(query, html) do |page, payload, before|
      expect(page.evaluate('document.querySelectorAll("[role=feed] > [role=article]").length')).to eq(24)
      expect(payload["contentType"]).not_to eq("list")
      expect(page.evaluate("document.body.outerHTML")).to eq(before)
      expect(page.evaluate('document.querySelectorAll("[role=feed] > [role=article]").length')).to eq(24)
    end
  end

  it "keeps duplicate source occurrences when the complete result candidate is accepted" do
    query = "design projects"
    cards = (1..23).map do |index|
      material_result_card(
        index,
        "Visual project #{index} in the source portfolio",
        "Source-owned context for visual project #{index} and its complete presentation."
      )
    end
    cards << material_result_card(
      1,
      "Visual project 1 in the source portfolio",
      "A second visible occurrence with the same title and destination remains distinct."
    )
    html = material_results_page(query, cards.join, count: "24")

    with_material_search(query, html) do |page, payload, before|
      if payload["contentType"] == "list"
        expect(payload["markdown"].scan("Visual project 1 in the source portfolio").length).to eq(2)
        expect(payload["markdown"]).to include(
          "Source-owned context for visual project 1",
          "A second visible occurrence with the same title and destination remains distinct."
        )
      end
      expect(page.evaluate("document.body.outerHTML")).to eq(before)
      expect(page.evaluate('document.querySelectorAll("[role=feed] > [role=article]").length')).to eq(24)
    end
  end

  it "keeps genuine not-found responses when result-like material is hidden, unrelated, or empty" do
    query = "missing record"
    suggestions = (1..4).map do |index|
      material_result_card(
        index,
        "Editorial suggestion #{index} for the archive",
        "A related public record from the editorial archive."
      )
    end.join
    error = '<h1>The requested page was not found</h1><p>The requested record is unavailable.</p>'
    valid_region = lambda do |count, feed, attributes = ""|
      <<~HTML
        <section role="region" aria-label="Search Results">
          <div id="error-count" role="region" aria-label="Search Result Count and Filters"><h2>#{count} Results for #{query}</h2></div>
          <div aria-describedby="error-count"><div role="feed" aria-label="Suggestions" #{attributes}>#{feed}</div></div>
        </section>
      HTML
    end
    cases = {
      "hidden results" => valid_region.call("40", suggestions, 'aria-hidden="true"'),
      "aside suggestions" => <<~HTML,
        <section role="region" aria-label="Search Results">
          <div id="error-count" role="region" aria-label="Search Result Count and Filters">
            <h2>40 Results for #{query}</h2>
          </div>
          <div aria-describedby="error-count"><aside><div role="feed">#{suggestions}</div></aside></div>
        </section>
      HTML
      "mismatched query label" => <<~HTML,
        <section role="region" aria-label="Search Results">
          <div id="error-count" role="region" aria-label="Search Result Count and Filters">
            <h2>40 Results for a different query</h2>
          </div>
          <div aria-describedby="error-count"><div role="feed">#{suggestions}</div></div>
        </section>
      HTML
      "empty owner" => valid_region.call("0", "")
    }

    cases.each do |name, results|
      html = "<html><head><title>Record unavailable</title></head><body><main>#{error}#{results}</main></body></html>"
      with_material_search(query, html) do |_page, payload, _before|
        aggregate_failures(name) do
          expect(payload["contentType"]).to eq("interstitial")
          expect(payload["warnings"]).to include("not_found_interstitial")
        end
      end
    end
  end

  it "keeps a queried article and its publication date beside recommendation cards" do
    query = "civic design"
    cards = (1..4).map do |index|
      material_result_card(
        index,
        "Related design story #{index} from the archive",
        "A related story with its own complete source summary."
      )
    end.join
    article = <<~HTML
      <article>
        <header><h1>A field study of civic design</h1><time datetime="2025-06-10T09:30:00Z">June 10, 2025</time></header>
        <p>The first source-owned paragraph describes the public research and the decisions that shaped the work.</p>
        <p>The second source-owned paragraph explains how the study informed a practical design system for the community.</p>
      </article>
    HTML
    html = material_results_page(query, cards, count: "40", before: article)

    with_material_search(query, html) do |_page, payload, _before|
      expect(payload["contentType"]).to eq("article")
      expect(payload["publishedTime"]).to eq("2025-06-10T09:30:00Z")
      expect(payload["markdown"]).to include(
        "A field study of civic design", "first source-owned paragraph", "second source-owned paragraph"
      )
    end
  end

  it "preserves article prose when a result collection shares the main region" do
    query = "design"
    cards = (1..4).map do |index|
      material_result_card(index, "Owned collection project #{index}", "A complete linked project summary.")
    end.join
    prose = (1..3).map do |index|
      "<p>Foreign source paragraph #{index} belongs to the selected article, not neighboring query results. " \
        "It records authored information about research methods, design decisions, and practical outcomes for the community.</p>"
    end.join
    article = %(<article><header><h1>Design field notes</h1><time datetime="2025-06-10T09:30:00Z">June 10, 2025</time></header>#{prose}</article>)
    html = material_results_page(query, cards, count: "40", before: article)

    with_material_search(query, html) do |_page, payload, _before|
      expect(payload["contentType"]).to eq("article")
      (1..3).each { |index| expect(payload["markdown"]).to include("Foreign source paragraph #{index}") }
    end
  end
end
