# frozen_string_literal: true

require 'cgi'
require 'nokogiri'
require 'spec_helper'
require 'support/extractor_integration_helpers'

RSpec.describe 'Physical identity and order of article comment threads' do
  include_context 'extractor integration helpers'

  it 'keeps the complete in-body and outside source threads once each' do
    root = File.expand_path('../..', File.dirname(FetchUtil::Extractor.instance_method(:extract).source_location.first))
    source = File.read(File.join(root, 'spec/fixtures/article_ownership_coverage/inside-and-outside-comments.html'))
    with_url_page('https://counter.example/articles/comment-boundary', source) do |page|
      before = page.evaluate('document.body.innerHTML')
      payload = extract_payload(page)
      html = Nokogiri::HTML.fragment(payload.fetch('html'))
      paragraphs = html.css('p').map(&:text)
      expect(paragraphs.count('Inside reply: the temporary ramp works for wheelchairs.')).to eq(1)
      expect(paragraphs.count('Outside reply: the ferry operator will post the accessible boarding times.')).to eq(1)
      expect(html.css('a[rel="author"]').map(&:text)).to eq(['Morgan Inside', 'Lee Outside'])
      expect(html.css('time').map(&:text)).to eq(['Posted at 10:20 UTC', 'Posted at 10:24 UTC'])
      expect(payload.fetch('markdown').index('Inside reply:')).to be < payload.fetch('markdown').index('Outside reply:')
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end

  it 'preserves independent equal-text and equal-destination threads before their physical following text' do
    observation = 'The recorded measurement remains valid for this independently published source observation.'
    program = "const reply = 'complete';  \nconsole.log(reply);\n"
    thread = lambda do |author, timestamp, code|
      <<~HTML
        <section class="comments" id="repeated-thread"><article class="comment">
        <p>#{observation} <a href="/records/evidence">Complete supporting record</a>.</p>
        #{code ? "<pre><code>#{CGI.escapeHTML(program)}</code></pre>" : ""}
        <footer class="comment-meta"><a rel="author" href="/people/shared">#{author}</a><time datetime="#{timestamp}">#{timestamp}</time></footer>
        </article></section>
      HTML
    end
    source = <<~HTML
      <!doctype html><html><head><title>Published field report</title>
      <link rel="canonical" href="https://counter.example/articles/comment-boundary">
      <meta property="og:type" content="article"><meta property="og:title" content="Published field report">
      <meta name="author" content="Field Desk"></head><body><main>
      <article class="article-record"><h1>Published field report</h1><div class="article-body">
      <p>The field team published its complete report with the original procedure and the recorded public observations.</p>
      </div></article>
      #{thread.call("First source author", "2026-09-29T10:20:00Z", true)}
      The unwrapped transition follows the first record and precedes the second.
      #{thread.call("Second source author", "2026-09-29T10:24:00Z", false)}
      <p>The closing observation follows both independent records.</p>
      <section class="comments" hidden><article class="comment"><p>Hidden reply must remain hidden.</p>
      <pre>hidden_program();</pre></article></section>
      </main></body></html>
    HTML
    with_url_page('https://counter.example/articles/comment-boundary', source) do |page|
      before = page.evaluate('document.body.innerHTML')
      payload = extract_payload(page)
      html = Nokogiri::HTML.fragment(payload.fetch('html'))
      expect(html.css('p').map(&:text).count("#{observation} Complete supporting record.")).to eq(2)
      expect(html.css('a[href="https://counter.example/records/evidence"]').map(&:text))
        .to eq(['Complete supporting record', 'Complete supporting record'])
      expect(html.css('a[rel="author"]').map(&:text)).to eq(['First source author', 'Second source author'])
      expect(html.css('time').map(&:text)).to eq(['2026-09-29T10:20:00Z', '2026-09-29T10:24:00Z'])
      expect(html.css('pre').map(&:text)).to eq([program])
      text = html.text
      expect(text.index('First source author')).to be < text.index('The unwrapped transition')
      expect(text.index('The unwrapped transition')).to be < text.index('Second source author')
      expect(text.index('Second source author')).to be < text.index('The closing observation')
      expect(payload.fetch('markdown').scan(observation).size).to eq(2)
      expect(payload.fetch('markdown')).not_to include('Hidden reply', 'hidden_program')
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end
end
