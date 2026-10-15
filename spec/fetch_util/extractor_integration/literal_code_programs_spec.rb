# frozen_string_literal: true

require 'cgi'

RSpec.describe 'FetchUtil complete literal code programs' do
  include_context 'extractor integration helpers'

  def literal_programs_probe(page, html)
    FetchUtil::Extractor.new.send(:inject_vendor_assets, page)
    directory = File.expand_path('../../../websieve', __dir__)
    source = File.readlines(File.join(directory, 'manifest.txt'), chomp: true)
                 .reject { |line| line.empty? || line.start_with?('#') }
                 .map { |file| File.read(File.join(directory, file)) }.join("\n")
    export = <<~JS
      window.literalProgramsProbe = withComposedDomRead(function(options) {
        var original = TurndownService.prototype.turndown;
        var programs = 0;
        var inputCharacters = 0;
        TurndownService.prototype.turndown = function(input) {
          input.querySelectorAll('pre').forEach(function(pre) {
            programs++;
            inputCharacters += pre.textContent.length;
          });
          return original.call(this, input);
        };
        try {
          var markdown = markdownFor(options.html, false, false, true);
          return { programs: programs, inputCharacters: inputCharacters, markdown: markdown };
        } finally { TurndownService.prototype.turndown = original; }
      });
      })(window);
    JS
    page.add_script_tag(content: source.sub('})(window);', export))
    page.evaluate("window.literalProgramsProbe(#{JSON.generate(html: html)})")
  end

  it 'retains every complete long program while avoiding discarded vendor conversion of literal bytes' do
    programs = (1..240).map do |number|
      (1..80).map { |line| "    value#{number}_#{line} = transform(source, '#{number}:#{line}')" }.join("\n")
    end
    html = programs.map do |program|
      "<pre><code class=\"language-python\">#{CGI.escapeHTML(program)}</code></pre>"
    end.join
    html = "<p>Published explanation with <a href=\"https://reference.example.test/code\">its reference</a>.</p>#{html}"
    with_url_page('https://publication.example.test/manual/code', '<html><body><p>Unchanged physical source.</p></body></html>') do |page|
      before = page.evaluate('document.body.innerHTML')
      result = literal_programs_probe(page, html)
      expect(result.fetch('programs')).to eq(240)
      expect(result.fetch('inputCharacters')).to eq(240)
      programs.each { |program| expect(result.fetch('markdown')).to include("```python\n#{program}\n```") }
      expect(result.fetch('markdown')).to include('Published explanation', 'https://reference.example.test/code')
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end

  it 'avoids source slot collisions and preserves literal fences, URIs, inline code and empty-program behavior' do
    program = "name = '`literal`'\nurl = 'https://reference.example.test/a_(b)'\n```\nnext(source);"
    html = '<p>Before <code>inline(source)</code> after.</p>' \
           '<pre data-fetch-util-literal-program="0" data-fetch-util-literal-program-owned="1">' \
           "<code class=\"language-text\">#{CGI.escapeHTML(program)}</code></pre><pre> \n </pre>" \
           '<p>Final authored explanation.</p>'
    with_url_page('https://publication.example.test/manual/code', '<html><body><p>Unchanged source.</p></body></html>') do |page|
      result = literal_programs_probe(page, html)
      expect(result.fetch('markdown')).to include(program, '`inline(source)`', 'Final authored explanation.')
      expect(result.fetch('markdown')).to include("````\n#{program}\n````")
      expect(result.fetch('markdown')).not_to include('data-fetch-util-literal-program')
    end
  end
end
