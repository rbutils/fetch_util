# frozen_string_literal: true

require 'spec_helper'
require 'support/extractor_integration_helpers'

RSpec.describe 'Literal supporting-reference labels' do
  include_context 'extractor integration helpers'

  it 'retains every literal label character and repeated occurrence in plain card context' do
    destination = 'https://resources.example.test/_photos/sample_*set*_.jpg'
    html = <<~HTML
      <html><head><title>Independent publication</title></head><body><main>
        <article id="reference-group"><h2><a id="selected-reference" href="/selected">Selected reference</a></h2>
          <p>This complete authored paragraph owns its independent supporting references.</p>
          <figure><a href="#{destination}"><span style="display:block;width:80px;height:30px;background:#eef"></span></a></figure>
          <figure><a href="#{destination}"><span style="display:block;width:80px;height:30px;background:#efe"></span></a></figure>
          <p><a href="/named">_literal_ *resource*</a> and the complete final sentence.</p>
          <details><summary>Visible supporting label</summary><p>Closed answer stays closed.</p></details>
          <p hidden>Hidden supporting material.</p>
        </article>
      </main></body></html>
    HTML
    with_url_page('https://publication.example.test/', html) do |page|
      before = page.evaluate('document.body.innerHTML')
      root = File.expand_path('../..', File.dirname(FetchUtil::Extractor.instance_method(:extract).source_location.first))
      paths = File.readlines(File.join(root, 'websieve/manifest.txt'), chomp: true).reject do |line|
        line.empty? || line.start_with?('#')
      end
      source = paths.map { |path| File.read(File.join(root, 'websieve', path)) }.join("\n")
      outro = File.read(File.join(root, 'websieve/99_outro.js'))
      raise 'source-module test boundary changed' unless source.scan(outro).size == 1

      source = source.sub(outro, <<~JS)
        window.__literalSupportingReferences = function() {
          var card = document.querySelector('#reference-group');
          return listTextWithReferences(card, false, card.querySelector('#selected-reference').href);
        };
        })(window);
      JS
      inject_standalone_extractor(page)
      page.add_script_tag(content: source)
      markdown = page.evaluate('window.__literalSupportingReferences()')
      label = destination.gsub(/[_*]/) { |character| "\\#{character}" }
      reference = "[#{label}](#{destination})"
      expect(markdown.scan(reference).size).to eq(2)
      expect(markdown).to include('[\_literal\_ \*resource\*](https://publication.example.test/named)',
                                  'This complete authored paragraph owns its independent supporting references.',
                                  'and the complete final sentence.', 'Visible supporting label')
      expect(markdown.index(reference)).to be < markdown.index('https://publication.example.test/named')
      expect(markdown).not_to include('Hidden supporting material.', 'Closed answer stays closed.')
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end
end
