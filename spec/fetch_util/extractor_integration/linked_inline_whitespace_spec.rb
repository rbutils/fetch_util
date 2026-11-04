# frozen_string_literal: true

require 'cgi'
require 'nokogiri'
require 'open3'

RSpec.describe 'FetchUtil complete whitespace-owned inline program references' do
  include_context 'extractor integration helpers'

  def whitespace_program_references
    [
      ['      git://code.example.test/project.git', 'https://reference.example.test/project?edition=full&view=text#source'],
      ['https://mirror.example.test/project.git', 'https://mirror.example.test/project?edition=full#source'],
      ['      git://code.example.test/library.git', 'https://reference.example.test/library?edition=full&view=text#source'],
      ['https://mirror.example.test/library.git', 'https://mirror.example.test/library?edition=full#source']
    ]
  end

  def whitespace_program_link(literal, destination, outer: false)
    text = CGI.escapeHTML(literal)
    href = CGI.escapeHTML(destination)
    outer ? "<a href=\"#{href}\"><code>#{text}</code></a>" : "<code><a href=\"#{href}\">#{text}</a></code>"
  end

  def whitespace_program_document(content)
    prose = (1..10).map do |index|
      "<p>Complete repository explanation #{index} preserves every published command, its independent reference and all original authored context.</p>"
    end.join
    '<html><head><title>Complete repository instructions</title></head><body>' \
      '<main><article><h1>Complete repository instructions</h1>' \
      "#{prose}#{content}</article></main></body></html>"
  end

  def whitespace_program_list(outer: false, ordered: false)
    items = whitespace_program_references.each_slice(2).with_index.map do |references, index|
      links = references.map { |literal, href| whitespace_program_link(literal, href, outer: outer) }.join(', or ')
      "<li><p>Complete repository #{index + 1} has two independently published alternatives:</p><p>#{links}.</p></li>"
    end.join
    ordered ? "<ol start=\"7\">#{items}</ol>" : "<ul>#{items}</ul>"
  end

  def independently_parsed_program_markdown(markdown)
    script = "import sys; from markdown_it import MarkdownIt; print(MarkdownIt('commonmark').enable('table').render(sys.stdin.read()), end='')"
    output, error, status = Open3.capture3('python3', '-c', script, stdin_data: markdown)
    raise "independent Markdown parser failed: #{error}" unless status.success?

    Nokogiri::HTML5.fragment(output)
  end

  def observe_whitespace_programs(content)
    html = whitespace_program_document(content)
    with_url_page('https://publication.example.test/manual/repositories', html) do |page|
      before = page.evaluate('document.body.outerHTML')
      payload = FetchUtil::Extractor.new.extract(page)
      expect(page.evaluate('document.body.outerHTML')).to eq(before)
      native = Nokogiri::HTML5.fragment(payload.fetch('html'))
      parsed = independently_parsed_program_markdown(payload.fetch('markdown'))
      (1..10).each { |index| expect(parsed.text).to include("Complete repository explanation #{index}") }
      yield native, parsed, payload.fetch('markdown')
    end
  end

  def expect_complete_program_references(native, parsed)
    whitespace_program_references.each do |literal, destination|
      native_links = native.css('a[href]').select { |node| node['href'] == destination }
      expect(native_links.map(&:text)).to eq([literal])
      expect(native_links.fetch(0).ancestors.any? { |node| node.name == 'code' } || native_links.fetch(0).at_css('code')).to be_truthy

      links = parsed.css('a[href]').select { |node| node['href'] == destination }
      expect(links.length).to eq(1)
      expect(links.fetch(0).css('code').map(&:text)).to eq([literal])
    end
    expect(parsed.css('pre')).to be_empty
  end

  it 'keeps all four real destinations in loose list paragraphs without moving literal spaces outside CODE' do
    observe_whitespace_programs(whitespace_program_list) do |native, parsed, _markdown|
      expect_complete_program_references(native, parsed)
      expect(parsed.css('ul > li').length).to eq(2)
      expect(parsed.css('ul > li > p').length).to eq(4)
    end
  end

  it 'preserves the same complete literal spaces when the Source reference already owns its CODE child' do
    observe_whitespace_programs(whitespace_program_list(outer: true)) do |native, parsed, _markdown|
      expect_complete_program_references(native, parsed)
      expect(parsed.css('ul > li').length).to eq(2)
    end
  end

  it 'keeps a standalone complete linked program as a paragraph rather than an indented program block' do
    links = whitespace_program_references.map { |literal, href| whitespace_program_link(literal, href) }.join(', or ')
    observe_whitespace_programs("<p>#{links}.</p>") do |native, parsed, _markdown|
      expect_complete_program_references(native, parsed)
    end
  end

  it 'retains ordered-list starts, complete program delimiters and nested repository alternatives' do
    special = '      run([item], "_value_*")`again'
    link = whitespace_program_link(special, 'https://reference.example.test/command?full=1#literal')
    content = "<ol start=\"7\"><li><p>Read the complete command before its alternatives.</p><p>#{link}</p>" \
      "#{whitespace_program_list}</li></ol>"
    observe_whitespace_programs(content) do |native, parsed, _markdown|
      expect_complete_program_references(native, parsed)
      expect(parsed.at_css('ol')['start']).to eq('7')
      command = parsed.css('a[href]').select { |node| node['href'] == 'https://reference.example.test/command?full=1#literal' }
      expect(command.length).to eq(1)
      expect(command.fetch(0).at_css('code').text).to eq(special)
    end
  end

  it 'keeps genuine multiline indentation and independent plain inline programs byte-complete' do
    program = "      first([item])\n\n    second(\"_value_*\")"
    content = "<p>Before <code>  plain_inline()  </code> after the independently authored value.</p>" \
      "<pre><code>#{CGI.escapeHTML(program)}</code></pre>"
    observe_whitespace_programs(content) do |native, parsed, _markdown|
      expect(native.at_css('pre code').text).to eq(program)
      expect(parsed.at_css('pre code').text).to eq("#{program}\n")
      expect(parsed.css('p code').map(&:text)).to eq(['  plain_inline()  '])
      expect(parsed.text).to include('Before ', ' after the independently authored value.')
    end
  end

  it 'preserves a complete actual linked PRE program rather than treating it as an inline ownership case' do
    literal = '      before step([item]) after'
    content = '<pre><code>      before <a href="https://reference.example.test/step?full=1#literal">step([item])</a> after</code></pre>'
    observe_whitespace_programs(content) do |native, parsed, _markdown|
      expect(native.at_css('pre code').text).to eq(literal)
      program = parsed.at_css('pre code')
      expect(program.text).to eq(literal)
      expect(program.at_css('a[href]')['href']).to eq('https://reference.example.test/step?full=1#literal')
    end
  end
end
