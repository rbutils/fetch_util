# frozen_string_literal: true

require 'spec_helper'
require 'support/extractor_integration_helpers'

RSpec.describe 'Complete Markdown output materialization' do
  include_context 'extractor integration helpers'

  def markdown_output_probe(body)
    directory = File.expand_path('../../../websieve', __dir__)
    source = File.readlines(File.join(directory, 'manifest.txt'), chomp: true)
                 .reject { |line| line.empty? || line.start_with?('#') }
                 .map { |file| File.read(File.join(directory, file)) }.join("\n")
    source.sub('})(window);', "window.markdownOutputProbe = function() { #{body} }; })(window);")
  end

  it 'copies complete unchanged prose as a span while still cleaning a final credential URL' do
    with_url_page('https://publication.example.test/reference/manual', '<p>Complete source</p>') do |page|
      page.add_script_tag(content: markdown_output_probe(<<~JS))
        var prefix = Array.from({length: 20000}, function(_, index) { return 'PublishedMaterial' + index; }).join(' ');
        var input = prefix + ' https://reader:secret@publication.example.test/reference';
        var original = MarkdownMaterializationOutput.prototype.flush;
        var copies = 0;
        MarkdownMaterializationOutput.prototype.flush = function(end) {
          if (this.input === input && end > this.copiedThrough) copies++;
          return original.call(this, end);
        };
        try { return {actual: materializedMarkdown(input), expected: prefix + ' https://publication.example.test/reference', copies: copies}; }
        finally { MarkdownMaterializationOutput.prototype.flush = original; }
      JS
      result = page.evaluate('markdownOutputProbe()')
      expect(result.fetch('actual')).to eq(result.fetch('expected'))
      expect(result.fetch('copies')).to eq(1)
    end
  end

  it 'retains every code, paragraph and reference boundary around replacements' do
    markdown = <<~'MARKDOWN'
      Published introduction keeps [literal]: /not-a-definition in its paragraph.

      [reference]: /reference "Published title"

      > Published quotation with [reference][reference].
      >
      > ```text
      > https://reader:secret@publication.example.test/literal
      > ```

      1. Published list with [safe](/safe).

          literal [unsafe](javascript:operation())

      Published inline `https://reader:secret@publication.example.test/inline` remains literal.

      [Late reference](https://reader:secret@publication.example.test/late)
    MARKDOWN
    expected = markdown.sub('[reference]: /reference', '[reference]: https://publication.example.test/reference')
                       .sub('[safe](/safe)', '[safe](https://publication.example.test/safe)')
                       .sub('[Late reference](https://reader:secret@publication.example.test/late)', 'Late reference')
    with_url_page('https://publication.example.test/reference/manual', '<p>Complete source</p>') do |page|
      page.add_script_tag(content: markdown_output_probe("return materializedMarkdown(#{JSON.generate(markdown)});"))
      expect(page.evaluate('markdownOutputProbe()')).to eq(expected)
    end
  end
end
