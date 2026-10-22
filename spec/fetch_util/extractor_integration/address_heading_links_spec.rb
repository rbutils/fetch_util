# frozen_string_literal: true

require "spec_helper"
require "support/extractor_integration_helpers"

RSpec.describe "Address-wrapped heading resources" do
  include_context "extractor integration helpers"

  def address_heading_probe(html)
    root = File.expand_path("../..", File.dirname(FetchUtil::Extractor.instance_method(:extract).source_location.first))
    paths = File.readlines(File.join(root, "websieve/manifest.txt"), chomp: true).reject do |line|
      line.empty? || line.start_with?("#")
    end
    source = paths.map { |path| File.read(File.join(root, "websieve", path)) }.join("\n")
    outro = File.read(File.join(root, "websieve/99_outro.js"))
    raise "source-module probe boundary changed" unless source.scan(outro).size == 1

    source = source.sub(outro, <<~JS)
      window.__addressHeadingProbe = function() {
        var before = document.body.innerHTML;
        var layout = document.body.cloneNode(true);
        materializeMarkdownHeadingLayouts(layout);
        var markdown = markdownFor(document.body.innerHTML);
        return {layout: layout.innerHTML, markdown: markdown, unchanged: before === document.body.innerHTML};
      };
      })(window);
    JS
    with_url_page("https://publication.example.test/reports/", html) do |page|
      inject_standalone_extractor(page)
      before = page.evaluate("document.body.innerHTML")
      page.add_script_tag(content: source)
      value = page.evaluate("window.__addressHeadingProbe()")
      expect(page.evaluate("document.body.innerHTML")).to eq(before)
      expect(value.fetch("unchanged")).to be(true)
      value
    end
  end

  it "retains both physical heading destinations and the complete ordinary publication" do
    records = %w[alpha beta].zip(["Ari Reader", "Bo Editor"]).map do |label, name|
      <<~HTML
        <div><a href="/reports/#{label}"><h2><address class="author">#{name}</address></h2></a>
          <h3>Complete #{label} research report</h3>
          <p>The #{label} report preserves the complete evidence, the independent analysis, and every published methodological qualification.</p></div>
      HTML
    end.join
    html = <<~HTML
      <html><head><title>Research bulletins</title></head><body><main>
        <article><h1>Research bulletins</h1><div>
          <p>This publication presents independently authored research, complete reports, and their public methodological evidence.</p>
          <section>#{records}</section></div></article></main></body></html>
    HTML
    with_url_page("https://publication.example.test/bulletins/", html) do |page|
      inject_standalone_extractor(page)
      before = page.evaluate("document.body.innerHTML")
      payload = page.evaluate("window.FetchUtilExtract.extract({reader_mode: true})")
      expect(page.evaluate("document.body.innerHTML")).to eq(before)
      expect(payload.fetch("byline")).to eq("Ari Reader")
      expect(payload.fetch("title")).to eq("Research bulletins")
      markdown = payload.fetch("markdown")
      expect(markdown).to include("## [Ari Reader](https://publication.example.test/reports/alpha)")
      expect(markdown).to include("## [Bo Editor](https://publication.example.test/reports/beta)")
      %w[alpha beta].each do |label|
        expect(markdown).to include("### Complete #{label} research report")
        expect(markdown).to include("The #{label} report preserves the complete evidence, the independent analysis, and every published methodological qualification.")
      end
      expect(markdown.index("/reports/alpha")).to be < markdown.index("/reports/beta")
    end
  end

  it "retains every heading rank and inline emphasis, code and reference ownership" do
    html = (1..6).map do |rank|
      %(<a href="/editions/#{rank}"><h#{rank}><address data-owner="rank-#{rank}">) +
        %(<em>Complete</em> <strong>edition #{rank}</strong> <code>record_#{rank}</code></address></h#{rank}></a>)
    end.join
    result = address_heading_probe(html)
    markdown = result.fetch("markdown")
    (1..6).each do |rank|
      expect(markdown).to include("#{"#" * rank} [_Complete_ **edition #{rank}** `record_#{rank}`](https://publication.example.test/editions/#{rank})")
      expect(result.fetch("layout")).to include("data-owner=\"rank-#{rank}\"")
    end
    expect(result.fetch("layout")).not_to include("<address")
  end

  it "preserves independently repeated equal destinations and adjacent prose exactly once" do
    html = %w[first second third].map do |label|
      %(<a href="/same"><h2><address>#{label} complete record</address></h2></a><p>Independent #{label} context.</p>)
    end.join
    markdown = address_heading_probe(html).fetch("markdown")
    expect(markdown.scan("](https://publication.example.test/same)").size).to eq(3)
    %w[first second third].each do |label|
      expect(markdown.scan("## [#{label} complete record]").size).to eq(1)
      expect(markdown.scan("Independent #{label} context.").size).to eq(1)
    end
    expect(markdown.index("first complete record")).to be < markdown.index("second complete record")
    expect(markdown.index("second complete record")).to be < markdown.index("third complete record")
  end

  it "does not flatten paragraph, program, interface or semantically marked heading descendants" do
    html = <<~HTML
      <h2><address id="paragraph-owner"><p>Complete independent paragraph.</p></address></h2>
      <h2><address id="program-owner"><pre><code>result = [1, 2, 3]\nputs result.inspect</code></pre></address></h2>
      <h2><address id="interface-owner"><button>Complete action label</button></address></h2>
      <h2><address id="role-owner" role="note">Complete marked note.</address></h2>
    HTML
    layout = address_heading_probe(html).fetch("layout")
    %w[paragraph-owner program-owner interface-owner role-owner].each do |id|
      expect(layout).to include("<address id=\"#{id}\"")
    end
    expect(layout).to include("<p>Complete independent paragraph.</p>", "result = [1, 2, 3]\nputs result.inspect")
    expect(layout).to include("<button>Complete action label</button>", 'role="note"')
  end
end
