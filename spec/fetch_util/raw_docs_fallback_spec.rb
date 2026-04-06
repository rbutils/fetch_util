# frozen_string_literal: true

RSpec.describe FetchUtil::RawDocsFallback do
  it "extracts fragment-scoped docs content from raw html" do
    html = <<~HTML
            <html lang="en">
              <head>
                <title>Kubernetes API Reference</title>
                <link rel="canonical" href="https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.31/" />
              </head>
              <body>
                <main>
                  <div class="resource-container" id="pod-v1-core">
                    <h1>Pod v1 core</h1>
                    <p>Pod is a collection of containers that can run on a host.</p>
                    <pre><code>apiVersion: v1
      kind: Pod</code></pre>
                    <table>
                      <tr><th>Field</th><th>Description</th></tr>
                      <tr><td>metadata</td><td>Standard object metadata.</td></tr>
                    </table>
                  </div>
                </main>
              </body>
            </html>
    HTML

    payload = described_class.new.payload_from_html(html, requested_url: "https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.31/#pod-v1-core")

    expect(payload["title"]).to eq("Pod v1 core")
    expect(payload["canonicalUrl"]).to eq("https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.31/")
    expect(payload["markdown"]).to include("# Pod v1 core")
    expect(payload["markdown"]).to include("collection of containers")
    expect(payload["markdown"]).to include("```")
    expect(payload["markdown"]).to include("metadata: Standard object metadata.")
  end

  it "extracts named-anchor directive sections from raw html" do
    html = <<~HTML
      <html>
        <head><title>Module ngx_http_proxy_module</title></head>
        <body>
          <a name="proxy_pass"></a>
          <div class="directive"><strong>proxy_pass</strong></div>
          <p>Sets the protocol and address of a proxied server.</p>
          <pre>proxy_pass http://localhost:8000/uri/;</pre>
        </body>
      </html>
    HTML

    payload = described_class.new.payload_from_html(html, requested_url: "https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_pass")

    expect(payload["title"]).to eq("proxy_pass")
    expect(payload["markdown"]).to include("# proxy_pass")
    expect(payload["markdown"]).to include("protocol and address of a proxied server")
  end

  it "extracts fragment ids that contain selector metacharacters" do
    html = <<~HTML
      <html>
        <head><title>Quoted section</title></head>
        <body>
          <main>
            <section id='section"1'>
              <h2>Quoted section</h2>
              <p>This fragment id contains a quote and should still be matched safely.</p>
            </section>
          </main>
        </body>
      </html>
    HTML

    payload = described_class.new.payload_from_html(html, requested_url: "https://example.com/docs#section%221")

    expect(payload["title"]).to eq("Quoted section")
    expect(payload["markdown"]).to include("should still be matched safely")
  end

  it "does not swallow unexpected extraction bugs in payload_from_html" do
    fallback = described_class.new
    html = <<~HTML
      <html>
        <body>
          <main>
            <h1>Example docs</h1>
            <p>This paragraph is long enough to reach the extraction path safely.</p>
          </main>
        </body>
      </html>
    HTML

    allow(fallback).to receive(:markdown_from_root).and_raise(NoMethodError, "boom")

    expect do
      fallback.payload_from_html(html, requested_url: "https://example.com/docs")
    end.to raise_error(NoMethodError, "boom")
  end
end
