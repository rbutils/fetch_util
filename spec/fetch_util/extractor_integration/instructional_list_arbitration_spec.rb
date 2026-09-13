require "spec_helper"
require "support/extractor_integration_helpers"

RSpec.describe FetchUtil::Extractor do
  include_context "extractor integration helpers"

  def instructional_landing_html
    <<~HTML
      <html><head><title>Quartz programming toolkit</title></head><body>
        <nav><a href="/download">Download toolkit</a></nav>
        <div class="container">
          <h1>Quartz programming toolkit</h1>
          <h2>Overview</h2>
          <p>Find a compiler and runtime for building browser applications with familiar programming tools.</p>
          <pre><code>items.each do |item|
        puts item
      end</code></pre>
          <h2>Server setup</h2>
          <p>Install the server integration and then configure the application entry point.</p>
          <pre><code>gem install quartz-server</code></pre>
          <p>Read the <a href="/guides/server">server integration guide</a> for deployment details.</p>
          <h2>Browser setup</h2>
          <p>Compile the application before including the generated script in your page.</p>
          <pre><code>quartz --compile app.rb &gt; app.js</code></pre>
          <p>Use the <a href="/guides/browser">browser application guide</a> to integrate the result.</p>
          <h2>Resources</h2>
          <p><a href="/examples">Application examples</a>, <a href="/libraries">Compatible libraries</a>,
            <a href="/community">Community discussions</a> and <a href="/reference">Language reference</a>.</p>
        </div>
      </body></html>
    HTML
  end

  def instructional_feed_html(extra = "", code_cards: false)
    groups = Array.new(2) do |group|
      cards = Array.new(6) do |index|
        number = group * 6 + index
        example = code_cards ? "<pre><code>example_#{number}()</code></pre>" : ""
        "<article><h3><a href='/stories/#{number}'>Compiler development report #{number}</a></h3>" \
          "<p>Independent report #{number} describes the latest compiler developments and release progress.</p>#{example}</article>"
      end.join
      "<section><h2>Development updates #{group}</h2>#{cards}</section>"
    end.join
    "<html><head><title>Compiler news and latest reports</title></head>" \
      "<body><main><h1>Compiler news</h1>#{extra}#{groups}</main></body></html>"
  end

  it "keeps tutorial prose and fenced examples instead of an early homepage link summary" do
    result = extract_from_url("https://quartz.example/", instructional_landing_html, reader_mode: false) { |payload| payload }

    expect(result.fetch("contentType")).to eq("article")
    markdown = result.fetch("markdown")
    expect(markdown).to include("Install the server integration", "Compile the application", "Community discussions")
    expect(markdown).to include(
      "```\nitems.each do |item|\n  puts item\nend\n```",
      "```\ngem install quartz-server\n```", "```\nquartz --compile app.rb > app.js\n```"
    )
    expect(markdown.index("## Server setup")).to be < markdown.index("## Browser setup")
    expect(markdown).not_to include("Download toolkit")
  end

  it "protects short examples from late index-list arbitration" do
    steps = Array.new(8) do |index|
      "<section><h2>Configuration step #{index}</h2><p>Set the value before continuing to the next step.</p>" \
        "<pre><code>configure(#{index})</code></pre><p><a href='/reference/#{index}'>Configuration reference #{index}</a></p></section>"
    end.join
    html = "<html><head><title>Configuration examples</title></head><body><div class='content'>#{steps}</div></body></html>"
    result = extract_from_url("https://quartz.example/examples", html, reader_mode: false) { |payload| payload }

    expect(result.fetch("contentType")).to eq("article")
    expect(result.fetch("markdown").scan(/```\nconfigure\((\d+)\)\n```/).flatten).to eq((0...8).map(&:to_s))
  end

  it "does not let a sectioned portal discard page-owned instructions beside its records" do
    instructions = "<h2>Reproduce these results</h2><p>Run the benchmark with the supplied configuration.</p>" \
                   "<pre><code>compiler benchmark --verify</code></pre>"
    result = extract_from_url("https://compiler.example/", instructional_feed_html(instructions), reader_mode: false) { |payload| payload }

    expect(result.fetch("markdown")).to include("```\ncompiler benchmark --verify\n```", "Run the benchmark")
    expect(result.fetch("markdown").scan(%r{\]\(https://compiler.example/stories/(\d+)\)}).flatten).to eq((0...12).map(&:to_s))
  end

  it "ignores hidden and chrome-owned examples when recognizing real feeds" do
    extra = "<div style='display:none'><pre>hidden_command()</pre></div>" \
            "<div aria-hidden='true'><pre>accessible_hidden_command()</pre></div>" \
            "<aside><pre>sidebar_command()</pre></aside><nav><pre>navigation_command()</pre></nav>"
    result = extract_from_url("https://compiler.example/", instructional_feed_html(extra), reader_mode: false) { |payload| payload }

    expect(result.fetch("contentType")).to eq("list")
    expect(result.fetch("markdown")).not_to include("hidden_command", "sidebar_command", "navigation_command")
    expect(result.fetch("markdown").scan(%r{\]\(https://compiler.example/stories/(\d+)\)}).flatten).to eq((0...12).map(&:to_s))
  end

  it "keeps independent linked code-example cards as a feed" do
    result = extract_from_url("https://compiler.example/", instructional_feed_html(code_cards: true), reader_mode: false) { |payload| payload }

    expect(result.fetch("contentType")).to eq("list")
    expect(result.fetch("markdown").scan(%r{\]\(https://compiler.example/stories/(\d+)\)}).flatten).to eq((0...12).map(&:to_s))
  end
end
