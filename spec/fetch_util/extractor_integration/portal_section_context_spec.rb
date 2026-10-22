require "spec_helper"
require "support/extractor_integration_helpers"

RSpec.describe FetchUtil::Extractor, "physical portal section context" do
  include_context "extractor integration helpers"

  def portal_context_page(groups, before: "", between: "", summary: nil, after: "")
    cards = (1..4).map do |number|
      "<article><h2><a href='/main/#{number}'>Main editorial story number #{number}</a></h2>" \
        "<p>Independent reporting and local context for main story #{number}.</p></article>"
    end.join
    sections = groups.map do |group|
      rank = group.fetch(:rank, 2)
      links = (1..8).map do |number|
        "<a href='/#{group.fetch(:id)}/#{number}'>Independent #{group.fetch(:id)} headline number #{number}</a>"
      end.join
      "<section><h#{rank}>#{group.fetch(:heading)}</h#{rank}><p>#{group.fetch(:text)}</p>" \
        "<div class='links-box'>#{links}<div class='empty-layout-spacer'></div></div></section>"
    end.join
    declaration = summary ? "<meta name='description' content='#{summary}'>" : ""
    "<!doctype html><html><head><title>Community news</title>#{declaration}</head><body>" \
      "<main><h1>Community news</h1>#{before}#{cards}#{between}#{sections}#{after}</main></body></html>"
  end

  def portal_context_payload(html)
    with_url_page("https://portal.publication.example.test/", html) do |page|
      before = page.evaluate("document.body.innerHTML")
      payload = extract_payload(page)
      expect(page.evaluate("document.body.innerHTML")).to eq(before)
      payload
    end
  end

  def regional_context(text = "These stories cover the latest regional developments.")
    { id: "regional", heading: "Regional headlines", text: text }
  end

  it "keeps the section heading and single introduction between its own records and preceding stories" do
    payload = portal_context_payload(portal_context_page([regional_context]))
    markdown = payload.fetch("markdown")
    expect(markdown.scan("## Regional headlines").length).to eq(1)
    expect(markdown.scan(regional_context.fetch(:text)).length).to eq(1)
    expect(markdown.index("/main/4)")).to be < markdown.index("## Regional headlines")
    expect(markdown.index("## Regional headlines")).to be < markdown.index(regional_context.fetch(:text))
    expect(markdown.index(regional_context.fetch(:text))).to be < markdown.index("/regional/1)")
    (1..8).each { |number| expect(markdown.scan("https://portal.publication.example.test/regional/#{number})").length).to eq(1) }
    expect(payload.fetch("title")).to eq("Community news")
    expect(payload["byline"]).to be_nil
    expect(payload["publishedTime"]).to be_nil
  end

  it "retains independently authored equal introductions in both physical sections" do
    text = regional_context.fetch(:text)
    science = { id: "science", heading: "Science reports", text: text }
    markdown = portal_context_payload(portal_context_page([regional_context, science])).fetch("markdown")
    expect(markdown.scan(text).length).to eq(2)
    expect(markdown).to include("## Regional headlines\n\n#{text}", "## Science reports\n\n#{text}")
    expect(markdown.index("/regional/8)")).to be < markdown.index("## Science reports")
    expect(markdown.index("## Science reports")).to be < markdown.index("/science/1)")
  end

  it "keeps a real page introduction once before the main records without promoting a later section introduction" do
    intro = "Independent reporting brings together the community's current editorial coverage."
    markdown = portal_context_payload(portal_context_page([regional_context], before: "<p>#{intro}</p>")).fetch("markdown")
    expect(markdown.scan(intro).length).to eq(1)
    expect(markdown.scan(regional_context.fetch(:text)).length).to eq(1)
    expect(markdown.index(intro)).to be < markdown.index("/main/1)")
    expect(markdown.index("/main/4)")).to be < markdown.index(regional_context.fetch(:text))
  end

  it "preserves an independent contextual paragraph equal to a record description at its own source position" do
    text = "Independent reporting and local context for main story 1."
    markdown = portal_context_payload(portal_context_page([regional_context], between: "<p>#{text}</p>")).fetch("markdown")
    expect(markdown.scan(text).length).to eq(2)
    expect(markdown.index("/main/4)")).to be < markdown.rindex(text)
    expect(markdown.rindex(text)).to be < markdown.index("## Regional headlines")
  end

  it "retains the actual subordinate heading rank and inline emphasis and program roles" do
    group = { id: "research", rank: 3, heading: "Local <em>research</em> with <code>field_data</code>", text: regional_context.fetch(:text) }
    markdown = portal_context_payload(portal_context_page([group])).fetch("markdown")
    expect(markdown).to include("### Local _research_ with `field_data`")
    expect(markdown.index("/main/4)")).to be < markdown.index("### Local _research_")
    expect(markdown.index("### Local _research_")).to be < markdown.index("/research/1)")
  end

  it "does not repeat a publisher excerpt that is represented by the exact section context" do
    text = regional_context.fetch(:text)
    markdown = portal_context_payload(portal_context_page([regional_context], summary: text)).fetch("markdown")
    expect(markdown.scan(text).length).to eq(1)
    expect(markdown).to include("## Regional headlines\n\n#{text}")
    expect(markdown.index("/main/4)")).to be < markdown.index(text)
  end

  it "does not expose hidden or closed section context or promote navigation headings" do
    hidden = "<section style='display:none'><h2>Hidden regional context</h2><p>Hidden details belong to the inactive view only.</p></section>"
    closed = "<details><summary>Additional details</summary><h2>Closed regional context</h2>" \
      "<p>Closed details belong to the unopened disclosure only.</p></details>"
    navigation = "<nav><h2>Navigation tools</h2><p>Navigation instructions remain interface-owned material only.</p></nav>"
    markdown = portal_context_payload(portal_context_page([regional_context], after: hidden + closed + navigation)).fetch("markdown")
    expect(markdown).not_to include(
      "Hidden regional context", "Hidden details", "Closed regional context", "Closed details", "Navigation tools", "Navigation instructions"
    )
    expect(markdown).to include("## Regional headlines")
    expect(markdown.scan(regional_context.fetch(:text)).length).to eq(1)
  end
end
