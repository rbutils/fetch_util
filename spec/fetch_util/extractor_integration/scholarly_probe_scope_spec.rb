# frozen_string_literal: true

RSpec.describe "FetchUtil scholarly probe scope" do
  include_context "extractor integration helpers"

  def scholarly_probe_source
    root = File.expand_path("../../..", __dir__)
    source = File.readlines(File.join(root, "websieve/manifest.txt"), chomp: true)
                 .reject { |line| line.empty? || line.start_with?("#") }
                 .map { |path| File.read(File.join(root, "websieve", path)) }.join("\n")
    source.sub("})(window);", <<~JAVASCRIPT)
      global.probeScholarlyArticle = function() {
        var calls = 0;
        fallbackContent = function() {
          calls += 1;
          return { html: document.body.innerHTML };
        };
        var result = genericScholarlyArticleContent(collectMetadata());
        return { calls: calls, type: result && result.contentType };
      };
      })(window);
    JAVASCRIPT
  end

  it "does not perform a full-page fallback on an unrelated research directory" do
    records = (0...125).map { |index| "<div><h2>Research dataset #{index}</h2><p>Public research data.</p></div>" }.join
    html = "<html><head><meta name='citation_journal_title' content='Research'></head><body>#{records}</body></html>"
    with_url_page("https://research.example/", html) do |page|
      page.add_script_tag(content: scholarly_probe_source)
      expect(page.evaluate("probeScholarlyArticle()")).to eq("calls" => 0, "type" => nil)
    end
  end

  [2, 3].each do |count|
    it "preserves scholarly extraction with #{count} recognized sections" do
      prose = "These observations describe experimental controls, reproducible measurements and the scientific results. " * 2
      sections = (1..count).map do |index|
        "<section class='section toc-section'><a data-toc='s#{index}'></a><h2>Section #{index}</h2><p>#{prose}</p></section>"
      end.join
      html = <<~HTML
        <html><head><title>Research observations</title><meta name="citation_journal_title" content="Research"></head>
        <body><div class="article-content"><div class="article-text">
        <section class="abstract toc-section"><h2>Abstract</h2><p>#{prose}</p></section>#{sections}
        </div></div></body></html>
      HTML
      with_url_page("https://research.example/paper", html) do |page|
        page.add_script_tag(content: scholarly_probe_source)
        expect(page.evaluate("probeScholarlyArticle()")).to eq("calls" => 0, "type" => "article")
      end
    end
  end

  it "rejects document-title identity without unique visible citation and section ownership" do
    prose = "These observations describe experimental controls, reproducible measurements and the scientific results. " * 2
    abstract = %(<section class="abstract toc-section"><h2>Abstract</h2><p>#{prose}</p></section>)
    sections = (1..2).map do |index|
      %(<section class="section toc-section"><a data-toc="s#{index}"></a><h2>Section #{index}</h2><p>#{prose}</p></section>)
    end.join
    citation = %(<meta name="citation_journal_title" content="Research">)
    record = %(<div class="article-text">#{abstract}#{sections}</div>)
    cases = [
      ["", record],
      [citation * 2, record],
      [citation, record * 2],
      [citation, %(<div class="article-text">#{abstract}</div>#{sections})],
      [citation, %(<div class="article-text">#{abstract}<div hidden>#{sections}</div></div>)],
      [citation, %(<div class="article-text">#{abstract}<aside>#{sections}</aside></div>)],
      [citation, "<h1>Independent research directory</h1>#{record}"]
    ]

    cases.each do |metadata, body|
      html = "<html><head><title>Research observations</title>#{metadata}</head><body>#{body}</body></html>"
      with_url_page("https://research.example/paper", html) do |page|
        page.add_script_tag(content: scholarly_probe_source)
        expect(page.evaluate("probeScholarlyArticle()")).to eq("calls" => 0, "type" => nil)
      end
    end
  end
end
