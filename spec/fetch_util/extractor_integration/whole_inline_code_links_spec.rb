# frozen_string_literal: true

require 'cgi'
require 'nokogiri'

RSpec.describe 'FetchUtil whole inline program reference ownership' do
  include_context 'extractor integration helpers'

  def linked_inline_programs
    [
      ['code', 'git://code.example.test/repository.git', 'https://reference.example.test/repository'],
      ['code', 'run([item], "_value_*")', 'https://reference.example.test/command'],
      ['tt', 'https://code.example.test/library.git', 'https://reference.example.test/library']
    ]
  end

  def linked_inline_program_html
    programs = linked_inline_programs.map do |tag, literal, destination|
      "<p>Before the published command <#{tag}><a href=\"#{destination}\">#{CGI.escapeHTML(literal)}</a></#{tag}> after its complete value.</p>"
    end.join
    explanations = (1..10).map do |number|
      "<p>Complete authored explanation #{number} preserves the command ownership and its independently published reference.</p>"
    end.join
    '<html><head><title>Published repository commands</title></head><body>' \
      '<main><article><h1>Published repository commands</h1>' \
      "#{programs}#{explanations}" \
      '<p>Keep <code>plain_inline()</code> and ' \
      '<a href="https://reference.example.test/outer"><code>outer_reference()</code></a> intact.</p>' \
      '<pre><code id="complete-program">before <a href="https://reference.example.test/step">step([item])</a> after</code></pre>' \
      '</article></main></body></html>'
  end

  def expect_linked_inline_program_material(markdown)
    linked_inline_programs.each do |_tag, literal, destination|
      expect(markdown.scan("[`#{literal}`](#{destination})").length).to eq(1)
      expect(markdown).not_to include("`[#{literal}](#{destination})`")
    end
    expect(markdown).to include('`plain_inline()`', '[`outer_reference()`](https://reference.example.test/outer)')
    expect(markdown.scan('Before the published command').length).to eq(3)
    expect(markdown.scan('after its complete value.').length).to eq(3)
    (1..10).each { |number| expect(markdown).to include("Complete authored explanation #{number}") }
    parsed = Nokogiri::HTML5.fragment(markdown)
    program = parsed.at_css('pre code')
    expect(program).not_to be_nil
    expect(program.text).to eq('before step([item]) after')
    expect(program.at_css('a[href]')['href']).to eq('https://reference.example.test/step')
  end

  def inline_program_markdown_probe(page, html)
    FetchUtil::Extractor.new.send(:inject_vendor_assets, page)
    source_root = ENV.fetch('FETCH_UTIL_BOUND_SOURCE_ROOT', File.expand_path('../../..', __dir__))
    directory = File.join(source_root, 'websieve')
    source = File.readlines(File.join(directory, 'manifest.txt'), chomp: true)
                 .reject { |line| line.empty? || line.start_with?('#') }
                 .map { |file| File.read(File.join(directory, file)) }.join("\n")
    export = <<~JS
      window.wholeInlineProgramProbe = withComposedDomRead(function(html) {
        return markdownFor(html);
      });
      })(window);
    JS
    page.add_script_tag(content: source.sub('})(window);', export))
    page.evaluate("window.wholeInlineProgramProbe(#{JSON.generate(html)})")
  end

  it 'keeps complete literal CODE and TT values outside their reference syntax in the shared converter' do
    with_url_page('https://publication.example.test/manual/repository', linked_inline_program_html) do |page|
      before = page.evaluate('document.body.innerHTML')
      markdown = inline_program_markdown_probe(page, linked_inline_program_html)
      expect_linked_inline_program_material(markdown)
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end

  it 'preserves the same literal programs, destinations and complete body through ordinary extraction' do
    with_url_page('https://publication.example.test/manual/repository', linked_inline_program_html) do |page|
      before = page.evaluate('document.body.innerHTML')
      payload = FetchUtil::Extractor.new.extract(page)
      expect_linked_inline_program_material(payload.fetch('markdown'))
      public_body = Nokogiri::HTML5.fragment(payload.fetch('html'))
      linked_inline_programs.each do |_tag, literal, destination|
        links = public_body.css('code a[href]').select { |link| link['href'] == destination }
        expect(links.map(&:text)).to eq([literal])
      end
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end
end
