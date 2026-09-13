# frozen_string_literal: true

require 'spec_helper'
require_relative '../../support/extractor_integration_helpers'

RSpec.describe FetchUtil::Extractor do
  include_context 'extractor integration helpers'

  def project_overview(body, repository: 'https://github.com/team/toolkit')
    <<~HTML
      <html><head><title>Toolkit developer framework</title></head><body>
      <nav><a href="/docs">Documentation</a><a href="#{repository}">Source code</a></nav>
      <header><h1>Toolkit</h1><p>A small open source framework for building applications.
      Use the runtime with existing libraries and deploy the result on your own servers.</p></header>
      #{body}
      <footer>Cookie Policy and unrelated site footer</footer>
      </body></html>
    HTML
  end

  it 'keeps short explanations, commands, and resource lists in page order' do
    html = project_overview(<<~HTML)
      <section><h2>Install</h2><pre>toolkit install</pre><p>Use the package in your application.</p></section>
      <section><h2>Features</h2><p>Concurrent requests share the runtime without blocking one another.</p></section>
      <section class="promo"><h2>Hosted tooling</h2><p>Connect the runtime to the project's hosted debugger.</p></section>
      <section><h2>Resources</h2><ul><li><a href="/guide">Guide</a></li><li><a href="/examples">Examples</a></li>
      <li><a href="/modules">Modules</a></li><li><a href="/community">Community</a></li></ul></section>
    HTML
    extract_from_url('https://toolkit.example.test/', html) do |result|
      markdown = result.fetch('markdown')
      expect(result.fetch('contentType')).to eq('article')
      expect(markdown).to include('Use the runtime with existing libraries', '```', 'toolkit install', 'Concurrent requests share')
      expect(markdown).to include('/guide)', '/examples)', '/modules)', '/community)')
      expect(markdown).to include("Connect the runtime to the project's hosted debugger.")
      expect(markdown.index('## Install')).to be < markdown.index('## Features')
      expect(markdown.index('## Features')).to be < markdown.index('## Resources')
      expect(markdown).not_to include('Cookie Policy', 'Source code')
    end
  end

  it 'preserves all materialized release records alongside the project narrative' do
    releases = (1..125).map do |index|
      "<article><h2><a href='/release/#{index}'>Release #{index}</a></h2><p>Release #{index} supports the current runtime.</p></article>"
    end.join
    html = project_overview("<main><h2>Latest News</h2><div class='latest-news'>#{releases}</div></main><section hidden><p>Hidden release draft</p></section>")
    extract_from_url('https://toolkit.example.test/', html) do |result|
      expect(result.fetch('markdown').scan(%r{https://toolkit.example.test/release/(\d+)\)}).flatten).to eq((1..125).map(&:to_s))
      expect(result.fetch('markdown')).not_to include('Hidden release draft')
    end
  end

  it 'does not treat an incidental repository link on a news page as project documentation' do
    html = project_overview('<main><h2>City headlines</h2><p>Reports from the city council.</p></main>')
    html = html.gsub('Toolkit developer framework', 'City headlines')
    html = html.gsub('A small open source framework for building applications.', 'The latest local reports.')
    html = html.gsub('Use the runtime with existing libraries and deploy the result on your own servers.', 'Read the reports from our journalists.')
    extract_from_url('https://news.example.test/', html) do |result|
      expect(result.fetch('html')).not_to include('data-fetchutil-page-overview')
    end
  end

  it 'keeps deep article routes out of homepage ownership' do
    html = project_overview('<main><h2>Building a framework</h2><p>This article describes the design.</p></main>')
    extract_from_url('https://toolkit.example.test/blog/designing-a-framework', html) do |result|
      expect(result.fetch('html')).not_to include('data-fetchutil-page-overview')
    end
  end
end
