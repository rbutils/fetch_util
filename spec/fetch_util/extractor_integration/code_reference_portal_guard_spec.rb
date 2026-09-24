# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Complete code reference ownership' do
  include_context 'extractor integration helpers'

  it 'keeps every source-owned API example and section without replacing the article with a link list' do
    sections = (1..12).map do |index|
      <<~HTML
        <section>
          <h3>Request method #{index}</h3>
          <p>Method #{index} explains request headers, socket handling, response ordering, and compatibility of the API with existing applications using real HTTP connections.</p>
          <p>Example #{index} preserves exception behavior and describes the callback contract for integrations that send requests over a persistent connection.</p>
          <pre><code>function requestMethod#{index}(response) { return response.statusCode + #{index}; }</code></pre>
          <p><a href="/api/method-#{index}.html">Request method #{index} reference</a></p>
        </section>
      HTML
    end.join
    html = <<~HTML
      <html><head><title>HTTP API reference</title></head><body>
        <header><nav><a href="/">Home</a><a href="/api/">All APIs</a></nav></header>
        <div id="api-content">
          <h2>HTTP API reference</h2>
          <p>The HTTP API provides request and response methods with comprehensive usage examples, connection lifecycle guidance and compatibility details for applications.</p>
          #{sections}
        </div>
      </body></html>
    HTML

    with_url_page('https://reference.example/api/http.html', html) do |page|
      before = page.evaluate('document.body.innerHTML')
      payload = extract_payload(page)

      expect(payload['contentType']).to eq('article')
      expect(payload['markdown']).to include('HTTP API reference')
      positions = (1..12).map do |index|
        method = "requestMethod#{index}(response)"
        destination = "https://reference.example/api/method-#{index}.html"
        expect(payload['markdown'].scan(method).length).to eq(1)
        expect(payload['markdown']).to include(destination)
        payload['markdown'].index(method)
      end
      expect(positions).to eq(positions.sort)
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end

  it 'still treats a linked API directory with code previews as a list' do
    cards = (1..12).map do |index|
      <<~HTML
        <article>
          <h2><a href="/api/packages/#{index}">Package API #{index} reference</a></h2>
          <p>Package #{index} contains its own independent API reference page and documentation destination.</p>
          <pre>preview#{index}()</pre>
        </article>
      HTML
    end.join
    html = "<html><head><title>API package directory</title></head><body><main><h1>API package directory</h1>#{cards}</main></body></html>"

    with_url_page('https://reference.example/api/packages/', html) do |page|
      payload = extract_payload(page)

      expect(payload['contentType']).to eq('list')
      (1..12).each do |index|
        expect(payload['markdown']).to include("https://reference.example/api/packages/#{index}")
      end
    end
  end
end
