# frozen_string_literal: true

require 'cgi'
require 'spec_helper'
require 'support/extractor_integration_helpers'

RSpec.describe 'Declared names of authored SVG images' do
  include_context 'extractor integration helpers'

  def named_svg_native_material(page, html)
    page.evaluate(<<~JS)
      (function() {
        var root = document.createElement('div');
        root.innerHTML = #{html.to_json};
        return {
          names: Array.from(root.querySelectorAll('svg[role="img"]')).map(function(svg) {
            var title = Array.from(svg.children).find(function(node) { return node.localName === 'title'; });
            return svg.getAttribute('aria-label') || (title && title.textContent) || '';
          }),
          paths: Array.from(root.querySelectorAll('svg path')).map(function(node) { return node.getAttribute('d'); }),
          programs: Array.from(root.querySelectorAll('pre code')).map(function(node) { return node.textContent; })
        };
      })()
    JS
  end

  def named_svg_reader_reparse_probe(page, mutation = nil)
    root = File.expand_path('../..', File.dirname(FetchUtil::Extractor.instance_method(:extract).source_location.first))
    source = File.readlines(File.join(root, 'websieve/manifest.txt'), chomp: true)
                 .reject { |path| path.empty? || path.start_with?('#') }
                 .map { |path| File.read(File.join(root, 'websieve', path)) }.join("\n")
    probe = <<~JS
      window.__readerSvgReparseProof = function(mutation) {
        var clone = safeReadableDocumentClone();
        var sourceClones = new Map();
        pruneHiddenClone(document.documentElement, clone.documentElement, null, null, null, sourceClones);
        var marker = markReadabilityExcerptSources(clone);
        markReadabilitySourceNodeProvenance(clone, sourceClones, marker);
        var reader = new Readability(clone);
        preserveReadabilityOwnedNamedSvgBlocks(reader, clone, sourceClones, marker);
        reader._cleanConditionally(clone.body, 'div');
        var originalNames = Array.from(clone.querySelectorAll('svg[role="img"]')).map(function(node) {
          return node.getAttribute('aria-label');
        });
        var originalMarkup = clone.body.innerHTML;
        clone.body.innerHTML = originalMarkup;
        var sameMarkup = clone.body.innerHTML === originalMarkup;
        var image = clone.querySelector('svg[role="img"]');
        var paragraph = image.closest('p');
        var block = paragraph.parentElement;
        if (mutation === 'text') paragraph.firstChild.nodeValue = 'Altered owner ';
        if (mutation === 'duplicate') block.after(block.cloneNode(true));
        if (mutation === 'foreign') paragraph.setAttribute('data-fetchutil-reader-source-paragraph', 'foreign:0');
        if (mutation === 'path') image.querySelector('path').setAttribute('d', 'M 0 0 L 99 99');
        reader._cleanConditionally(clone.body, 'div');
        var html = clone.body.innerHTML;
        return { html: html, markdown: markdownFor(html), originalNames: originalNames, sameMarkup: sameMarkup };
      };
    JS
    raise 'extractor closure boundary changed' unless source.scan('})(window);').size == 1

    page.add_script_tag(content: source.sub('})(window);', "#{probe}\n})(window);"))
    page.evaluate("window.__readerSvgReparseProof(#{mutation.to_json})")
  end

  it 'retains each independently declared image name and its physical reference in source order' do
    html = <<~HTML
      <html><head><title>Published image names</title><meta name="generator" content="MkDocs 1.6"></head>
      <body><main class="md-main"><article class="md-content__inner md-typeset">
      <h1>Published image names</h1><p>Included with <svg xmlns="http://www.w3.org/2000/svg" role="img" aria-hidden="false" aria-label="Research Bundle"><title>Research Bundle</title><path d="M 0 0 L 10 10"></path></svg>.</p>
      <p>Choose the independent <a href="../bundle/"><svg xmlns="http://www.w3.org/2000/svg" role="img" aria-label="Research Bundle"><title>Research Bundle</title><path d="M 1 1 L 11 11"></path></svg></a> for the complete collection.</p>
      <p>Archive: <svg xmlns="http://www.w3.org/2000/svg" role="img"><title>Archive Edition</title><path d="M 2 2 L 12 12"></path></svg>.</p>
      <p>Every complete explanation remains after the three independent physical images.</p>
      </article></main></body></html>
    HTML
    with_url_page('https://docs.publication.example.test/guide/images/', html) do |page|
      before = page.evaluate('document.body.innerHTML')
      payload = extract(page)
      material = named_svg_native_material(page, payload.fetch('html'))
      expect(material.fetch('names')).to eq(['Research Bundle', 'Research Bundle', 'Archive Edition'])
      expect(material.fetch('paths')).to eq(['M 0 0 L 10 10', 'M 1 1 L 11 11', 'M 2 2 L 12 12'])
      markdown = payload.fetch('markdown')
      expect(markdown.scan('Research Bundle').length).to eq(2)
      expect(markdown.scan('Archive Edition').length).to eq(1)
      expect(markdown).to include('Included with Research Bundle',
                                  '[Research Bundle](https://docs.publication.example.test/guide/bundle/)',
                                  'Choose the independent', 'for the complete collection.',
                                  'Every complete explanation remains after the three independent physical images.')
      expect(markdown.index('Included with')).to be < markdown.index('[Research Bundle]')
      expect(markdown.index('[Research Bundle]')).to be < markdown.index('Archive Edition')
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end

  it 'uses the explicit image name while preserving visible chart text without a duplicate metadata label' do
    html = <<~HTML
      <html><head><title>Image naming precedence</title><meta name="generator" content="MkDocs 1.6"></head>
      <body><main class="md-main"><article class="md-content__inner md-typeset"><h1>Image naming precedence</h1>
      <p>Named resource: <svg xmlns="http://www.w3.org/2000/svg" role="img" aria-label="Declared resource"><title>Fallback metadata title</title><path d="M 0 0 L 20 20"></path></svg>.</p>
      <figure><svg xmlns="http://www.w3.org/2000/svg" role="img" aria-label="Chart metadata name"><title>Chart metadata title</title><text>Visible observation</text><text>Repeated value</text><text>Repeated value</text></svg><figcaption>The complete physical chart caption.</figcaption></figure>
      </article></main></body></html>
    HTML
    with_url_page('https://docs.publication.example.test/guide/precedence/', html) do |page|
      before = page.evaluate('document.body.innerHTML')
      payload = extract(page)
      expect(named_svg_native_material(page, payload.fetch('html')).fetch('names')).to eq(
        ['Declared resource', 'Chart metadata name']
      )
      markdown = payload.fetch('markdown')
      expect(markdown).to include('Declared resource', 'Visible observation', 'The complete physical chart caption.')
      expect(markdown.scan('Repeated value').length).to eq(2)
      expect(markdown).not_to include('Fallback metadata title', 'Chart metadata name', 'Chart metadata title')
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end

  it 'keeps named images in short owned reference paragraphs through generic reader cleanup' do
    program = "const edition = 'Research Bundle';\nconsole.log(edition);"
    paragraphs = [
      'The research report documents the complete observations from the public collection. ' \
      'Each physical record has an independent owner, and the publication keeps the original sequence ' \
      'so readers can compare every result with its explanation.',
      'The archive includes the supporting material needed to interpret the measurements. ' \
      'Its independent references remain attached to the published explanation, and the complete program below ' \
      'demonstrates the original procedure without changing its literal values.',
      'The final discussion describes the limits of the observations and explains which details were directly recorded. ' \
      'Readers can follow the physical reference to review the full supporting collection and return to this complete article.'
    ]
    html = <<~HTML
      <html><head><title>Public research report</title><meta property="og:type" content="article"></head>
      <body><main><section><h1>Public research report</h1><div class="report-content">
      <div><p>Included with <svg xmlns="http://www.w3.org/2000/svg" role="img" aria-label="Research Bundle"><title>Research Bundle</title><path d="M 0 0 L 10 10"></path></svg> • <a href="../bundle/">Explore collection</a>.</p></div>
      <p>#{paragraphs[0]}</p><div><p>Archived in <svg xmlns="http://www.w3.org/2000/svg" role="img" aria-label="Research Bundle"><title>Research Bundle</title><path d="M 1 1 L 11 11"></path></svg> • <a href="../archive/">Explore archive</a>.</p></div>
      <p>#{paragraphs[1]}</p><pre><code>#{CGI.escapeHTML(program)}</code></pre>
      <h2>Complete discussion</h2><p>#{paragraphs[2]} <a href="../support/">Supporting collection</a>.</p>
      </div></section></main></body></html>
    HTML
    with_url_page('https://publication.example.test/reports/research/', html) do |page|
      before = page.evaluate('document.body.innerHTML')
      payload = extract(page)
      material = named_svg_native_material(page, payload.fetch('html'))
      expect(material.fetch('names')).to eq(['Research Bundle', 'Research Bundle'])
      expect(material.fetch('paths')).to eq(['M 0 0 L 10 10', 'M 1 1 L 11 11'])
      expect(material.fetch('programs')).to eq([program])
      paragraphs.each { |paragraph| expect(payload.fetch('markdown')).to include(paragraph) }
      expect(payload.fetch('markdown')).to include(
        'Included with Research Bundle', 'Archived in Research Bundle',
        '[Explore collection](https://publication.example.test/reports/bundle/)',
        '[Explore archive](https://publication.example.test/reports/archive/)',
        '[Supporting collection](https://publication.example.test/reports/support/)'
      )
      expect(payload.fetch('markdown').scan('Research Bundle').length).to eq(3)
      reparsed = named_svg_reader_reparse_probe(page)
      expect(reparsed.fetch('originalNames')).to eq(['Research Bundle', 'Research Bundle'])
      expect(reparsed.fetch('sameMarkup')).to be(true)
      expect(named_svg_native_material(page, reparsed.fetch('html'))).to eq(material)
      paragraphs.each { |paragraph| expect(reparsed.fetch('markdown')).to include(paragraph) }
      expect(reparsed.fetch('markdown')).to include(
        '[Explore collection](https://publication.example.test/reports/bundle/)',
        '[Explore archive](https://publication.example.test/reports/archive/)',
        '[Supporting collection](https://publication.example.test/reports/support/)'
      )
      %w[text duplicate foreign path].each do |mutation|
        rejected = named_svg_reader_reparse_probe(page, mutation)
        rejected_material = named_svg_native_material(page, rejected.fetch('html'))
        expect(rejected_material.fetch('names')).to eq(['Research Bundle'])
        expect(rejected_material.fetch('paths')).to eq(['M 1 1 L 11 11'])
        expect(rejected_material.fetch('programs')).to eq([program])
      end
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end

  it 'keeps decorative, control, hidden and closed names out while conserving the whole literal program' do
    program = "const sample = '<svg role=\"img\" aria-label=\"literal program name\"></svg>';\nconsole.log(sample);"
    html = <<~HTML
      <html><head><title>Image name visibility</title><meta name="generator" content="MkDocs 1.6"></head>
      <body><main class="md-main"><article class="md-content__inner md-typeset"><h1>Image name visibility</h1>
      <p>The complete public explanation stays readable.</p>
      <svg xmlns="http://www.w3.org/2000/svg"><title>Decorative metadata only</title><path d="M 0 0 L 1 1"></path></svg>
      <button type="button"><svg xmlns="http://www.w3.org/2000/svg" role="img" aria-label="Private control name"><path d="M 1 1 L 2 2"></path></svg></button>
      <svg xmlns="http://www.w3.org/2000/svg" role="img" aria-hidden="true" aria-label="Private aria name"><path d="M 2 2 L 3 3"></path></svg>
      <svg xmlns="http://www.w3.org/2000/svg" role="img" style="display:none" aria-label="Private CSS name"><path d="M 3 3 L 4 4"></path></svg>
      <div hidden><svg xmlns="http://www.w3.org/2000/svg" role="img" aria-label="Private ancestor name"><path d="M 4 4 L 5 5"></path></svg></div>
      <details><summary>Closed image panel</summary><svg xmlns="http://www.w3.org/2000/svg" role="img" aria-label="Closed image name"><path d="M 5 5 L 6 6"></path></svg></details>
      <pre><code data-language="js">#{CGI.escapeHTML(program)}</code></pre>
      </article></main></body></html>
    HTML
    with_url_page('https://docs.publication.example.test/guide/name-visibility/', html) do |page|
      before = page.evaluate('document.body.innerHTML')
      payload = extract(page)
      expect(named_svg_native_material(page, payload.fetch('html')).fetch('programs')).to eq([program])
      expect(payload.fetch('markdown')).to include(
        'The complete public explanation stays readable.', 'Closed image panel', "```js\n#{program}\n```"
      )
      expect(payload.fetch('markdown')).not_to include(
        'Decorative metadata only', 'Private control name', 'Private aria name', 'Private CSS name',
        'Private ancestor name', 'Closed image name'
      )
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end
end
