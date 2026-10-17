require 'cgi'

RSpec.describe FetchUtil::Extractor do
  include_context 'extractor integration helpers'

  it 'retains filenames and authored wrapper material around complete programs' do
    programs = ["const payload = '<literal>';\nrender(payload);", "print('complete result')\nfinish()"]
    html = <<~HTML
      <html>
        <head><title>Program resources</title><meta name="generator" content="Docusaurus v3.9.2"></head>
        <body><div id="__docusaurus"><main><article class="markdown">
          <header><h1>Program resources</h1></header>
          <p>Keep every filename, instruction and resource together with its complete program.</p>
          <div class="codeBlockContainer_example">
            <div class="codeBlockTitle_example">example.js</div>
            <p>These authored instructions belong before the first program.</p>
            <pre><code class="language-javascript">#{CGI.escapeHTML(programs.fetch(0))}</code></pre>
            <p>Download the <a href="/files/example.js">raw source file</a> after reading it.</p>
          </div>
          <div class="highlight">
            <figcaption>complete-result.py</figcaption>
            <pre><code class="language-python">#{CGI.escapeHTML(programs.fetch(1))}</code></pre>
            <p>The second wrapper also has its own complete explanation.</p>
          </div>
        </article></main></div></body>
      </html>
    HTML

    with_url_page('https://docs.publication.example.test/guide/program-resources/', html) do |page|
      before = page.evaluate('document.body.outerHTML')
      payload = extract(page)
      actual_programs = page.evaluate(<<~JS)
        (function() {
          var root = document.createElement("div");
          root.innerHTML = #{JSON.generate(payload.fetch("html"))};
          return Array.from(root.querySelectorAll("pre")).map(function(node) { return node.textContent; });
        })()
      JS

      expect(actual_programs).to eq(programs)
      expect(payload.fetch('markdown')).to include(
        'example.js',
        'complete-result.py',
        'These authored instructions belong before the first program.',
        'Download the [raw source file](https://docs.publication.example.test/files/example.js) after reading it.',
        'The second wrapper also has its own complete explanation.',
        *programs
      )
      expect(page.evaluate('document.body.outerHTML')).to eq(before)
    end
  end
end
