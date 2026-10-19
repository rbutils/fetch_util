# frozen_string_literal: true

require 'spec_helper'
require 'support/extractor_integration_helpers'

RSpec.describe 'Physical headings in a single media reference context' do
  include_context 'extractor integration helpers'

  def single_media_heading_html
    <<~HTML
      <html><head><title>Independent publication resources</title></head><body><main>
      <p id="introduction">The complete introduction precedes the independently owned reference.</p>
      <div id="entry" class="publication-unit">
        <div><picture><img src="/images/publication.jpg" alt="Complete physical publication image"></picture></div>
        <div><h2>Independent reference heading<br><em>Complete subtitle</em></h2>
          <p>The complete authored explanation belongs to this physical resource.</p>
          <h3>Authored support information</h3>
          <p>The complete second paragraph follows its physical third-level heading.</p>
        </div>
        <div><a id="reference" href="/reference/details"><span>Learn more</span></a></div>
        <div hidden><h2>Hidden heading</h2><pre>hidden_program();</pre></div>
      </div>
      <pre id="program">const literal = "Keep [brackets] &amp; a &gt; b";
      second_line();</pre>
      </main></body></html>
    HTML
  end

  def single_media_heading_markdown(page, sectioned: false)
    root = File.expand_path('../..', File.dirname(FetchUtil::Extractor.instance_method(:extract).source_location.first))
    paths = File.readlines(File.join(root, 'websieve/manifest.txt'), chomp: true).reject do |line|
      line.empty? || line.start_with?('#')
    end
    source = paths.map { |path| File.read(File.join(root, 'websieve', path)) }.join("\n")
    outro = File.read(File.join(root, 'websieve/99_outro.js'))
    raise 'source-module test boundary changed' unless source.scan(outro).size == 1

    source = source.sub(outro, <<~JS)
      window.__singleMediaHeadingMarkdown = function() {
        var root = visibleListClone(document.body);
        var card = root.querySelector('#entry');
        var link = root.querySelector('#reference');
        var item = {sourceNode: link, card: card, url: link.href, text: link.textContent};
        addCardContext(item, card);
        if (!#{sectioned}) return listMarkdown([item]);
        var heading = card.querySelector('h2');
        var introduction = root.querySelector('#introduction');
        var program = root.querySelector('#program');
        return sectionedListMarkdownWithDescriptions({regions: [
          {node: card, cards: [item], headingNode: heading, label: heading.textContent}
        ]}, [
          {node: introduction, markdown: markdownFor(introduction.outerHTML)},
          {node: program, markdown: markdownFor(program.outerHTML)}
        ]);
      };
      })(window);
    JS
    inject_standalone_extractor(page)
    page.add_script_tag(content: source)
    page.evaluate('window.__singleMediaHeadingMarkdown()')
  end

  it 'retains physical heading levels, inline formatting and source order around an independent reference' do
    with_url_page('https://publication.example.test/', single_media_heading_html) do |page|
      before = page.evaluate('document.body.innerHTML')
      markdown = single_media_heading_markdown(page)
      tokens = [
        '![Complete physical publication image](https://publication.example.test/images/publication.jpg)',
        '## Independent reference heading _Complete subtitle_',
        'The complete authored explanation belongs to this physical resource.',
        '### Authored support information',
        'The complete second paragraph follows its physical third-level heading.',
        '[Learn more](https://publication.example.test/reference/details)'
      ]
      positions = tokens.map { |token| markdown.index(token) }
      expect(positions).not_to include(nil)
      expect(positions).to eq(positions.sort)
      tokens.each { |token| expect(markdown.scan(token).size).to eq(1) }
      expect(markdown).not_to include('Hidden heading', 'hidden_program')
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end

  it 'keeps the complete media context once when a region separately represents its main heading' do
    with_url_page('https://publication.example.test/', single_media_heading_html) do |page|
      before = page.evaluate('document.body.innerHTML')
      markdown = single_media_heading_markdown(page, sectioned: true)
      expect(markdown).to include('### Authored support information')
      expect(markdown.scan('## Independent reference heading _Complete subtitle_').size).to eq(1)
      expect(markdown.scan('[Learn more](https://publication.example.test/reference/details)').size).to eq(1)
      expect(markdown).to include("const literal = \"Keep [brackets] & a > b\";\nsecond_line();")
      expect(markdown).to include('The complete introduction', 'The complete second paragraph')
      expect(markdown).not_to include('Hidden heading', 'hidden_program')
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end

  it 'does not turn an ordinary linked primary heading into an independently owned unlinked heading' do
    html = single_media_heading_html.sub(
      '<h2>Independent reference heading<br><em>Complete subtitle</em></h2>',
      '<h2><a id="reference" href="/reference/details">Complete primary publication</a></h2>'
    ).sub('<a id="reference" href="/reference/details"><span>Learn more</span></a>', '')
    with_url_page('https://publication.example.test/', html) do |page|
      before = page.evaluate('document.body.innerHTML')
      markdown = single_media_heading_markdown(page)
      expect(markdown.scan('[Complete primary publication](https://publication.example.test/reference/details)').size).to eq(1)
      expect(markdown).not_to include('## Complete primary publication', 'Hidden heading', 'hidden_program')
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end
end
