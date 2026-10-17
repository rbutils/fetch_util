# frozen_string_literal: true

require 'spec_helper'
require 'nokogiri'
require 'cgi'

RSpec.describe 'Named code target preservation' do
  include_context 'extractor integration helpers'

  def named_code_reference(content)
    <<~HTML
      <html><head><title>Engine Reference Manual</title></head><body>
      <article role="main"><h1>Engine Reference Manual</h1>
      <p>This complete technical manual explains every instruction and its observable effects.</p>
      <section><h2>Instruction examples</h2><p>Each complete program and its exact source line remains available.</p>
      #{content}</section><section><h2>Source references</h2>
      <p>Read the <a href="#line-603">last instruction line</a> with the complete program and all preceding instructions.</p>
      </section></article></body></html>
    HTML
  end

  it 'retains all line targets, destinations and exact program positions without adding fence markup' do
    lines = (1..603).map { |index| %(instruction_#{index}("π😀", "```literal```")) }
    marked = lines.each_with_index.map do |line, index|
      %(<a id="line-#{index + 1}" name="line-#{index + 1}" href="#line-#{index + 1}" title="Source line #{index + 1}"></a>#{CGI.escapeHTML(line)})
    end.join("\n")
    content = <<~HTML.chomp
      <pre><code class="language-python">

      <a id="program-start" name="program-start"></a>#{marked}
      <a id="program-end" name="program-end"></a>
      </code></pre>
    HTML
    base = 'https://reference.example.test/manual/'

    with_url_page(base, named_code_reference(content)) do |page|
      before = page.evaluate('document.body.innerHTML')
      payload = extract(page)
      selected = Nokogiri::HTML5.fragment(payload.fetch('html'))
      code = selected.at_css('pre code')
      expected = lines.join("\n")
      expect(code.text).to eq(expected)
      expect(code['data-language']).to eq('python')
      expect(code.css('a').map { |node| node['id'] }).to eq(['program-start'] + (1..603).map { |index| "line-#{index}" } + ['program-end'])
      (1..603).each do |index|
        anchor = code.at_css("a#line-#{index}")
        expect(%w[name href title].map { |attribute| anchor[attribute] }).to eq(["line-#{index}", "#{base}#line-#{index}", "Source line #{index}"])
        prefix = anchor.xpath('preceding-sibling::text()').map(&:text).join
        expect(prefix).to eq(index == 1 ? '' : "#{lines.take(index - 1).join("\n")}\n")
      end
      expect(payload.fetch('markdown')).to include("````python\n#{expected}\n````", "[last instruction line](#{base}#line-603)")
      expect(payload.fetch('markdown')).not_to include('<a id="line-')
      expect(extract(page)).to eq(payload)
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end

  it 'retains materialized editor targets while excluding measurements, hidden lines and copy controls' do
    lines = (1..17).map { |index| "visible_instruction_#{index}(value)" }
    editor = lines.each_with_index.map do |line, index|
      %(<pre class="CodeMirror-line"><a id="editor-#{index}" name="editor-#{index}"></a>#{line}</pre>)
    end.join
    content = <<~HTML
      <div class="CodeMirror" data-language="python">
      <div class="CodeMirror-measure"><pre><a id="measurement"></a>not a published program</pre></div>
      <div class="CodeMirror-code">#{editor}<pre class="CodeMirror-line" hidden><a id="hidden-line"></a>hidden_instruction</pre></div>
      <button class="copybutton" id="copy-control">Copy</button></div>
    HTML
    with_url_page('https://reference.example.test/manual/', named_code_reference(content)) do |page|
      before = page.evaluate('document.body.innerHTML')
      payload = extract(page)
      selected = Nokogiri::HTML5.fragment(payload.fetch('html'))
      expect(selected.css('pre').length).to eq(1)
      expect(selected.at_css('pre code').text).to eq(lines.join("\n"))
      expect(selected.css('pre a').map { |node| node['id'] }).to eq((0..16).map { |index| "editor-#{index}" })
      expect(selected.css('#measurement, #hidden-line, #copy-control')).to be_empty
      expect(payload.fetch('markdown')).not_to include('not a published program', 'hidden_instruction', 'Copy')
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end

  it 'keeps target offsets when materialized block lines supply the program newlines' do
    content = <<~HTML
      <pre data-language="javascript"><code>
      <div><a id="block-one" name="block-one"></a><span>const α = "😀";</span></div>
      <div><a id="block-two" name="block-two"></a><span>const β = α;</span></div>
      <div><a id="block-three" name="block-three"></a><span>print(β);</span></div>
      </code></pre>
    HTML
    with_url_page('https://reference.example.test/manual/', named_code_reference(content)) do |page|
      before = page.evaluate('document.body.innerHTML')
      payload = extract(page)
      selected = Nokogiri::HTML5.fragment(payload.fetch('html'))
      code = selected.at_css('pre code')
      expect(code.text).to eq("const α = \"😀\";\nconst β = α;\nprint(β);")
      expect(code.css('a').map { |node| node['id'] }).to eq(%w[block-one block-two block-three])
      expect(code.at_css('#block-two').xpath('preceding-sibling::text()').map(&:text).join).to eq("const α = \"😀\";\n")
      expect(code['data-language']).to eq('javascript')
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end

  it 'keeps a target between CR and LF at the normalized line boundary after an astral character' do
    content = '<pre data-language="javascript"><code id="source-program"></code></pre>'
    base = 'https://reference.example.test/manual/'
    with_url_page(base, named_code_reference(content)) do |page|
      page.evaluate(<<~JS)
        (() => {
          const code = document.querySelector('#source-program'), ending = String.fromCharCode(13, 10);
          code.appendChild(document.createTextNode(ending + 'first😀' + ending[0]));
          const middle = document.createElement('a');
          middle.id = 'between-endings'; middle.name = 'between-endings'; middle.href = '#between-endings';
          code.appendChild(middle);
          code.appendChild(document.createTextNode(ending[1] + 'second' + ending));
          const end = document.createElement('a'); end.id = 'final-target'; end.name = 'final-target';
          code.appendChild(end);
        })()
      JS
      before = page.evaluate('document.body.innerHTML')
      payload = extract(page)
      code = Nokogiri::HTML5.fragment(payload.fetch('html')).at_css('pre code')
      expect(code.text).to eq("first😀\nsecond")
      expect(code.at_css('#between-endings').xpath('preceding-sibling::text()').map(&:text).join).to eq("first😀\n")
      expect(code.at_css('#between-endings')['href']).to eq("#{base}#between-endings")
      expect(code.at_css('#final-target').xpath('preceding-sibling::text()').map(&:text).join).to eq("first😀\nsecond")
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end
end
