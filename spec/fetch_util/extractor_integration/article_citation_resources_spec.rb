# frozen_string_literal: true

RSpec.describe "FetchUtil article citation resources" do
  include_context "extractor integration helpers"

  def citation_article(metadata: true, resources: nil)
    resources ||= <<~HTML
      <a href="/articles/study.bib">Download BibTeX</a>
      <a href="/articles/study.ris">Download .RIS</a>
    HTML
    paragraphs = 6.times.map do |index|
      "<p>Research section #{index} explains the observed cellular process, experimental controls, measured outcomes, and interpretation for subsequent studies.</p>"
    end.join
    <<~HTML
      <html><head><title>Cellular process study</title>
      #{'<meta name="citation_doi" content="10.1234/example.study">' if metadata}</head><body>
      <main><article><h1>Cellular process study</h1>#{paragraphs}</article></main>
      <aside><div class="citation-downloads">#{resources}</div>
      <div class="citation-downloads" hidden>
        <a href="/articles/hidden.bib">Hidden BibTeX</a>
        <a href="/articles/hidden.ris">Hidden RIS</a>
      </div></aside>
      </body></html>
    HTML
  end

  def extract_current_citation_article(html, &block)
    with_url_page("https://journals.example/articles/study", html) do |page|
      extract_payload(page)
      root = File.expand_path("../../..", __dir__)
      source = File.readlines(File.join(root, "websieve/manifest.txt"), chomp: true).reject(&:empty?).map do |entry|
        File.read(File.join(root, "websieve", entry))
      end.join("\n")
      page.add_script_tag(content: source)
      block.call(page.evaluate("window.FetchUtilExtract.extract({reader_mode: true})"))
    end
  end

  it "preserves every visible scholarly citation export in DOM order" do
    extract_current_citation_article(citation_article) do |payload|
      expect(payload.fetch("contentType")).to eq("article")
      expect(payload.fetch("markdown")).to include(
        "[Download BibTeX](https://journals.example/articles/study.bib)",
        "[Download .RIS](https://journals.example/articles/study.ris)"
      )
      expect(payload.fetch("markdown").index("study.bib")).to be < payload.fetch("markdown").index("study.ris")
      expect(payload.fetch("markdown")).not_to include("hidden.bib", "hidden.ris")
    end
  end

  it "does not promote isolated or unsafe download actions" do
    resources = <<~HTML
      <a href="/articles/study.bib">Download BibTeX</a>
      <a href="https://fixture-user:fixture-secret@example.net/study.ris">Private RIS</a>
    HTML
    extract_current_citation_article(citation_article(resources: resources)) do |payload|
      expect(payload.fetch("markdown")).not_to include("study.bib", "fixture-secret")
    end
  end

  it "requires scholarly article metadata" do
    extract_current_citation_article(citation_article(metadata: false)) do |payload|
      expect(payload.fetch("markdown")).not_to include("study.bib", "study.ris")
    end
  end
end
