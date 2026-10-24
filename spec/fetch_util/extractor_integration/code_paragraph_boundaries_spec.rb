require 'spec_helper'
require 'nokogiri'

RSpec.describe 'Physical selectable program paragraph preservation' do
  include_context 'extractor integration helpers'

  def paragraph_program_document(content)
    <<~HTML
      <html><head><title>Program Paragraph Reference</title>
      <style>.paragraph-lines > span[data-selectable-paragraph] { display: block; }</style></head><body>
      <article><h1>Program Paragraph Reference</h1>
      <p>This technical reference retains every instruction, independent program, source destination and physical paragraph boundary.</p>
      <section><h2>Complete examples</h2>#{content}</section>
      <p>Read the <a href="https://reference.example.test/manual/?view=complete#instruction-two">source instruction</a> with its exact location.</p>
      <section hidden><pre>hidden_program()</pre></section>
      <details><summary>Optional unpublished program</summary><pre>closed_program()</pre></details>
      </article></body></html>
    HTML
  end

  def with_program_paragraphs(content)
    with_url_page('https://reference.example.test/manual/', paragraph_program_document(content)) do |page|
      before = page.evaluate('document.body.innerHTML')
      result = extract(page)
      retained = Nokogiri::HTML5.fragment(result.fetch('html'))
      expect(result.fetch('title')).to eq('Program Paragraph Reference')
      expect(retained.css('h1, h2').map(&:text)).to eq(['Program Paragraph Reference', 'Complete examples'])
      expect(retained.css('a').any? do |node|
        node.text == 'source instruction' && node['href'] == 'https://reference.example.test/manual/?view=complete#instruction-two'
      end).to be(true)
      expect(result.fetch('markdown')).not_to include('hidden_program()', 'closed_program()')
      closed = retained.at_css('details:not([open])')
      expect(closed).not_to be_nil
      expect(closed.css('pre code').map(&:text)).to eq(['closed_program()'])
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
      yield result, retained, page, before
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end

  it 'retains complete paragraph boundaries together with physical BR values and literal blank lines' do
    content = <<~HTML
      <pre data-language="go"><code class="paragraph-lines"><span data-selectable-paragraph="true">type Entry struct {<br>    Name string<br>}</span><span data-selectable-paragraph="true">var entry = CreateEntry("π😀")</span><span data-selectable-paragraph="true">first_step()<br><br>last_step()</span></code></pre>
    HTML
    expected = "type Entry struct {\n    Name string\n}\nvar entry = CreateEntry(\"π😀\")\nfirst_step()\n\nlast_step()"
    with_program_paragraphs(content) do |result, retained, page, _before|
      expect(retained.css('pre code').map(&:text)).to eq([expected, 'closed_program()'])
      expect(result.fetch('markdown')).to include("```\n#{expected}\n```")
      expect(page.evaluate('document.body.innerText')).to include(expected)
    end
  end

  it 'keeps named target positions and complete HTTP bindings at the inserted paragraph boundaries' do
    content = <<~HTML
      <pre data-language="javascript"><code class="paragraph-lines"><span data-selectable-paragraph="true"><a id="instruction-one" name="instruction-one"></a>const α = "😀 ```literal```";</span><span data-selectable-paragraph="true"><a id="instruction-two" name="instruction-two" href="?view=complete#instruction-two"></a>const β = α;</span><span data-selectable-paragraph="true"><a id="instruction-three" name="instruction-three"></a>print(β);</span></code></pre>
    HTML
    lines = ['const α = "😀 ```literal```";', 'const β = α;', 'print(β);']
    with_program_paragraphs(content) do |result, retained, _page, _before|
      code = retained.at_css('pre code')
      expect(code.text).to eq(lines.join("\n"))
      expect(code.css('a').map { |node| node['id'] }).to eq(%w[instruction-one instruction-two instruction-three])
      expect(code.at_css('#instruction-two').xpath('preceding-sibling::text()').map(&:text).join).to eq("#{lines.first}\n")
      expect(code.at_css('#instruction-three').xpath('preceding-sibling::text()').map(&:text).join).to eq("#{lines.first(2).join("\n")}\n")
      expect(code.at_css('#instruction-two')['href']).to eq('https://reference.example.test/manual/?view=complete#instruction-two')
      expect(result.fetch('markdown')).to include("````javascript\n#{lines.join("\n")}\n````")
    end
  end

  it 'preserves independently repeated programs and nested syntax spans without extra line breaks' do
    program = '<pre><code class="paragraph-lines">' \
              '<span data-selectable-paragraph="true"><span class="keyword">first</span>_step()</span>' \
              '<span data-selectable-paragraph="true">second_step()</span></code></pre>'
    with_program_paragraphs("#{program}<p>The second published example is an independent occurrence.</p>#{program}") do |result, retained, _page, _before|
      expect(retained.css('pre code').map(&:text)).to eq(["first_step()\nsecond_step()", "first_step()\nsecond_step()", 'closed_program()'])
      expect(result.fetch('markdown').scan("first_step()\nsecond_step()").length).to eq(2)
      expect(retained.css('p').map(&:text)).to include('The second published example is an independent occurrence.')
    end
  end

  it 'keeps a marked span mixed with authored inline text literal' do
    with_program_paragraphs('<pre><code>prefix<span data-selectable-paragraph="true">middle</span>suffix</code></pre>') do |result, retained, _page, _before|
      expect(retained.at_css('pre code').text).to eq('prefixmiddlesuffix')
      expect(result.fetch('markdown')).to include("```\nprefixmiddlesuffix\n```")
    end
  end

  it 'does not turn ordinary adjacent syntax spans into separate program paragraphs' do
    content = '<pre><code><span class="keyword">function run() {</span><span class="value">return true;}</span></code></pre>'
    with_program_paragraphs(content) do |result, retained, _page, _before|
      expect(retained.at_css('pre code').text).to eq('function run() {return true;}')
      expect(result.fetch('markdown')).to include("```\nfunction run() {return true;}\n```")
    end
  end
end
