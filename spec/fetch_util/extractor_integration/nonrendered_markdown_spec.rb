# frozen_string_literal: true

require 'spec_helper'
require 'support/extractor_integration_helpers'

RSpec.describe 'Non-rendered Markdown runtime nodes' do
  include_context 'extractor integration helpers'

  def nonrendered_markdown_probe(body)
    directory = File.expand_path('../../../websieve', __dir__)
    source = File.readlines(File.join(directory, 'manifest.txt'), chomp: true)
                 .reject { |line| line.empty? || line.start_with?('#') }
                 .map { |file| File.read(File.join(directory, file)) }.join("\n")
    source.sub('})(window);', "window.nonrenderedMarkdownProbe = withComposedDomRead(function(options) { #{body} }); })(window);")
  end

  it 'omits actual runtime nodes while retaining every published record in both conversion paths' do
    records = (1..240).map do |number|
      "<p>Published explanation #{number} and <a href='/reference/#{number}'>reference #{number}</a>.</p>"
    end.join
    runtime = '<noscript><img src="https://metrics.example.test/pixel.gif" alt="RuntimeFallbackSentinel"></noscript>' \
              '<script type="application/json">{"name":"RuntimePayloadSentinel"}</script>' \
              '<style>.RuntimeStyleSentinel { display: none; }</style>' \
              '<template><p>RuntimeTemplateSentinel</p></template>'
    with_url_page('https://publication.example.test/course/reference', "<article>#{records}#{runtime}</article>") do |page|
      before = page.evaluate('document.body.innerHTML')
      FetchUtil::Extractor.new.send(:inject_vendor_assets, page)
      page.add_script_tag(content: nonrendered_markdown_probe(<<~JS))
        var html = document.querySelector('article').outerHTML;
        return {whole: markdownFor(html, false, true, true),
          units: markdownFor(html, false, true, true, turndownBlockUnits)};
      JS
      result = page.evaluate('nonrenderedMarkdownProbe({})')
      result.each_value do |markdown|
        (1..240).each do |number|
          expect(markdown).to include("Published explanation #{number}", "https://publication.example.test/reference/#{number}")
        end
        expect(markdown).not_to include('RuntimeFallbackSentinel', 'RuntimePayloadSentinel', 'RuntimeStyleSentinel',
                                        'RuntimeTemplateSentinel', 'metrics.example.test')
      end
      expect(result.fetch('whole')).to eq(result.fetch('units'))
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end

  it 'retains complete authored inline and fenced HTML examples and ordinary element-name prose' do
    program = "<noscript>\n  <img src=\"/published-diagram.svg\" alt=\"Published diagram\">\n</noscript>"
    html = '<p>A script, style, noscript, and template are HTML elements.</p>' \
           '<p>Inline example: <code>&lt;noscript&gt;published fallback&lt;/noscript&gt;</code>.</p>' \
           "<pre><code data-language='html'>#{program.gsub("&", "&amp;").gsub("<", "&lt;")}</code></pre>" \
           '<p>Keep <a href="/reference">the authored reference</a>.</p>'
    with_url_page('https://publication.example.test/course/reference', html) do |page|
      before = page.evaluate('document.body.innerHTML')
      FetchUtil::Extractor.new.send(:inject_vendor_assets, page)
      page.add_script_tag(content: nonrendered_markdown_probe('return markdownFor(document.body.innerHTML, false, true, true);'))
      markdown = page.evaluate('nonrenderedMarkdownProbe({})')
      expect(markdown).to include('A script, style, noscript, and template are HTML elements.',
                                  '`<noscript>published fallback</noscript>`',
                                  "```html\n#{program}\n```", 'https://publication.example.test/reference')
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end
end
