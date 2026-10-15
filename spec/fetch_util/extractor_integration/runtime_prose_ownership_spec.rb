# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Runtime syntax and authored prose' do
  include_context 'extractor integration helpers'

  def runtime_prose_probe
    directory = File.expand_path('../../../websieve', __dir__)
    source = File.readlines(File.join(directory, 'manifest.txt'), chomp: true)
                 .reject { |line| line.empty? || line.start_with?('#') }
                 .map { |file| File.read(File.join(directory, file)) }.join("\n")
    source.sub('})(window);', <<~JS)
      window.runtimeProseProbe = function(values) {
        return withComposedDomRead(function() {
          var root = document.createElement('div');
          root.innerHTML = document.body.innerHTML;
          cleanupAgentRoot(root);
          return {syntax: values.map(looksLikeInlineJS), html: root.innerHTML,
            paragraphs: Array.prototype.map.call(root.querySelectorAll('p'), function(node) { return node.textContent; }),
            remainingDivs: root.querySelectorAll('div').length,
            markdown: markdownFor(root.innerHTML)};
        })({});
      };
      })(window);
    JS
  end

  it 'retains every parenthetical function explanation and conditional return statement in prose' do
    explanations = [
      'The selected function (before argument conversion) keeps every source record and its documented ordering.',
      'This result describes the function (when no other option was supplied), including the complete declaration and its values.',
      'If the input has a declared type, the routine returns true. The function may also return true if a later check succeeds (without changing that input).'
    ]
    paragraphs = (1..240).flat_map do |number|
      explanations.map { |text| "Record #{number}: #{text}" }
    end
    html = "<article><h1>Complete record semantics</h1>#{paragraphs.map { |text| "<p>#{text}</p>" }.join}</article>"
    with_url_page('https://reference.example.test/record-semantics', html) do |page|
      before = page.evaluate('document.body.innerHTML')
      page.add_script_tag(content: runtime_prose_probe)
      result = page.evaluate("runtimeProseProbe(#{JSON.generate(explanations)})")
      expect(result.fetch('syntax')).to eq([false, false, false])
      expect(result.fetch('paragraphs')).to eq(paragraphs)
      paragraphs.each { |text| expect(result.fetch('markdown')).to include(text) }
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end

  it 'still removes actual runtime statements and preserves explicitly formatted examples' do
    scripts = [
      'function () { return true; }',
      'function (value = {ready: true}) { return value; }',
      'load(); return this.value;',
      'return false && finish();',
      "document.body.classList.add('ready');",
      'if (ready) { return false; }',
      'JSON.stringify(value);'
    ]
    html = <<~HTML
      <article><h1>Documented runtime examples</h1>
      <p>The following formatted example is authored material.</p>
      <pre><code>function () { return true; }</code></pre>
      #{scripts.map { |text| "<div>#{text}</div>" }.join}
      </article>
    HTML
    with_url_page('https://reference.example.test/runtime-examples', html) do |page|
      before = page.evaluate('document.body.innerHTML')
      page.add_script_tag(content: runtime_prose_probe)
      result = page.evaluate("runtimeProseProbe(#{JSON.generate(scripts)})")
      expect(result.fetch('syntax')).to eq([true] * scripts.length)
      expect(result.fetch('remainingDivs')).to eq(0)
      expect(result.fetch('markdown')).to include('function () { return true; }')
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end
end
