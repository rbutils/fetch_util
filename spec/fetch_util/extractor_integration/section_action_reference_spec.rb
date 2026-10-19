# frozen_string_literal: true

require 'spec_helper'
require 'nokogiri'
require 'support/extractor_integration_helpers'

RSpec.describe 'Section-owned collection references' do
  include_context 'extractor integration helpers'

  it 'retains independent heading-adjacent collection references in documentation' do
    url = 'https://docs.publication.example.test/collections/'
    destination = 'https://docs.publication.example.test/records/'
    program = "View all\nShare\nCopy link"
    html = <<~HTML
      <html><head><title>Published research collections</title>
      <meta name="generator" content="MkDocs 1.6"></head><body>
      <main class="md-main"><article class="md-content__inner md-typeset">
      <h1>Published research collections</h1>
      <p>Each research collection publishes its own complete records and a reference to the full collection.</p>
      <section><div><h2>Field observations</h2><a href="/records/">View all</a></div>
      <p>The first collection records the complete sequence of independent field observations.</p>
      <ul><li>Observation one remains in its original collection.</li></ul></section>
      <section><div><h2>Laboratory observations</h2><a href="/records/"><span>View all</span></a></div>
      <p>The second collection independently publishes its full laboratory records.</p>
      <ul><li>Observation two remains in its separate collection.</li></ul></section>
      <pre><code>#{program}</code></pre>
      <p>The final explanation follows both collections and the complete literal program.</p>
      </article></main></body></html>
    HTML
    with_url_page(url, html) do |page|
      before = page.evaluate('document.body.innerHTML')
      payload = extract(page)
      document = Nokogiri::HTML5(payload.fetch('html'))
      references = document.css('a').select { |node| node['href'] == destination }
      expect(references.map { |node| node.text.strip }).to eq(['View all', 'View all'])
      expect(payload.fetch('markdown').scan("[View all](#{destination})").length).to eq(2)
      expect(document.css('pre code').map(&:text)).to eq([program])
      expect(payload.fetch('markdown')).to include("```\n#{program}\n```",
                                                   'Field observations', 'Laboratory observations',
                                                   'Observation one remains in its original collection.',
                                                   'Observation two remains in its separate collection.',
                                                   'The final explanation follows both collections')
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end

  it 'keeps each ordinary dashboard panel reference and its physical heading in source order' do
    html = <<~HTML
      <html><head><title>Published observation dashboard</title></head><body><main>
      <h1>Published observation dashboard</h1>
      <p>This dashboard publishes independent collections with their complete measurements and destinations.</p>
      <section><div><h3>Recent field observations</h3><a href="/activities">View all</a></div>
      <table><tr><th>Observation</th><th>Value</th></tr><tr><td>First observation</td><td>17</td></tr></table></section>
      <section><div><h3>Recent laboratory observations</h3><a href="/activities">View all</a></div>
      <ul><li>Second observation contains the complete independent laboratory measurement.</li></ul></section>
      <section><div><h3>Published milestones</h3><a href="/milestones">View all</a></div>
      <p>The milestone record publishes the original complete result for the research collection.</p></section>
      <p>All three collection destinations remain available after the dashboard measurements.</p>
      </main></body></html>
    HTML
    with_url_page('https://dashboard.publication.example.test/', html) do |page|
      before = page.evaluate('document.body.innerHTML')
      payload = extract(page)
      document = Nokogiri::HTML5(payload.fetch('html'))
      references = document.css('a').select { |node| node.text.strip == 'View all' }
      expected = %w[activities activities milestones].map { |path| "https://dashboard.publication.example.test/#{path}" }
      expect(references.map { |node| node['href'] }).to eq(expected)
      expect(payload.fetch('markdown').scan(/\[View all\]\(([^)]+)\)/).flatten).to eq(expected)
      expect(payload.fetch('markdown')).to include('Recent field observations', 'Recent laboratory observations',
                                                   'Published milestones', 'First observation', '17',
                                                   'Second observation contains the complete independent laboratory measurement.',
                                                   'The milestone record publishes the original complete result')
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end

  it 'keeps actual controls and hidden collections out of the readable document' do
    program = "View all\nShare\nCopy link"
    html = <<~HTML
      <html><head><title>Collection controls</title><meta name="generator" content="MkDocs 1.6"></head><body>
      <main class="md-main"><article class="md-content__inner md-typeset"><h1>Collection controls</h1>
      <p>The published explanation and literal program remain separate from the collection interface.</p>
      <div role="toolbar"><h2>Viewer controls</h2><a href="/toolbar-control" role="button">View all</a>
      <button>View all</button></div>
      <nav><h2>Navigation controls</h2><a href="/navigation-control">View all</a></nav>
      <div><h2>Interactive disclosure</h2><a href="#unopened" aria-controls="unopened" aria-expanded="false">View all</a></div>
      <div id="unopened" hidden><h2>Unpublished collection</h2><a href="/unpublished">View all</a></div>
      <div hidden><h2>Hidden records</h2><a href="/hidden-records">View all</a></div>
      <pre><code>#{program}</code></pre>
      <p>The complete closing explanation remains after the controls and literal program.</p>
      </article></main></body></html>
    HTML
    with_url_page('https://docs.publication.example.test/collection-controls/', html) do |page|
      before = page.evaluate('document.body.innerHTML')
      payload = extract(page)
      document = Nokogiri::HTML5(payload.fetch('html'))
      expect(document.css('button, [role="button"], [role="toolbar"], nav')).to be_empty
      expect(document.css('pre code').map(&:text)).to eq([program])
      expect(payload.fetch('markdown')).to include("```\n#{program}\n```", 'The complete closing explanation remains')
      [payload.fetch('html'), payload.fetch('markdown')].each do |content|
        expect(content).not_to include('/toolbar-control', '/navigation-control', '#unopened', '/unpublished', '/hidden-records')
      end
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end
end
