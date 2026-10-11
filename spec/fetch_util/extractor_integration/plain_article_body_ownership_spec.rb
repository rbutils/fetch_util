# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Plain article body ownership" do
  include_context 'extractor integration helpers'

  let(:url) { "https://publication.example.test/reports/current?ref=front" }
  let(:headline) { "Public reporting about community decisions" }
  let(:lead) { "Officials published the meeting results today, including their public comments on the evidence." }
  let(:reporting) { "The complete reporting preserves witnesses, documented findings, and linked supporting resources." }

  def extract_document(body, canonical: "https://publication.example.test/reports/current")
    with_url_page(url, <<~HTML) { |page| described_class_payload(page) }
      <html><head><title>#{headline} | Example publication</title>
        <link rel="canonical" href="#{canonical}">
        <meta property="og:type" content="article"><meta property="og:title" content="#{headline}">
        <meta property="og:url" content="#{canonical}"><meta property="article:published_time" content="2026-10-10T10:00:00Z">
        <meta name="author" content="Reporting desk">
      </head><body>#{body}</body></html>
    HTML
  end

  def described_class_payload(page)
    extractor_for(false).extract(page)
  end

  def article_body(extra: "", comments: "", controls: "")
    <<~HTML
      <div class="story_main">
        <div class="story_crumb"><a href="/">Home</a> &gt; <a href="/reports">Reports</a></div>
        <h1>#{headline}</h1><div class="story_info">2026-10-10 10:00:00 <a rel="author" href="/desk">Reporting desk</a></div>
        <div class="story_content">#{controls}<div class="story_body">
          <p>Original headline: #{headline}</p>
          <div class="media-wrapper"><video src="/recording.mp4"></video><div class="media-info"><p><a href="/video">#{headline}</a> Video desk</p></div></div>
          <p>#{lead}</p><p>#{reporting} <a href="/evidence">Evidence</a></p>
          <h2>Recorded details</h2><blockquote><p>The witness discussed comments, subscriptions and privacy services.</p></blockquote>
          <pre><code>comments = preserve_all</code></pre><table><tr><td>Full table entry</td></tr></table>
        </div><div class="story_author">Source and editor credit</div>#{comments}</div>
        #{extra}
      </div><div class="story_side"><h2>Recommendations</h2><a href="/other">Unrelated report</a></div>
    HTML
  end

  def comment_interface(reply: "")
    <<~HTML
      <div id="comment-area"><div class="editor"><form><textarea></textarea></form><button>Post</button></div>
        <p class="interface-reminder">Readers express their own views; this is the comment editor notice.</p>
        #{reply}<a class="show-all-comments" href="/all-comments">View all comments</a>
      </div>
    HTML
  end

  it "retains complete reporting, attribution and resources while selecting the reporting lead" do
    payload = extract_document(article_body(comments: comment_interface))
    expect(payload["contentType"]).to eq("article")
    expect(payload["excerpt"]).to eq(lead)
    expect(payload["html"]).to include(reporting, "Source and editor credit", "recording.mp4", "/evidence", "Full table entry", "comments = preserve_all")
    expect(payload["textContent"]).to include("subscriptions and privacy services")
    expect(payload["textContent"]).not_to include("editor notice", "Recommendations", "Unrelated report")
  end

  it "preserves published replies and portraits beside the editor notice" do
    reply = '<div class="comment-record"><img src="/reader.jpg"><p>A published reply with its own comments.</p>' \
            '<blockquote>Quoted notice stays published.</blockquote></div>'
    payload = extract_document(article_body(comments: comment_interface(reply: reply)))
    expect(payload["textContent"]).to include("A published reply", "Quoted notice stays published")
    expect(payload["html"]).to include("reader.jpg")
    expect(payload["textContent"]).not_to include("editor notice")
  end

  it "declines ambiguous, foreign and incomplete owners without discarding their actual paragraphs" do
    additional = '<div class="story_body"><p>Another complete body contains independently published material with no proved common owner.</p>' \
                 '<p>Second independent paragraph remains material.</p></div>'
    [article_body(extra: additional), article_body(extra: '<p>Outside authored reporting must survive.</p>')].each do |body|
      payload = extract_document(body)
      expect(payload["textContent"]).to include(reporting)
      expect(payload["textContent"]).to include(body.include?(additional) ? "Second independent paragraph" : "Outside authored reporting")
    end
    payload = extract_document(article_body, canonical: "https://publication.example.test/reports/foreign")
    expect(payload["textContent"]).to include(reporting)
  end

  it "retains reminder-like authored replies and ambiguous prose without a proved editor" do
    reply = '<div class="comment-record"><p class="interface-reminder">Published reminder-like reply.</p></div>'
    payload = extract_document(article_body(comments: comment_interface(reply: reply)))
    expect(payload["textContent"]).to include("Published reminder-like reply")
    payload = extract_document(article_body(comments: '<div id="comment-area"><p class="interface-reminder">An authored notice without an editor.</p></div>'))
    expect(payload["textContent"]).to include("An authored notice without an editor")
    unmarked = '<div><a href="/published-source">Published source link without a record marker</a></div>'
    payload = extract_document(article_body(comments: comment_interface(reply: unmarked)))
    expect(payload["textContent"]).to include("Published source link without a record marker")
    expect(payload["html"]).to include("/published-source")
  end

  it "recognizes exclusive sharing and comment controls while retaining an unowned link branch" do
    controls = '<div><div class="story_share"><span>Share</span><a href="javascript:;">Share action</a></div>' \
               '<div><a href="#comment-area"></a><a href="/all-comments">0</a></div></div>'
    payload = extract_document(article_body(comments: comment_interface, controls: controls))
    expect(payload["excerpt"]).to eq(lead)
    expect(payload["textContent"]).not_to include("Share action")
    ambiguous = controls.sub('</div></div>', '</div><div><a href="/analysis">Independently authored analysis</a></div></div>')
    payload = extract_document(article_body(comments: comment_interface, controls: ambiguous))
    expect(payload["textContent"]).to include("Independently authored analysis")
  end

  it "uses a reporting lead that mentions the complete headline" do
    lead_with_title = "The report titled #{headline} contains the newly published findings."
    payload = extract_document(article_body.sub(lead, lead_with_title))
    expect(payload["excerpt"]).to eq(lead_with_title)
  end

  it "preserves the original browser source and visibility" do
    body = article_body(extra: '<div hidden class="story_body"><p>Hidden reporting remains hidden.</p></div>')
    with_url_page(url, "<html><body>#{body}</body></html>") do |page|
      before = page.evaluate("document.body.outerHTML")
      payload = described_class_payload(page)
      expect(payload["textContent"]).not_to include("Hidden reporting remains hidden")
      expect(page.evaluate("document.body.outerHTML")).to eq(before)
    end
  end
end
