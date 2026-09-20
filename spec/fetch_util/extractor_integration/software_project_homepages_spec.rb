# frozen_string_literal: true

require 'spec_helper'
require_relative '../../support/extractor_integration_helpers'

RSpec.describe FetchUtil::Extractor do
  include_context 'extractor integration helpers'

  it 'keeps project download and documentation actions without retaining navigation or unrelated CTAs' do
    html = <<~HTML
      <html><head><title>Toolkit compiler</title></head><body><main>
        <h1>Toolkit compiler</h1>
        <p>Toolkit is an open source compiler and runtime for building reliable applications.
           Download the release and consult the documentation before starting your project.</p>
        <div class="page-header__actions"><a href="https://github.com/example/toolkit/archive/1.0.zip">Download 1.0</a>
          <a href="https://github.com/example/toolkit">View on GitHub</a></div>
        <div class="cta-buttons"><a href="/documentation/1.0/">Documentation</a><a href="/changes">Changes</a></div>
        <div class="rightsidebar"><h2>Project references</h2><ul>
          <li><a href="/quickstart">Getting started</a></li><li><a href="/language">Language reference</a></li>
          <li><a href="/api">API reference</a></li></ul></div>
        <div class="nav"><a href="/navigation-docs">Documentation menu</a></div>
        <div class="cta-ad"><a href="/subscription">Subscribe</a></div>
      </main></body></html>
    HTML

    result = extract_from_url('https://toolkit.example.test/', html) { |payload| payload }
    expect(result.fetch('markdown')).to include('https://github.com/example/toolkit/archive/1.0.zip')
    expect(result.fetch('markdown')).to include('[Documentation](https://toolkit.example.test/documentation/1.0/)')
    expect(result.fetch('markdown')).to include('[Changes](https://toolkit.example.test/changes)')
    expect(result.fetch('markdown')).to include('/quickstart', '/language', '/api')
    expect(result.fetch('markdown')).not_to include('/navigation-docs', '/subscription')
  end

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

  it 'recognizes software descriptions in plain lists and inline-only layout blocks' do
    html = <<~HTML
      <html><head><title>The toolkit projects</title></head><body>
      <div id="nav"><ul><li><a href="/install">Installation</a></li><li><a href="/tutorial">Tutorial</a></li></ul></div>
      <div>This is the common project page for the following tools.</div>
      <ul><li><a href="/compiler">Compiler</a> — a compiler for the application language.</li>
      <li><a href="/coroutines">Coroutines</a> — an extension for native concurrent execution.</li>
      <li><a href="/assembler">Assembler</a> — a dynamic assembler for code generation engines.</li></ul>
      <div>The runtime supports existing applications and works with the tools above.</div>
      </body></html>
    HTML
    extract_from_url('https://toolkit.example.test/', html) do |result|
      expect(result.fetch('html')).to include('data-fetchutil-page-overview')
      expect(result.fetch('markdown')).to include(
        'common project page', 'a compiler for the application language',
        'native concurrent execution', 'dynamic assembler', 'supports existing applications'
      )
      expect(result.fetch('markdown')).not_to include('/install)', '/tutorial)')
    end
  end

  it 'preserves owned project features introduced by a top-level heading' do
    html = project_overview(<<~HTML)
      <div class="promo"><h1>Build with the hosted tools</h1>
      <div>Use the application framework with a shared workspace.</div>
      <div><span>Connect your data</span><span>Pull data from the project database and local files.</span></div>
      <a href="https://hosted.example.test/">Open the workspace</a></div>
    HTML
    extract_from_url('https://toolkit.example.test/', html) do |result|
      expect(result.fetch('markdown')).to include(
        'Build with the hosted tools', 'Connect your data',
        'Pull data from the project database', 'https://hosted.example.test/'
      )
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

  it 'preserves locally owned release versions and notes from project footers' do
    html = project_overview(<<~HTML)
      <main><h2>Build applications</h2><p>The framework works with your existing code and deployment tools.</p></main>
      <footer><div class="footer-releasenotes">The latest release is 4.14.8, released on August 30, 2026.
        See <a href="/release-notes/">release notes</a> for details.</div>
        <p>Copyright and unrelated footer content.</p><a href="/privacy">Privacy Policy</a>
        <div hidden>Release 9.0.0 <a href="/draft-notes/">release notes</a></div></footer>
    HTML
    extract_from_url('https://toolkit.example.test/', html) do |result|
      markdown = result.fetch('markdown')
      expect(markdown).to include('4.14.8', 'August 30, 2026', '[release notes](https://toolkit.example.test/release-notes/)')
      expect(markdown.index('Build applications')).to be < markdown.index('4.14.8')
      expect(markdown).not_to include('Copyright', 'Privacy Policy', '9.0.0', '/draft-notes/')
    end
  end

  it 'does not promote bare changelog navigation or unrelated versioned footer text' do
    html = project_overview(<<~HTML)
      <footer><div>Copyright toolkit version 2.0.0 <a href="/release-notes/">Release notes</a></div>
        <p><a href="/changelog/">Changelog</a></p>
        <div>Release 3.0.0 <a href="javascript:alert(1)">Release notes</a></div>
        <div>Release 4.0.0 <a href="/releases/">Release notes</a><a href="/privacy">Privacy Policy</a></div></footer>
    HTML
    extract_from_url('https://toolkit.example.test/', html) do |result|
      expect(result.fetch('markdown')).not_to include('2.0.0', '3.0.0', '4.0.0', '/changelog/', 'Privacy Policy')
    end
  end

  it 'keeps deep article routes out of homepage ownership' do
    html = project_overview('<main><h2>Building a framework</h2><p>This article describes the design.</p></main>')
    extract_from_url('https://toolkit.example.test/blog/designing-a-framework', html) do |result|
      expect(result.fetch('html')).not_to include('data-fetchutil-page-overview')
    end
  end

  it 'preserves coherent developer-product narratives instead of reducing them to product links' do
    sections = [
      ['Desktop UI controls', 'WinForms suite', '/products/winforms', 'WPF component library', '/products/wpf'],
      ['Modern web frameworks', 'Blazor components', '/products/blazor', 'ASP.NET developer tools', '/products/aspnet'],
      ['Reporting and analytics', 'Reporting SDK', '/products/reporting', 'Dashboard platform', '/products/dashboard']
    ].each_with_index.map do |(heading, first_label, first_path, second_label, second_path), index|
      owner_class = %w[control-group component_group ControlGroup].fetch(index)
      <<~HTML
        <section class="#{owner_class}"><h2>#{heading}</h2>
        <p>Build reliable software for demanding business applications with a complete set of developer components.
        The integrated tools share one platform, support production deployment, and include detailed product capabilities.</p>
        <a href="#{first_path}"><svg><style>.icon_blue{fill:#26A4DD;}</style></svg><span>#{first_label}</span></a>
        <a href="#{second_path}">#{second_label}</a></section>
      HTML
    end.join
    bulk_links = (1..125).map { |index| "<a href='/products/api/#{index}'>Developer API #{index}</a>" }.join
    bulk_section = <<~HTML
      <section class="feature-overview"><h2>Developer APIs</h2>
      <p>Integrate production software with a complete set of developer APIs for automation, deployment,
      reporting, and secure application workflows across supported platforms and component libraries.</p>
      #{bulk_links}<a href="https://user:secret@acme.example.test/products/private">Private SDK</a></section>
    HTML
    html = <<~HTML
      <html><head><title>Acme UI components for .NET and JavaScript developers</title>
      <meta name="author" content="Acme Software Inc."></head><body>
      <nav>#{(1..20).map { |index| "<a href='/menu/#{index}'>Menu #{index}</a>" }.join}</nav>
      <main>#{sections}#{bulk_section}</main>
      <footer><a href="/privacy">Privacy</a></footer></body></html>
    HTML

    with_url_page('https://acme.example.test/', html) do |page|
      before = page.evaluate('document.body.innerHTML')
      result = extract_payload(page)
      markdown = result.fetch('markdown')
      expect(result.fetch('contentType')).to eq('article')
      expect(result.fetch('byline')).to eq('Acme Software Inc.')
      expect(result.fetch('html')).to include('data-fetchutil-page-overview')
      expect(markdown).to include('Desktop UI controls', 'Modern web frameworks', 'Reporting and analytics')
      expect(markdown).to include('/products/winforms)', '/products/wpf)', '/products/blazor)', '/products/aspnet)')
      expect(markdown).to include('/products/reporting)', '/products/dashboard)')
      expect(markdown.scan(%r{https://acme\.example\.test/products/api/(\d+)\)}).flatten).to eq((1..125).map(&:to_s))
      expect(markdown).not_to include('.icon_blue', '/menu/', '/privacy)', 'user:secret', '/products/private)')
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end

  it 'does not promote link-heavy developer news as a product overview' do
    stories = (1..6).map do |index|
      <<~HTML
        <section class="control-group"><h2>Developer resources #{index}</h2>
        <p>News about software teams, product tools, component releases, and their latest work in the community.
        This editorial record describes one update rather than a coherent product capability or owned feature overview.</p>
        <a href="/news/#{index}/product">Product tool release #{index}</a>
        <a href="/blog/#{index}/component">Component update #{index}</a></section>
      HTML
    end.join
    html = "<html><head><title>Developer software news</title></head><body><main>#{stories}</main></body></html>"

    extract_from_url('https://news.example.test/', html) do |result|
      expect(result.fetch('html')).not_to include('data-fetchutil-page-overview')
    end
  end

  it 'does not promote a generic software catalog without structural section ownership' do
    sections = (1..3).map do |index|
      <<~HTML
        <section class="products control group features" data-testid="feature-overview" role="showcase"><h2>Developer platform #{index}</h2>
        <p>Build production software with integrated developer components, deployment support, and detailed tools
        for teams that maintain demanding applications across multiple environments and release cycles.</p>
        <a href="/products/#{index}/first">Component suite #{index}</a>
        <a href="/products/#{index}/second">Framework tool #{index}</a></section>
      HTML
    end.join
    html = "<html><head><title>Acme developer software component suites</title></head><body><main>#{sections}</main></body></html>"

    extract_from_url('https://acme.example.test/', html) do |result|
      expect(result.fetch('html')).not_to include('data-fetchutil-page-overview')
    end
  end

  it 'does not use hidden text to establish developer-product identity' do
    sections = (1..3).map do |index|
      <<~HTML
        <section class="feature-overview"><h2>Business service #{index}<span hidden>Developer product platform</span></h2>
        <p>Integrated operations support demanding organizations with reliable workflows, deployment assistance,
        detailed administration, and coordinated delivery across multiple environments and release cycles.
        <span style="display:none">Software developer components and product tools</span></p>
        <a href="/services/#{index}/first">Component suite #{index}</a>
        <a href="/services/#{index}/second">Framework tool #{index}</a></section>
      HTML
    end.join
    html = <<~HTML
      <html><head><title>Acme developer software products</title></head><body>
      <main>#{sections}</main></body></html>
    HTML

    extract_from_url('https://acme.example.test/', html) do |result|
      expect(result.fetch('html')).not_to include('data-fetchutil-page-overview')
    end
  end

  it 'requires one visible main with a complete same-origin product inventory' do
    section = lambda do |index, extra = ''|
      <<~HTML
        <section #{extra}><h2>Developer platform #{index}</h2>
        <p>Build production software with integrated developer components, deployment support, and detailed tools
        for teams that maintain demanding applications across multiple environments and release cycles.</p>
        <a href="/products/#{index}/first">Component suite #{index}</a>
        <a href="https://external.example.test/products/#{index}/second">Framework tool #{index}</a></section>
      HTML
    end
    html = <<~HTML
      <html><head><title>Acme developer software component suites</title></head><body>
      <main>#{section.call(1)}#{section.call(2)}#{section.call(3, "hidden")}</main>
      <main>#{section.call(4)}#{section.call(5)}#{section.call(6)}</main>
      </body></html>
    HTML

    extract_from_url('https://acme.example.test/', html) do |result|
      expect(result.fetch('html')).not_to include('data-fetchutil-page-overview')
    end
  end
end
