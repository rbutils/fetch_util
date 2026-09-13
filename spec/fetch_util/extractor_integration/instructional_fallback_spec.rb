require "spec_helper"
require "support/extractor_integration_helpers"

RSpec.describe FetchUtil::Extractor do
  include_context "extractor integration helpers"

  def instructional_fallback_html
    sections = Array.new(3) do |index|
      <<~HTML
        <h2>Installation method #{index}</h2>
        <p>Install the integration before creating the application. This method connects the compiler to your existing runtime.</p>
        <div class="highlight"><pre><code>install tool-#{index}</code></pre></div>
        <p>Place the following configuration in your application file, then start the development server to see the output.</p>
        <div class="highlight"><pre><code>application = Application.new do |config|
          config.runtime = "browser-#{index}"
          config.entrypoint = "main.rb"
        end
        application.start</code></pre></div>
        <p>See the <a href="/integration/#{index}">integration reference #{index}</a> for further configuration options.</p>
      HTML
    end.join
    <<~HTML
      <html><head><title>Browser compiler</title><meta name="author" content="Avery Example"></head><body>
        <nav><a href="/login">Account navigation</a></nav>
        <div class="container">
          <div class="hero"><h1>Browser compiler</h1><p>Build browser applications with an approachable compiler and a familiar language.</p></div>
          #{sections}
          <h2>Resources</h2>
          <p>Find <a href="/examples">complete application examples</a>, <a href="/libraries">compatible library packages</a>
            and <a href="/community">community discussions</a> to support your application development.</p>
          <div hidden><pre>private_hidden_command()</pre></div>
          <aside><pre>unrelated_sidebar_command()</pre></aside>
        </div>
        <footer>Footer navigation</footer>
      </body></html>
    HTML
  end

  it "recovers short commands and owned introductory and resource prose on a generic landing page" do
    extract_from_url("https://compiler.example/", instructional_fallback_html) do |result|
      expect(result.fetch("readerMode")).to be(true)
      expect(result.fetch("contentType")).to eq("article")
      expect(result.fetch("byline")).to eq("Avery Example")
      markdown = result.fetch("markdown")
      expect(markdown).to include("Build browser applications", "complete application examples", "community discussions")
      expect(markdown.scan(/```\ninstall tool-(\d+)\n```/).flatten).to eq(%w[0 1 2])
      expect(markdown.scan(/config.runtime = "browser-(\d+)"/).flatten).to eq(%w[0 1 2])
      expect(markdown).not_to include("private_hidden_command", "unrelated_sidebar_command", "Account navigation", "Footer navigation")
    end
  end

  it "also recovers instructional content on a non-homepage article route" do
    extract_from_url("https://compiler.example/tutorial/installation", instructional_fallback_html) do |result|
      expect(result.fetch("contentType")).to eq("article")
      expect(result.fetch("readerMode")).to be(true)
      expect(result.fetch("markdown").scan(/```\ninstall tool-(\d+)\n```/).flatten).to eq(%w[0 1 2])
    end
  end

  it "recovers an instructional page even when Readability discarded every short example" do
    html = instructional_fallback_html.gsub(%r{<pre><code>application =.*?</code></pre>}m, "<pre><code>tool --help</code></pre>")

    extract_from_url("https://compiler.example/", html) do |result|
      expect(result.fetch("contentType")).to eq("article")
      expect(result.fetch("markdown").scan(/```\ninstall tool-(\d+)\n```/).flatten).to eq(%w[0 1 2])
      expect(result.fetch("markdown").scan(/```\ntool --help\n```/).length).to eq(3)
    end
  end
end
