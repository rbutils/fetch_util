# frozen_string_literal: true

RSpec.describe 'Docusaurus authored headings' do
  include_context 'extractor integration helpers'

  it 'retains visible article headers and sticky headings without exposing hidden material or navigation' do
    program = "const settings = { mode: \"steady\" };\nprocess(settings);"
    html = <<~HTML
      <html>
        <head>
          <title>Publication reference | Documentation</title>
          <meta name="generator" content="Docusaurus v3.9.2">
        </head>
        <body>
          <div id="__docusaurus">
            <nav><h2>Global navigation</h2><a href="/elsewhere">Elsewhere</a></nav>
            <main><article><div class="theme-doc-markdown markdown">
              <header>
                <h1>Publication reference</h1>
                <p>The article header links to the <a href="/guide">complete guide</a>.</p>
              </header>
              <div class="navbar"><h2>Navigation panel</h2><a href="/search">Search documentation</a></div>
              <h2 id="installation" class="anchor anchorWithStickyNavbar_example">Installation</h2>
              <p>Install the complete publication service, preserving every configuration value.</p>
              <h3 class="anchor anchorWithStickyNavbar_example">Containers</h3>
              <pre><code>const settings = { mode: "steady" };
      <a id="line-entry" style="display:none"></a>process(settings);</code></pre>
              <h3 class="anchor anchorWithStickyNavbar_example" style="display:none">Private hidden heading</h3>
              <div style="display:none"><pre><code>HIDDEN_DO_NOT_EXPOSE=1</code></pre></div>
              <h3 class="anchor anchorWithStickyNavbar_example">Storage</h3>
              <p>Validate the <a href="/schemas/v1.json">JSON schema</a> and return to the <a href="#line-entry">line entry</a>.</p>
              <aside><h2>Local navigation</h2><a href="/other">Other page</a></aside>
            </div></article></main>
          </div>
        </body>
      </html>
    HTML

    with_url_page('https://docs.publication.example.test/guide/installation/', html) do |page|
      before = page.evaluate('document.body.outerHTML')
      payload = extract(page)
      material = page.evaluate(<<~JS)
        (function() {
          var root = document.createElement("div");
          root.innerHTML = #{JSON.generate(payload.fetch("html"))};
          return {
            headings: Array.from(root.querySelectorAll("h1,h2,h3,h4,h5,h6")).map(function(node) {
              return [node.tagName.toLowerCase(), node.textContent];
            }),
            programs: Array.from(root.querySelectorAll("pre")).map(function(node) { return node.textContent; }),
            namedTargets: root.querySelectorAll("pre #line-entry").length,
            headerTitle: root.querySelector("header h1") && root.querySelector("header h1").textContent
          };
        })()
      JS

      expected_headings = [
        ['h1', 'Publication reference'], ['h2', 'Installation'], ['h3', 'Containers'], ['h3', 'Storage']
      ]
      expect(material.fetch('headings')).to eq(expected_headings)
      expect(material.fetch('headerTitle')).to eq('Publication reference')
      expect(material.fetch('programs')).to eq([program])
      expect(material.fetch('namedTargets')).to eq(1)
      expect(payload.fetch('markdown')).to include('# Publication reference', '## Installation', '### Containers', '### Storage')
      expect(payload.fetch('markdown')).to include(program.strip)
      expect(payload.fetch('markdown')).to include('[complete guide](https://docs.publication.example.test/guide)')
      expect(payload.fetch('markdown')).to include('[JSON schema](https://docs.publication.example.test/schemas/v1.json)')
      expect(payload.fetch('markdown')).to include('[line entry](https://docs.publication.example.test/guide/installation/#line-entry)')
      expect(payload.fetch('markdown')).not_to include(
        'Global navigation', 'Navigation panel', 'Local navigation', 'Private hidden heading', 'HIDDEN_DO_NOT_EXPOSE'
      )
      expect(payload.fetch('html')).not_to include('Private hidden heading', 'HIDDEN_DO_NOT_EXPOSE')
      expect(page.evaluate('document.body.outerHTML')).to eq(before)
    end
  end
end
