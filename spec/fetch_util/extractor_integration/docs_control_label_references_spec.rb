RSpec.describe FetchUtil::Extractor do
  include_context 'extractor integration helpers'

  %w[radio checkbox].each do |input_type|
    it "retains visible #{input_type} label references without revealing inactive programs" do
      choices = %w[alpha beta gamma delta]
      inputs = choices.map do |choice|
        checked = choice == 'alpha' ? ' checked' : ''
        "<input type=\"#{input_type}\" name=\"connector\" id=\"selection-#{choice}\" style=\"display:none\"#{checked}>"
      end.join
      labels = choices.map do |choice|
        fragment = choice == 'delta' ? 'selection%2Ddelta' : "selection-#{choice}"
        "<label for=\"selection-#{choice}\"><a href=\"##{fragment}\">#{choice.capitalize}</a></label>"
      end.join
      foreign_label = '<label for="foreign-resource"><a href="https://resources.example.test/catalog/">Foreign</a></label>'
      html = <<~HTML
        <html>
          <head><title>Connector choices</title><meta name="generator" content="mkdocs-1.6.1, mkdocs-material-9.7.1"></head>
          <body><main><article class="md-content__inner">
            <h1>Connector choices<a class="headerlink" href="#connector-choices">¶</a></h1>
            <p>Compare the visible connector labels while keeping inactive program bodies hidden.</p>
            <nav aria-label="On this page"><a href="#unrelated-heading">Navigation control</a></nav>
            <div class="connector-set">
              #{inputs}
              <div class="connector-labels">#{labels}#{foreign_label}</div>
              <div><pre><code>connect('alpha');
        finish();</code></pre></div>
              <div style="display:none"><pre><code>INACTIVE_PROGRAM_BETA</code></pre></div>
              <div style="display:none"><pre><code>INACTIVE_PROGRAM_GAMMA</code></pre></div>
              <div style="display:none"><pre><code>INACTIVE_PROGRAM_DELTA</code></pre></div>
              <label for="selection-alpha" style="display:none"><a href="#selection-alpha">HIDDEN_LABEL</a></label>
            </div>
            <h2 id="unrelated-heading">Complete visible instructions</h2>
            <p>The selected complete program remains readable after the label references.</p>
          </article></main></body>
        </html>
      HTML

      with_url_page('https://docs.publication.example.test/guide/connector-choices/', html) do |page|
        before = page.evaluate('document.body.outerHTML')
        payload = extract(page)
        actual = page.evaluate(<<~JS)
          (function() {
            var root = document.createElement("div");
            root.innerHTML = #{JSON.generate(payload.fetch("html"))};
            return {
              references: Array.from(root.querySelectorAll("a[href]")).map(function(link) {
                return [link.textContent, link.getAttribute("href")];
              }),
              programs: Array.from(root.querySelectorAll("pre")).map(function(node) { return node.textContent; })
            };
          })()
        JS
        expected_references = choices.map do |choice|
          fragment = choice == 'delta' ? 'selection%2Ddelta' : "selection-#{choice}"
          [choice.capitalize, "https://docs.publication.example.test/guide/connector-choices/##{fragment}"]
        end
        expected_references << ['Foreign', 'https://resources.example.test/catalog/']

        expect(actual.fetch('references')).to eq(expected_references)
        expect(actual.fetch('programs')).to eq(["connect('alpha');\nfinish();"])
        markdown = payload.fetch('markdown')
        expected_links = expected_references.map { |label, destination| "[#{label}](#{destination})" }
        expect(markdown).to include(expected_links.join(' '), "connect('alpha');\nfinish();")
        expect(markdown).not_to include('INACTIVE_PROGRAM', 'HIDDEN_LABEL', 'Navigation control', '[¶]')
        expect(page.evaluate('document.body.outerHTML')).to eq(before)
      end
    end
  end
end
