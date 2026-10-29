# frozen_string_literal: true

require 'spec_helper'
require 'cgi'
require 'nokogiri'
require 'open3'

RSpec.describe 'Complete compact image references' do
  include_context 'extractor integration helpers'

  def linked_image_reference_probe
    directory = File.expand_path('../../../websieve', __dir__)
    source = File.readlines(File.join(directory, 'manifest.txt'), chomp: true)
                 .reject { |line| line.empty? || line.start_with?('#') }
                 .map { |file| File.read(File.join(directory, file)) }.join("\n")
    source.sub('})(window);', <<~JS)
      window.linkedImageReferenceProbe = function(primaryUrl) {
        return withInertDomWork(function() {
          return withComposedDomRead(function() {
            var root = document.querySelector('.reference-root');
            var before = document.body.outerHTML;
            var link = root.matches('a[href]') ? root : root.querySelector('a[href]');
            var eligible = listLinkedImageReferenceMarkdown(link, true, root);
            var markdown = listTextWithReferences(root, false, primaryUrl);
            return {markdown: markdown, eligible: eligible, unchanged: document.body.outerHTML === before};
          })({});
        })({});
      };
      })(window);
    JS
  end

  def observe_image_reference(html, primary_url: nil)
    with_url_page('https://publication.example.test/catalogue', "<title>Reference catalogue</title>#{html}") do |page|
      before = page.evaluate('document.body.outerHTML')
      inject_standalone_extractor(page, reader_mode: true)
      page.add_script_tag(content: linked_image_reference_probe)
      result = page.evaluate("linkedImageReferenceProbe(#{primary_url.to_json})")
      parsed, error, status = Open3.capture3(
        'python', '-c',
        "import sys\nfrom markdown_it import MarkdownIt\nprint(MarkdownIt('commonmark').enable('table').render(sys.stdin.read()))",
        stdin_data: result.fetch('markdown')
      )
      raise error unless status.success?
      expect(result.fetch('unchanged')).to be(true)
      expect(page.evaluate('document.body.outerHTML')).to eq(before)
      yield result, Nokogiri::HTML5.fragment(parsed)
    end
  end

  it 'keeps the complete image and owning destination when the reference itself is the root' do
    destination = 'https://publication.example.test/volume?edition=2&view=full#contents'
    image = 'https://media.example.test/cover.jpg?size=full&theme=light#art'
    html = "<a class='reference-root' href='#{CGI.escapeHTML(destination)}'>" \
      "<img src='#{CGI.escapeHTML(image)}' alt='Cover [one] *literal*'></a>"
    [nil, destination].each do |primary|
      observe_image_reference(html, primary_url: primary) do |_result, parsed|
        expect(parsed.css('img').map { |node| [node['src'], node['alt']] }).to eq([[image, 'Cover [one] *literal*']])
        expect(parsed.css('a').map { |node| node['href'] }).to eq(primary ? [] : [destination])
      end
    end
  end

  it 'preserves independent identical images and a preceding literal exclamation mark' do
    reference = '<a href="/volume/42?view=full&amp;edition=2#cover"><img src="/covers/42.png" alt="Independent  cover"></a>'
    observe_image_reference("<main class='reference-root'>!#{reference} #{reference}</main>") do |_result, parsed|
      expect(parsed.css('img').map { |node| [node['src'], node['alt']] }).to eq(
        [['https://publication.example.test/covers/42.png', 'Independent  cover']] * 2
      )
      expect(parsed.css('a').map { |node| node['href'] }).to eq(
        ['https://publication.example.test/volume/42?view=full&edition=2#cover'] * 2
      )
      expect(parsed.text.strip).to eq('!')
    end
  end

  it 'keeps empty ALT, complete responsive candidates and sizes without selecting a candidate' do
    srcset = 'https://media.example.test/cdn/a,b.png?size=1&view=full 1x, https://media.example.test/cdn/a,b.png?size=2&view=full 2x'
    html = '<main class="reference-root"><a href="/volume/42#cover">' \
      '<img src="https://media.example.test/cdn/a,b.png?size=1&amp;view=full" alt="" ' \
      "srcset=\"#{CGI.escapeHTML(srcset)}\" sizes=\"(max-width: 40em) 100vw, 40em\"></a></main>"
    observe_image_reference(html) do |_result, parsed|
      expect(parsed.css('img').length).to eq(1)
      image = parsed.at_css('img')
      expect(image['src']).to eq('https://media.example.test/cdn/a,b.png?size=1&view=full')
      expect(image['alt']).to eq('')
      expect(image['srcset']).to eq(srcset)
      expect(image['sizes']).to eq('(max-width: 40em) 100vw, 40em')
      expect(image.ancestors('a').map { |node| node['href'] }).to eq(['https://publication.example.test/volume/42#cover'])
    end
  end

  it 'leaves ordinary authored text labels and complete query values unchanged' do
    html = '<main class="reference-root"><a href="/reference?edition=2&amp;view=full#details">A [literal] *label*</a></main>'
    observe_image_reference(html) do |result, parsed|
      expect(result.fetch('eligible')).to eq('')
      expect(parsed.css('img')).to be_empty
      expect(parsed.css('a').map { |node| [node['href'], node.text] }).to eq(
        [['https://publication.example.test/reference?edition=2&view=full#details', 'A [literal] *label*']]
      )
    end
  end

  it 'does not promote literal, interactive, hidden, closed, named or independently labelled material' do
    cases = [
      '<pre class="reference-root"><a href="/reference"><img src="/literal.png" alt="Literal"></a></pre>',
      '<nav class="reference-root"><a href="/reference"><img src="/control.png" alt="Control"></a></nav>',
      '<main class="reference-root"><a style="display:none" href="/reference"><img src="/hidden.png" alt="Hidden"></a></main>',
      '<main class="reference-root"><details><summary>Optional</summary><a href="/reference"><img src="/closed.png" alt="Closed"></a></details></main>',
      '<main class="reference-root"><a id="named-resource" href="/reference"><img src="/named.png" alt="Named"></a></main>',
      '<main class="reference-root"><a aria-label="Independent accessible declaration" href="/reference"><img src="/label.png" alt="Cover"></a></main>',
      '<main class="reference-root"><a href="javascript:void(0)"><img src="/unsafe.png" alt="Unsafe"></a></main>',
      '<main class="reference-root"><a href="https://name:secret@reference.example.test/"><img src="/private.png" alt="Private"></a></main>'
    ]
    cases.each do |html|
      observe_image_reference(html) do |result, _parsed|
        expect(result.fetch('eligible')).to eq('')
      end
    end
  end
end
