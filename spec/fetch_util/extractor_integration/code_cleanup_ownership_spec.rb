require "spec_helper"
require "support/extractor_integration_helpers"

RSpec.describe FetchUtil::Extractor do
  include_context "extractor integration helpers"

  def code_cleanup_page(examples)
    <<~HTML
      <html><head><title>Working with commands</title></head><body>
        <main><article>
          <h1>Working with commands</h1>
          <p>These examples demonstrate how commands operate on local values and preserve their output.
             Run each example in the interpreter and compare the resulting values before continuing.</p>
          #{examples}
          <p>Use <code><span>print</span></code> to inspect the result. The keyboard command
             <kbd><span>delete</span></kbd> and output <samp><span>save</span></samp> are also meaningful.</p>
          <button>Print</button><a href="/share">Share</a>
        </article></main>
      </body></html>
    HTML
  end

  it 'preserves highlighted identifiers that resemble UI actions in generic articles' do
    html = code_cleanup_page(<<~HTML)
      <pre><code><span class="nb">print</span>("ready")
      <span class="nf">save</span>(record)
      <span class="k">delete</span> row
      player.<span>play</span>()</code></pre>
    HTML

    extract_from_url('https://manual.example.test/commands', html, reader_mode: false) do |payload|
      markdown = payload.fetch('markdown')
      expect(markdown).to include('print("ready")', 'save(record)', 'delete row', 'player.play()')
      expect(markdown).to include('`print`', 'delete', 'save')
      expect(markdown).not_to include("[Share]", "\nPrint\n")
    end
  end

  it 'keeps short code blocks and linked tokens while removing real code controls' do
    html = code_cleanup_page(<<~HTML)
      <div class="highlight"><pre><code><span>copy</span></code></pre></div>
      <div class="highlight"><pre><code><span>help</span></code></pre></div>
      <pre><code>Copy(value)
      <a href="/functions/print"><span>print</span></a>("¶")
      copy(value)</code><button>Copy to clipboard</button><span role="button">Copy</span></pre>
    HTML

    extract_from_url('https://manual.example.test/commands', html, reader_mode: false) do |payload|
      markdown = payload.fetch('markdown')
      expect(markdown).to include("\ncopy\n", "\nhelp\n", 'Copy(value)', 'print("¶")', 'copy(value)')
      expect(markdown).not_to include("Copy to clipboard", "\nCopy\n", "[Share]")
    end
  end

  it 'preserves documentation identifiers through docs cleanup and Markdown conversion' do
    html = <<~HTML
      <html><head><title>Command reference</title><meta name="generator" content="Sphinx"></head>
      <body><div class="document"><div class="body" role="main">
        <h1>Command reference</h1>
        <p>Inspect the interpreter commands below. Each line is executable and its identifiers must
           remain unchanged when the reference is copied into another programming environment.</p>
        <div class="highlight-python"><pre><span class="nb">print</span>("hello")
      <span>help</span>(object)
      <span>search</span>(index)
      <span>settings</span>.update(value)</pre></div>
        <p>The <code><span>help</span></code> function describes the selected object.</p>
        <button>Copy to clipboard</button><a href="#top">View source</a>
      </div></div></body></html>
    HTML

    extract_from_url('https://reference.example.test/commands.html', html) do |payload|
      markdown = payload.fetch('markdown')
      expect(markdown).to include('print("hello")', 'help(object)', 'search(index)', 'settings.update(value)', '`help`')
      expect(markdown).not_to include('Copy to clipboard', 'View source')
    end
  end
end
