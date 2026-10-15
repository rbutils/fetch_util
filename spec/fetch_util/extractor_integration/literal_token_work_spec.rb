# frozen_string_literal: true

RSpec.describe 'Literal program token eligibility' do
  include_context 'extractor integration helpers'

  it 'retains every literal token without parsing CSS selectors for each presentation span' do
    directory = File.expand_path('../../../websieve', __dir__)
    source = File.readlines(File.join(directory, 'manifest.txt'), chomp: true)
                 .reject { |line| line.empty? || line.start_with?('#') }
                 .map { |file| File.read(File.join(directory, file)) }.join("\n")
    export = <<~JS
      window.literalTokenWork = withComposedDomRead(function() {
        var node = document.getElementById('source');
        var matches = 0;
        node.querySelectorAll('span').forEach(function(token) {
          var original = token.matches;
          token.matches = function(selector) { matches++; return original.call(this, selector); };
        });
        var copy = physicalLiteralCodeProjection(node);
        return { text: copy.textContent, source: node.textContent, matches: matches };
      }); })(window);
    JS
    tokens = (1..240).map { |number| "<span class=\"token\">complete_value_#{number};</span>\n" }.join
    with_url_page('https://publication.example.test/reference/tokens', "<pre id=\"source\">#{tokens}</pre>") do |page|
      before = page.evaluate('document.body.innerHTML')
      page.add_script_tag(content: source.sub('})(window);', export))
      result = page.evaluate('window.literalTokenWork({})')
      expect(result.fetch('text')).to eq(result.fetch('source'))
      (1..240).each { |number| expect(result.fetch('text')).to include("complete_value_#{number};") }
      expect(result.fetch('matches')).to eq(0)
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end
end
