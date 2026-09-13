# frozen_string_literal: true

require 'spec_helper'
require_relative '../../support/extractor_integration_helpers'

RSpec.describe FetchUtil::Extractor do
  include_context 'extractor integration helpers'

  def code_surface_page(body)
    <<~HTML
      <html><head><title>Example integration guide</title></head><body><main>
      <h1>Example integration guide</h1>
      <p>Follow these examples to configure the client and build a working application.
      Every line belongs to the example, including callbacks, comments and output.</p>
      #{body}
      <p>Keep the configuration beside your application and run it with the provided runtime.</p>
      </main></body></html>
    HTML
  end

  it 'keeps all rendered editor lines together before article cleanup' do
    html = code_surface_page(<<~HTML)
      <div class="codeBlock-wrapper"><div class="CodeMirror">
      <div class="CodeMirror-measure"><pre>xxxxxxxxxx</pre></div>
      <textarea hidden>unmaterialized source buffer</textarea>
      <div class="CodeMirror-code">
      <pre class="CodeMirror-line"><span>const component = {</span></pre>
      <pre class="CodeMirror-line"><span>  <span class="cm-property">view</span>: function() {</span></pre>
      <pre class="CodeMirror-line"><span>    <span class="cm-comment">// your code goes here!</span></span></pre>
      <pre class="CodeMirror-line"><span>    return count++;</span></pre>
      <pre class="CodeMirror-line"><span>  }</span></pre>
      <pre class="CodeMirror-line"><span>};</span></pre>
      <pre class="CodeMirror-line" style="display:none">inactive example</pre>
      </div></div></div>
    HTML

    result = extract_from_url('https://guide.example.test/integration', html) { |payload| payload }
    expect(result.fetch('markdown')).to include("const component = {\n  view: function() {\n    // your code goes here!\n    return count++;\n  }\n};")
    expect(result.fetch('markdown')).not_to include('xxxxxxxxxx', 'unmaterialized source buffer', 'inactive example')
  end

  it 'preserves every materialized modern editor line without collecting a hidden editor' do
    lines = (1..125).map { |index| "<div class='cm-line'>configure(#{index});</div>" }.join
    html = code_surface_page(<<~HTML)
      <div class="cm-editor"><div class="cm-content">#{lines}</div></div>
      <div class="cm-editor" hidden><div class="cm-content"><div class="cm-line">hidden()</div></div></div>
    HTML

    result = extract_from_url('https://guide.example.test/configuration', html, reader_mode: false) { |payload| payload }
    expect(result.fetch('markdown')).to include((1..125).map { |index| "configure(#{index});" }.join("\n"))
    expect(result.fetch('markdown')).not_to include('hidden()')
  end

  it 'preserves block line breaks and independent examples inside one wrapper' do
    html = code_surface_page(<<~HTML)
      <div class="code-samples">
      <pre><div>$ npm install toolkit</div><div>$ toolkit start</div></pre>
      <p>Import the installed package in the application.</p>
      <pre><code>const toolkit = require('toolkit');</code></pre>
      </div>
    HTML

    result = extract_from_url('https://guide.example.test/installation', html, reader_mode: false) { |payload| payload }
    expect(result.fetch('markdown')).to include("$ npm install toolkit\n$ toolkit start", "const toolkit = require('toolkit');")
    expect(result.fetch('markdown')).to include('Import the installed package in the application.')
    expect(result.fetch('markdown').scan(/^```/).length).to eq(4)
  end

  it 'preserves highlighted code comments and identifiers while removing real controls' do
    html = code_surface_page(<<~HTML)
      <pre><code><span class="comment">// expected output</span>
      <span class="share">share</span>(<span class="advert">advert</span>);
      <span class="cm-property">view</span>();</code><button>Copy</button></pre>
      <div class="share-buttons"><button>Share</button></div>
    HTML

    result = extract_from_url('https://guide.example.test/output', html) { |payload| payload }
    expect(result.fetch('markdown')).to include("// expected output\nshare(advert);\nview();")
    expect(result.fetch('markdown')).not_to include('Copy', 'Share')
  end

  it 'keeps preformatted samples fenced inside an inline code wrapper' do
    example = "let answer = 42\nif answer > 0:\n  echo answer"
    html = code_surface_page(<<~HTML)
      <code class="sample"><figure class="highlight"><pre>#{example}</pre></figure></code>
      <p>Use the inline expression <code>print(value)</code> when reporting the result.</p>
    HTML

    result = extract_from_url('https://guide.example.test/examples', html, reader_mode: false) { |payload| payload }
    expect(result.fetch('markdown')).to include(example, '`print(value)`')
    expect(result.fetch('markdown').scan(/^```/).length).to eq(2)
  end
end
