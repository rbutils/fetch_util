# frozen_string_literal: true

RSpec.describe 'FetchUtil nested inert document work' do
  include_context 'extractor integration helpers'

  it 'isolates complete nested work documents and restores outer and physical creation after exceptions' do
    directory = File.expand_path('../../../websieve', __dir__)
    source = File.readlines(File.join(directory, 'manifest.txt'), chomp: true)
                 .reject { |line| line.empty? || line.start_with?('#') }
                 .map { |file| File.read(File.join(directory, file)) }.join("\n")
    export = <<~JS
      window.inertWorkProbe = function() {
        var creation = document.createElement;
        var cloning = Node.prototype.cloneNode;
        var before = document.body.innerHTML;
        var original = document.querySelector('article');
        var result = withInertDomWork(function() {
          var outer = document.createElement('div');
          var outerCreation = document.createElement;
          var outerCloning = Node.prototype.cloneNode;
          var nested = withInertDomWork(function() {
            var root = document.createElement('div');
            var clone = original.cloneNode(true);
            root.appendChild(clone);
            return { document: root.ownerDocument, cloneDocument: clone.ownerDocument,
              html: root.innerHTML, base: root.ownerDocument.baseURI,
              language: root.ownerDocument.documentElement.lang };
          })();
          var threw = false;
          try {
            withInertDomWork(function() { throw new Error('owned nested work'); })();
          } catch (error) { threw = error.message === 'owned nested work'; }
          return { independent: nested.document !== outer.ownerDocument,
            cloneOwner: nested.document === nested.cloneDocument, html: nested.html,
            base: nested.base, language: nested.language, threw: threw,
            outerOwner: document.createElement('div').ownerDocument === outer.ownerDocument,
            outerCreation: document.createElement === outerCreation,
            outerCloning: Node.prototype.cloneNode === outerCloning };
        })();
        result.physicalCreation = document.createElement === creation;
        result.physicalCloning = Node.prototype.cloneNode === cloning;
        result.physicalOwner = document.createElement('div').ownerDocument === document;
        result.sourceUnchanged = document.body.innerHTML === before;
        return result;
      };
      })(window);
    JS
    records = (1..240).map { |number| "<p>Complete source record #{number}</p>" }.join
    html = "<html lang='es'><body><article>#{records}</article></body></html>"

    with_url_page('https://publication.example.test/manual/complete', html) do |page|
      page.add_script_tag(content: source.sub('})(window);', export))
      result = page.evaluate('inertWorkProbe()')
      %w[independent cloneOwner threw outerOwner outerCreation outerCloning physicalCreation physicalCloning physicalOwner sourceUnchanged].each do |key|
        expect(result.fetch(key)).to be true
      end
      expect(result.fetch('language')).to eq('es')
      expect(result.fetch('base')).to eq('https://publication.example.test/manual/complete')
      (1..240).each { |number| expect(result.fetch('html')).to include("Complete source record #{number}</p>") }
    end
  end
end
