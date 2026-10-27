# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Complete source resource material boundaries' do
  include_context 'extractor integration helpers'

  def resource_material_probe
    directory = File.expand_path('../../../websieve', __dir__)
    source = File.readlines(File.join(directory, 'manifest.txt'), chomp: true)
                 .reject { |line| line.empty? || line.start_with?('#') }
                 .map { |file| File.read(File.join(directory, file)) }.join("\n")
    source.sub('})(window);', <<~JS)
      window.resourceMaterialProbe = function(cases) {
        return withInertDomWork(function() {
          return withComposedDomRead(function() {
            var before = document.body.outerHTML;
            var values = cases.map(function(pair) {
              var previous = document.createElement('div');
              var complete = document.createElement('div');
              previous.innerHTML = pair[0];
              complete.innerHTML = pair[1];
              return sourceOwnedResourceMaterialPreserved(previous, complete);
            });
            return {values: values, sourceUnchanged: document.body.outerHTML === before};
          })({});
        })({});
      };
      })(window);
    JS
  end

  def material_results(cases)
    with_url_page('https://publication.example.test/records/', '<title>Complete records</title><main><h1>Complete records</h1></main>') do |page|
      before = page.evaluate('document.body.outerHTML')
      page.add_script_tag(content: resource_material_probe)
      result = page.evaluate("resourceMaterialProbe(#{JSON.generate(cases)})")
      expect(result.fetch('sourceUnchanged')).to be true
      expect(page.evaluate('document.body.outerHTML')).to eq(before)
      result.fetch('values')
    end
  end

  it 'accepts a complete generated paragraph only over one whole identical inline run' do
    paragraph = '<p>Complete <em>record</em> with <a href="https://resources.example.test/reference?mode=full#part">reference</a>.</p>'
    inline = '<div>Complete <em>record</em> with <a href="https://resources.example.test/reference?mode=full#part">reference</a>.</div>'
    expect(material_results([[paragraph, inline], [inline, inline]])).to eq([true, true])
  end

  it 'rejects merging, splitting, named paragraphs and partial inline runs' do
    cases = [
      ['<p>First complete record.</p><p>Second complete record.</p>', '<div>First complete record.Second complete record.</div>'],
      ['<p>First complete record.</p>', '<p>First complete</p><p>record.</p>'],
      ['<p id="authored-record">Complete record.</p>', '<div>Complete record.</div>'],
      ['<p>Complete record.</p>', '<div>Prefix Complete record.</div>']
    ]
    expect(material_results(cases)).to eq([false, false, false, false])
  end

  it 'preserves literal lines, full query fragments and independent equal destinations' do
    destination = 'https://resources.example.test/reference?mode=full#part'
    cases = [
      ["<pre><code>first_value()\n\nlast_value()</code></pre>", "<pre><code>first_value()\nlast_value()</code></pre>"],
      ["<p><a href='#{destination}'>Reference</a></p>", "<div><a href='#{destination.sub("mode=full", "mode=other")}'>Reference</a></div>"],
      ["<p><a href='#{destination}'>Same</a> <a href='#{destination}'>Same</a></p>", "<div><a href='#{destination}'>Same</a></div>"]
    ]
    expect(material_results(cases)).to eq([false, false, false])
  end
end
