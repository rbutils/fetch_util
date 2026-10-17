require 'cgi'

RSpec.describe FetchUtil::Extractor do
  include_context 'extractor integration helpers'

  {
    'Docusaurus' => 'Docusaurus v3.9.2',
    'MkDocs' => 'mkdocs-1.6.1, mkdocs-material-9.7.1'
  }.each do |engine, generator|
    it "preserves #{engine} callout resources, programs, and disclosure state" do
      program = "const payload = [1, 2, 3];\nrender('<literal>');"
      closed_program = "closed('<private>');"
      open_program = 'open({ready: true});'
      container_id = engine == 'Docusaurus' ? '__docusaurus' : 'documentation'
      html = <<~HTML
        <html>
          <head><title>Callout reference</title><meta name="generator" content="#{generator}"></head>
          <body>
            <div id="#{container_id}">
              <main><article class="markdown md-content__inner">
                <header><h1>Callout reference</h1></header>
                <p>Read the <a href="/manual/">manual</a> before comparing the examples.</p>
                <div class="admonition note" id="note-with-resources" role="note">
                  <div class="admonition-heading">Reference <a href="/manual/">manual</a></div>
                  <p>Use the complete <a href="/schema.json">schema</a> for every record.</p>
                  <pre><code>#{CGI.escapeHTML(program)}</code></pre>
                  <ul><li>Read the <a href="/guide/">guide</a> before saving.</li></ul>
                  <table><tbody><tr><th>Resource</th><td><a href="/records/">complete records</a></td></tr></tbody></table>
                  <p><img src="/diagram.svg" alt="Reference diagram"></p>
                  <div class="admonition tip">
                    <p class="admonition-title">Nested instructions</p>
                    <p>Keep the <a href="/nested/">nested reference</a> in its original position.</p>
                  </div>
                  <details class="warning" id="deferred-notes">
                    <summary>Deferred <a href="/summary/">explanation</a></summary>
                    <p>CLOSED_DO_NOT_PUBLISH <a href="/closed-body/">private example</a></p>
                    <pre><code>#{CGI.escapeHTML(closed_program)}</code></pre>
                  </details>
                  <details class="tip" id="expanded-notes" open>
                    <summary>Expanded notes</summary>
                    <p>Keep the <a href="/expanded/">expanded reference</a> visible.</p>
                    <pre><code>#{CGI.escapeHTML(open_program)}</code></pre>
                  </details>
                </div>
              </article></main>
            </div>
          </body>
        </html>
      HTML

      with_url_page('https://docs.publication.example.test/guide/callouts/', html) do |page|
        before = page.evaluate('document.body.outerHTML')
        payload = extract(page)
        material = page.evaluate(<<~JS)
          (function() {
            var root = document.createElement("div");
            root.innerHTML = #{JSON.generate(payload.fetch("html"))};
            var callout = root.querySelector("blockquote#note-with-resources");
            return {
              programs: Array.from(root.querySelectorAll("pre")).map(function(node) { return node.textContent; }),
              calloutManual: callout && callout.querySelectorAll("a[href='https://docs.publication.example.test/manual/']").length,
              allManual: root.querySelectorAll("a[href='https://docs.publication.example.test/manual/']").length,
              closed: !!root.querySelector("details#deferred-notes:not([open]) > summary"),
              expanded: !!root.querySelector("details#expanded-notes[open] > summary"),
              list: callout && callout.querySelector("li").textContent,
              table: callout && callout.querySelector("table").textContent,
              title: callout && callout.querySelector(".admonition-heading").textContent
            };
          })()
        JS

        expect(material.fetch('programs')).to eq([program, closed_program, open_program])
        expect(material.fetch('calloutManual')).to eq(1)
        expect(material.fetch('allManual')).to eq(2)
        expect(material.fetch('closed')).to be(true)
        expect(material.fetch('expanded')).to be(true)
        expect(material.fetch('list')).to eq('Read the guide before saving.')
        expect(material.fetch('table')).to eq('Resourcecomplete records')
        expect(material.fetch('title')).to eq('Reference manual')

        markdown = payload.fetch('markdown')
        expect(markdown.scan('[manual](https://docs.publication.example.test/manual/)').length).to eq(2)
        expect(markdown.gsub(/^> ?/, '')).to include(program, open_program)
        expect(markdown).to include(
          '[schema](https://docs.publication.example.test/schema.json)',
          '[guide](https://docs.publication.example.test/guide/)',
          '[complete records](https://docs.publication.example.test/records/)',
          '![Reference diagram](https://docs.publication.example.test/diagram.svg)',
          '[nested reference](https://docs.publication.example.test/nested/)',
          '[explanation](https://docs.publication.example.test/summary/)',
          '[expanded reference](https://docs.publication.example.test/expanded/)'
        )
        expect(markdown).not_to include('CLOSED_DO_NOT_PUBLISH', 'closed-body', closed_program)
        expect(page.evaluate('document.body.outerHTML')).to eq(before)
      end
    end
  end
end
