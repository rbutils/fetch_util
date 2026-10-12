# frozen_string_literal: true

RSpec.describe 'FetchUtil bounded Markdown URL-token work' do
  include_context 'extractor integration helpers'

  def token_work_source
    root = File.expand_path('../../..', __dir__)
    paths = File.readlines(File.join(root, 'websieve/manifest.txt'), chomp: true)
                .reject { |line| line.empty? || line.start_with?('#') }
    source = paths.map { |path| File.read(File.join(root, 'websieve', path)) }.join("\n")
    source.sub('})(window);', <<~JAVASCRIPT)
      global.checkMarkdownTokenWork = function(input) {
        var original = String.prototype.slice;
        var slicedCharacters = 0;
        String.prototype.slice = function() {
          var result = original.apply(this, arguments);
          slicedCharacters += result.length;
          return result;
        };
        var output;
        try { output = materializedMarkdown(input, true); }
        finally { String.prototype.slice = original; }
        return {output: output, slicedCharacters: slicedCharacters};
      };
      })(window);
    JAVASCRIPT
  end

  def token_work_examples(markdowns)
    with_url_page('https://publication.example.test/report', '<main>Materialization probe</main>') do |page|
      page.add_script_tag(content: token_work_source)
      page.evaluate("#{JSON.generate(markdowns)}.map(checkMarkdownTokenWork)")
    end
  end

  def token_work(markdown)
    token_work_examples([markdown]).first
  end

  it 'preserves long prose without copying a document suffix for each ordinary character' do
    markdown = 'healthy human observations have high reproducibility. ' * 1_500
    shorter, longer = token_work_examples([markdown, markdown * 2])

    expect(shorter.fetch('output')).to eq(markdown)
    expect(longer.fetch('output')).to eq(markdown * 2)
    # An operation-count oracle, independent of machine speed or presentation length.
    expect(longer.fetch('slicedCharacters')).to be <= shorter.fetch('slicedCharacters') * 2.1
  end

  it 'preserves token boundaries, case and escaped literals while removing active credentials' do
    markdown = <<~'MARKDOWN'
      Bare https://reader:secret@publication.example.test/report?view=full#result
      Mixed HTTPS://reader:secret@publication.example.test/upper
      Literal \https://reader:secret@publication.example.test/escaped
      Empty https:// and http:// remain ordinary text.
      Uncredentialed https://publication.example.test/public remains intact.
      Boundary https://reader:secret@publication.example.test/a>after
    MARKDOWN
    expected = markdown.sub('https://reader:secret@publication.example.test/report', 'https://publication.example.test/report')
                       .sub('HTTPS://reader:secret@publication.example.test/upper', 'HTTPS://publication.example.test/upper')
                       .sub('https://reader:secret@publication.example.test/a>after', 'https://publication.example.test/a>after')
    expect(token_work(markdown).fetch('output')).to eq(expected)
  end

  it 'keeps complete literal code and nested labels while materializing active destinations' do
    markdown = <<~'MARKDOWN'
      `https://reader:secret@publication.example.test/inline`

      ```text
      https://reader:secret@publication.example.test/fenced
      ```

      [Report [Contact](mailto:record@example.test)](https://publication.example.test/report)
      [Private source](https://reader:secret@publication.example.test/private)
    MARKDOWN
    expected = markdown.sub('[Private source](https://reader:secret@publication.example.test/private)', 'Private source')
    expect(token_work(markdown).fetch('output')).to eq(expected)
  end
end
