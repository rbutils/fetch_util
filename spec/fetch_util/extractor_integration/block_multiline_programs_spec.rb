# frozen_string_literal: true

require 'cgi'

RSpec.describe 'FetchUtil physically block-owned multiline code' do
  include_context 'extractor integration helpers'

  def block_program_values(markdown)
    programs = []
    fence = nil
    value = +''
    markdown.lines.each do |line|
      if fence
        if line.chomp.match?(/\A#{Regexp.escape(fence[0])}{#{fence.length},}[ \t]*\z/)
          programs << value
          fence = nil
          value = +''
        else
          value << line
        end
      elsif (opening = line.match(/\A(`{3,}|~{3,})[^\r\n]*\n\z/))
        fence = opening[1]
      end
    end
    expect(fence).to be_nil
    programs
  end

  def with_block_program(body)
    html = <<~HTML
      <!doctype html><html><head><title>Literal program guide</title></head><body>
      <main><article><h1>Literal program guide</h1>
      <p>This published guide explains the complete installation procedure and its surrounding
      context. Readers need every command in its original order, including comments, whitespace,
      literal strings and the independent destination in the closing explanation.</p>
      #{body}
      <p>The final explanation remains part of the same guide. Read the
      <a href="https://reference.example.test/manual">complete reference</a> before changing
      the configuration, and keep all original publication material together.</p>
      </article></main></body></html>
    HTML
    with_url_page('https://publication.example.test/guides/literal-programs', html) do |page|
      before = page.evaluate('document.body.innerHTML')
      payload = extract_payload(page)
      expect(payload.fetch('markdown')).to include('complete reference', 'https://reference.example.test/manual')
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
      yield payload
    end
  end

  it 'keeps a complete installation program with comments, blank lines and literal fences' do
    program = "# Download the files\ncurl -LO https://reference.example.test/setup.yml\n\n" \
              "# Keep this literal fence\nprintf '```'\n\n# Start the service\nrun_service --config setup.yml"
    with_block_program("<div><code>#{CGI.escapeHTML(program)}</code></div>") do |payload|
      expect(block_program_values(payload.fetch('markdown'))).to eq(["#{program}\n"])
      expect(Nokogiri::HTML5.parse(payload.fetch('html')).at_css('code').text).to eq(program)
    end
  end

  it 'retains original leading and trailing program whitespace instead of trimming it' do
    program = "\n            run_service --demo\n          "
    with_block_program("<p><code data-clipboard-text='run_service --demo'>#{program}</code></p>") do |payload|
      expect(block_program_values(payload.fetch('markdown'))).to eq(["#{program}\n"])
      expect(Nokogiri::HTML5.parse(payload.fetch('html')).at_css('code').text).to eq(program)
    end
  end

  it 'keeps introductory prose and emphasis before an explicitly separated program' do
    program = "<script data-counter='https://counter.example.test/count'\n        async src='https://counter.example.test/client.js'></script>"
    body = "<p>Use <strong>one script tag</strong>:<br>\n<code>#{CGI.escapeHTML(program)}</code>\n</p>"
    with_block_program(body) do |payload|
      markdown = payload.fetch('markdown')
      expect(markdown).to include('Use **one script tag**:')
      expect(block_program_values(markdown)).to eq(["#{program}\n"])
      expect(markdown.index('one script tag')).to be < markdown.index('<script data-counter=')
    end
  end

  it 'preserves equal programs in independent physical sections in source order' do
    program = "# Independently published\nrun_service --check"
    body = %w[Alpha Beta].map do |name|
      "<section><h2>#{name} instructions</h2><p><code>#{CGI.escapeHTML(program)}</code></p></section>"
    end.join
    with_block_program(body) do |payload|
      expect(block_program_values(payload.fetch('markdown'))).to eq(["#{program}\n", "#{program}\n"])
      expect(payload.fetch('markdown').index('Alpha instructions')).to be < payload.fetch('markdown').index('Beta instructions')
    end
  end

  it 'retains every line of a complete long program without a presentation limit' do
    program = (1..500).map { |line| "value_#{line} = transform(source, '#{line}:literal')" }.join("\n")
    with_block_program("<div><code>#{CGI.escapeHTML(program)}</code></div>") do |payload|
      expect(block_program_values(payload.fetch('markdown'))).to eq(["#{program}\n"])
    end
  end

  it 'keeps ordinary inline code and existing preformatted programs intact' do
    program = "existing(source);\nfinish(source);"
    body = '<p>Before <code>literal(source)</code> after.</p>' \
           "<pre><code>#{CGI.escapeHTML(program)}</code></pre>"
    with_block_program(body) do |payload|
      expect(payload.fetch('markdown')).to include('Before `literal(source)` after.')
      expect(block_program_values(payload.fetch('markdown'))).to eq(["#{program}\n"])
    end
  end

  it 'does not expose hidden or closed programs while retaining the visible complete program' do
    program = "# Visible instructions\nrun_service --visible"
    body = "<div><code>#{CGI.escapeHTML(program)}</code></div>" \
           "<div style=\"display:none\"><code>hidden_command()\nhidden_finish()</code></div>" \
           "<details><summary>Additional instructions</summary><code>closed_command()\nclosed_finish()</code></details>"
    with_block_program(body) do |payload|
      expect(block_program_values(payload.fetch('markdown'))).to eq(["#{program}\n"])
      expect(payload.fetch('markdown')).not_to include('hidden_command()', 'hidden_finish()', 'closed_command()', 'closed_finish()')
    end
  end

  it 'retains multiline inline fragments within their surrounding prose' do
    program = "alpha()\n beta()"
    with_block_program("<p>Before <code>#{program}</code> after.</p>") do |payload|
      expect(block_program_values(payload.fetch('markdown'))).to be_empty
      expect(payload.fetch('markdown')).to match(/Before `alpha\(\)\s+beta\(\)` after\./)
      expect(Nokogiri::HTML5.parse(payload.fetch('html')).at_css('code').text).to eq(program)
    end
  end

  it 'keeps table cell code on its existing table serialization path' do
    program = "alpha()\n beta()"
    body = '<table><thead><tr><th>Example</th><th>Program</th></tr></thead><tbody>' \
           "<tr><td>meaningful row</td><td><code>#{program}</code></td></tr></tbody></table>"
    with_block_program(body) do |payload|
      expect(block_program_values(payload.fetch('markdown'))).to be_empty
      expect(payload.fetch('markdown')).to include('| Example | Program |', 'meaningful row', 'alpha()', 'beta()')
      expect(Nokogiri::HTML5.parse(payload.fetch('html')).at_css('table code').text).to eq(program)
    end
  end

  it 'does not promote a hard-break fragment followed by more prose' do
    program = "alpha()\n beta()"
    with_block_program("<p>Use code:<br><code>#{program}</code> then continue reading.</p>") do |payload|
      expect(block_program_values(payload.fetch('markdown'))).to be_empty
      expect(payload.fetch('markdown')).to match(/`alpha\(\)\s+beta\(\)` then continue reading\./)
      expect(Nokogiri::HTML5.parse(payload.fetch('html')).at_css('code').text).to eq(program)
    end
  end

  it 'keeps private snapshot attributes distinct from authored attributes' do
    program = "first_operation()\nlast_operation()"
    body = "<p data-fetch-util-block-code-program='0'><code data-fetch-util-block-code-program='77'>#{program}</code></p>"
    with_block_program(body) do |payload|
      expect(block_program_values(payload.fetch('markdown'))).to eq(["#{program}\n"])
      expect(Nokogiri::HTML5.parse(payload.fetch('html')).at_css('code').text).to eq(program)
    end
  end
end
