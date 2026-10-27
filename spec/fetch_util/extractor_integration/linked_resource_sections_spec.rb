require "open3"

RSpec.describe "Source-owned linked resource sections outside a main document" do
  include_context "extractor integration helpers"

  def resource_group(heading, resources, heading_attributes: "", group_attributes: "")
    links = resources.map do |name, destination, image|
      %(<a href="#{destination}"><img src="#{image}" alt="#{name}" width="120" height="60"></a>)
    end.join
    %(<div class="resource-heading" #{heading_attributes}><h2>#{heading}</h2></div><div class="resource-cohort" #{group_attributes}>#{links}</div>)
  end

  def resource_document(groups, intro_tag: "p")
    <<~HTML
      <!doctype html><html><head><title>Automation overview | Publication</title>
      <link rel="canonical" href="https://docs.publication.example.test/guide/automation/">
      <meta property="og:title" content="Automation overview | Publication"></head><body>
      <div class="document-page"><div class="document-layout">
      <aside><nav><a href="/guide/">Guide navigation</a></nav></aside>
      <main role="main"><div class="document-content"><h1>Automation overview</h1>
      <#{intro_tag}>This complete public overview explains how an independent automation session is created, inspected and retired while preserving every declared resource and all source-owned reference material.</#{intro_tag}>
      <p>Readers can follow each complete protocol value in the same document. The introduction belongs to the page, and it must not be replaced by an unrelated partner description or an interface label.</p>
      <h2>Stable protocol</h2><p>The literal example retains both complete lines and the independent blank program line.</p>
      <pre><code>start_value('&lt;kept&gt;')

      finish_value('&amp;complete')</code></pre>
      <p>Closing publication context remains after the complete program and before the separately owned resource sections.</p>
      </div></main></div>#{groups}</div></body></html>
    HTML
  end

  def with_resource_document(groups, intro_tag: "p")
    html = resource_document(groups, intro_tag: intro_tag)
    with_url_page("https://docs.publication.example.test/guide/automation/", html) do |page|
      before = page.evaluate("document.body.outerHTML")
      payload = extract_payload(page, reader_mode: true)
      expect(page.evaluate("document.body.outerHTML")).to eq(before)
      parsed, error, status = Open3.capture3(
        "python3", "-c", 'from markdown_it import MarkdownIt; import sys; print(MarkdownIt("commonmark").enable("table").render(sys.stdin.read()))',
        stdin_data: payload.fetch("markdown")
      )
      raise error unless status.success?
      native = Nokogiri::HTML5.fragment(payload.fetch("html"))
      markdown = Nokogiri::HTML5.fragment(parsed)
      yield native, markdown, payload
    end
  end

  def expect_document_body(native, markdown)
    [native, markdown].each do |document|
      expect(document.css("h1").map(&:text)).to include("Automation overview")
      expect(document.text).to include("Closing publication context remains after the complete program")
      values = document.css("pre").map(&:text).map { |value| value.delete_suffix("\n") }
      expect(values).to eq(["start_value('<kept>')\n\nfinish_value('&complete')"])
    end
  end

  it "retains two complete following source headings and every independently linked image" do
    first = [
      ["Alpha collective", "https://resources.example.test/alpha?edition=2#profile", "https://images.example.test/alpha.png"],
      ["Beta collective", "https://resources.example.test/beta#work", "https://images.example.test/beta.png"]
    ]
    second = [
      ["Gamma collective", "https://resources.example.test/gamma?mode=full", "https://images.example.test/gamma.png"],
      ["Delta collective", "https://resources.example.test/delta", "https://images.example.test/delta.png"],
      ["Epsilon collective", "https://resources.example.test/epsilon", "https://images.example.test/epsilon.png"]
    ]
    groups = resource_group("Implementation collaborators", first) + resource_group("Publication participants", second)
    with_resource_document(groups) do |native, markdown, payload|
      expect_document_body(native, markdown)
      [native, markdown].each do |document|
        expect(document.css("h2").map(&:text)).to eq(["Stable protocol", "Implementation collaborators", "Publication participants"])
        expect(document.css("img").map { |image| [image["alt"], image["src"]] }).to eq((first + second).map { |name, _, image| [name, image] })
        expect(document.css("a[href]").select { |link| link.at_css("img") }.map { |link| link["href"] }).to eq((first + second).map { |_, destination, _| destination })
      end
      expect(payload.fetch("title")).to eq("Automation overview | Publication")
      expect(payload.fetch("byline")).to be_nil
      expect(payload.fetch("publishedTime")).to be_nil
    end
  end

  it "preserves independent physical groups even when their complete destinations and image values repeat" do
    resources = [["Independent collective", "https://resources.example.test/shared?mode=full#profile", "https://images.example.test/shared.png"]]
    groups = resource_group("First physical cohort", resources) + resource_group("Second physical cohort", resources)
    with_resource_document(groups) do |native, markdown, _|
      expect_document_body(native, markdown)
      [native, markdown].each do |document|
        expect(document.css("h2").map(&:text)).to eq(["Stable protocol", "First physical cohort", "Second physical cohort"])
        expect(document.css("img").map { |image| image["src"] }).to eq([resources.first.last, resources.first.last])
        expect(document.css("a[href]").select { |link| link.at_css("img") }.map { |link| link["href"] }).to eq([resources.first[1], resources.first[1]])
      end
    end
  end

  it "retains the source-owned sections after a complete inline introductory block" do
    first = [["Alpha collective", "https://resources.example.test/alpha?edition=2#profile", "https://images.example.test/alpha.png"]]
    second = [["Beta collective", "https://resources.example.test/beta#work", "https://images.example.test/beta.png"]]
    groups = resource_group("Implementation collaborators", first) + resource_group("Publication participants", second)
    with_resource_document(groups, intro_tag: "div") do |native, markdown, _|
      expect_document_body(native, markdown)
      [native, markdown].each do |document|
        expect(document.css("h2").map(&:text)).to eq(["Stable protocol", "Implementation collaborators", "Publication participants"])
        expect(document.css("img").map { |image| [image["alt"], image["src"]] }).to eq((first + second).map { |name, _, image| [name, image] })
        expect(document.css("a[href]").select { |link| link.at_css("img") }.map { |link| link["href"] }).to eq((first + second).map { |_, destination, _| destination })
        expect(document.text).to include(
          "This complete public overview explains how an independent automation session is created, inspected and retired " \
          "while preserving every declared resource and all source-owned reference material."
        )
        expect(document.text).to include("Readers can follow each complete protocol value in the same document.")
      end
    end
  end

  it "does not expose source-hidden headings, source-hidden resources or closed disclosure contents" do
    hidden = resource_group(
      "Unpublished resource heading",
      [["Hidden collective", "https://resources.example.test/hidden", "https://images.example.test/hidden.png"]],
      heading_attributes: 'style="display:none"', group_attributes: "hidden"
    )
    hidden += '<details><summary>Deferred resource choices</summary><div><h2>Closed resource heading</h2></div><div>' \
              '<a href="https://resources.example.test/closed"><img src="https://images.example.test/closed.png" alt="Closed collective"></a></div></details>'
    with_resource_document(hidden) do |native, markdown, _|
      expect_document_body(native, markdown)
      expect(markdown.text).not_to include("Unpublished resource heading", "Closed resource heading", "Hidden collective", "Closed collective")
      expect(markdown.css("a[href]").map { |link| link["href"] }).not_to include("https://resources.example.test/hidden", "https://resources.example.test/closed")
    end
  end

  it "does not promote a separate navigation or form-owned image action as document resources" do
    groups = '<nav><div><h2>Unrelated navigation actions</h2></div><div><a href="https://resources.example.test/navigation">' \
             '<img src="https://images.example.test/navigation.png" alt="Navigation action"></a></div></nav>'
    groups += '<form><div><h2>Registration actions</h2></div><div><a href="https://resources.example.test/register"><button type="submit">' \
              '<img src="https://images.example.test/register.png" alt="Registration action"></button></a><input type="email"></div></form>'
    with_resource_document(groups) do |native, markdown, _|
      expect_document_body(native, markdown)
      [native, markdown].each do |document|
        expect(document.text).not_to include("Unrelated navigation actions", "Registration actions")
        expect(document.css("img").map { |image| image["src"] }).not_to include("https://images.example.test/navigation.png", "https://images.example.test/register.png")
      end
    end
  end
end
