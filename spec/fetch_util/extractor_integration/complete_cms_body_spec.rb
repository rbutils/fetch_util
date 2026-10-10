# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Complete source-owned CMS article bodies' do
  include_context 'extractor integration helpers'

  let(:url) { 'https://reporting.example.test/dispatch' }
  let(:paragraphs) do
    (1..16).map do |index|
      "Reporting paragraph #{index} explains the observations and their context, preserving the independently authored details of this investigation."
    end
  end

  def document(body)
    <<~HTML
      <!doctype html><html><head>
        <title>Independent reporting</title><meta name="generator" content="WordPress">
        <meta property="og:type" content="article"><link rel="canonical" href="#{url}">
      </head><body>#{body}</body></html>
    HTML
  end

  def reporting_body
    paragraphs.each_with_index.map do |paragraph, index|
      "#{index.even? ? "<h2>Section #{index / 2 + 1}</h2>" : ""}<p>#{paragraph}</p>"
    end.join
  end

  def extract_fixture(html, fixture_url)
    with_url_page(fixture_url, html) { |page| extract(page) }
  end

  it 'selects the complete heading-owned body instead of another story description' do
    unrelated = 'Another story describes a separate investigation, its witnesses and the evidence from a different region. ' * 3
    html = document(<<~HTML)
      <aside><p class="post-description">#{unrelated}</p></aside>
      <main><article><header><h1>Independent reporting</h1></header>
        <div class="post-body">#{reporting_body}
          <p>Authored citation <a href="/evidence">source evidence</a>.</p>
          <pre><code>preserve_reporting_data()</code></pre>
        </div>
      </article></main>
    HTML
    data = extract_fixture(html, url)

    expect(data.fetch('contentType')).to eq('article')
    expect(data.fetch('title')).to eq('Independent reporting')
    paragraphs.each { |paragraph| expect(data.fetch('markdown')).to include(paragraph) }
    positions = paragraphs.map { |paragraph| data.fetch('markdown').index(paragraph) }
    expect(positions).to eq(positions.sort)
    expect(data.fetch('markdown')).to include('Section 8', 'source evidence', 'preserve_reporting_data()')
    expect(data.fetch('markdown')).not_to include(unrelated)
  end

  it 'declines hidden or recommendation-owned body lookalikes' do
    html = document(<<~HTML)
      <main><article><h1>Independent reporting</h1>
        <div class="post-body" hidden><p>Hidden article body is not materialized reporting.</p></div>
        <aside><div class="post-body"><p>Recommendation body belongs to a separate interface region.</p></div></aside>
        <div class="entry-content">#{reporting_body}</div>
      </article></main>
    HTML
    data = extract_fixture(html, url)

    paragraphs.each { |paragraph| expect(data.fetch('markdown')).to include(paragraph) }
    expect(data.fetch('markdown')).not_to include('Hidden article body', 'Recommendation body')
  end

  it 'does not choose between ambiguous body candidates under the same heading' do
    html = document(<<~HTML)
      <main><article><h1>Independent reporting</h1>
        <div class="post-body"><p>First unproved body candidate describes unrelated material.</p></div>
        <div class="post-body"><p>Second unproved body candidate describes different material.</p></div>
        <div class="entry-content">#{reporting_body}</div>
      </article></main>
    HTML
    data = extract_fixture(html, url)

    paragraphs.each { |paragraph| expect(data.fetch('markdown')).to include(paragraph) }
    expect(data.fetch('markdown')).not_to include('First unproved', 'Second unproved')
  end
end
