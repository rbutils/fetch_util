require 'spec_helper'
require 'support/extractor_integration_helpers'
require 'cgi'
require 'nokogiri'

RSpec.describe 'Literal inline program whitespace' do
  include_context 'extractor integration helpers'

  it 'retains each complete physical inline program value in source order' do
    programs = ['command  --flag', '  padded  value  ', "left\tcenter  right"]
    html = <<~HTML
      <html><head><title>Complete command reference</title><meta name="generator" content="MkDocs 1.6"></head>
      <body><main class="md-main"><article class="md-content__inner md-typeset">
      <h1>Complete command reference</h1>
      #{programs.each_with_index.map { |value, index| "<p>Independent command #{index + 1}: <code>#{CGI.escapeHTML(value)}</code> completes the published procedure.</p>" }.join}
      <p>The independent <a href="../reference/">full reference</a> remains in the complete body.</p>
      </article></main></body></html>
    HTML
    with_url_page('https://publication.example.test/guide/commands/', html) do |page|
      before = page.evaluate('document.body.innerHTML')
      payload = extract(page)
      expect(Nokogiri::HTML5(payload.fetch('html')).css('code').map(&:text)).to eq(programs)
      markdown = payload.fetch('markdown')
      # These fixture values contain no backticks or line endings. CommonMark
      # removes one padding space only when both ends contain a space.
      parsed_programs = markdown.scan(/`([^`\n]*)`/).flatten.map do |value|
        value.start_with?(' ') && value.end_with?(' ') && value.match?(/\S/) ? value[1...-1] : value
      end
      expect(parsed_programs).to eq(programs)
      expect(markdown).to include('[full reference](https://publication.example.test/guide/reference/)')
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end

  it 'keeps ordinary prose normalization, complete block programs and captured visibility' do
    program = "first();\n  second(  value  );"
    html = <<~HTML
      <html><head><title>Complete program controls</title><meta name="generator" content="MkDocs 1.6"></head>
      <body><main class="md-main"><article class="md-content__inner md-typeset">
      <h1>Complete program controls</h1><p>Ordinary    prose stays readable.</p>
      <p hidden>Unpublished <code>hidden  command</code></p>
      <details><summary>Closed program controls</summary><p><code>closed  command</code></p></details>
      <pre><code data-language="js">#{CGI.escapeHTML(program)}</code></pre>
      </article></main></body></html>
    HTML
    with_url_page('https://publication.example.test/guide/commands/', html) do |page|
      before = page.evaluate('document.body.innerHTML')
      markdown = extract(page).fetch('markdown')
      expect(markdown).to include('Ordinary prose stays readable.', "```js\n#{program}\n```")
      expect(markdown).not_to include('hidden  command', 'closed  command')
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end
end
