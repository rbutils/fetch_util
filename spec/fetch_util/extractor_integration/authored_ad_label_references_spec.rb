RSpec.describe FetchUtil::Extractor do
  include_context 'complete raw table expectations'

  it 'retains ad-like labels owned by authored prose while removing standalone ad controls' do
    html = <<~HTML
      <html>
        <head><title>Publication register</title><meta name="generator" content="mkdocs-1.6.1"></head>
        <body><main><article class="md-content__inner">
          <h1>Publication register</h1>
          <p>Readers may contact <a href="/sponsors/"><span>sponsors</span></a> for preservation funding.</p>
          <ul><li>Consult the <a href="/sponsored-records/">sponsored records</a> before evaluating the evidence.</li></ul>
          <dl><dt>Documentation</dt><dd>Review the <a href="/sponsor-archive/">sponsor archive</a> for the complete chronology.</dd></dl>
          <table><tbody><tr><th>Source</th><td>Read the <a href="/advertisement-records/">advertisement records</a> before comparing the dates.</td></tr></tbody></table>
          <div class="ad-label"><p>Advertisement</p><a href="/sponsor-control/">sponsors</a></div>
          <div><a href="/sponsored-control/">Sponsored</a></div>
        </article></main></body>
      </html>
    HTML

    with_url_page('https://publication.example.test/register/', html) do |page|
      before = page.evaluate('document.body.outerHTML')
      payload = extract(page)
      references = page.evaluate(<<~JS)
        (function() {
          var root = document.createElement("div");
          root.innerHTML = #{JSON.generate(payload.fetch("html"))};
          return Array.from(root.querySelectorAll("a[href]")).map(function(node) {
            return [node.textContent, node.getAttribute("href")];
          });
        })()
      JS
      expected_references = [
        ['sponsors', 'https://publication.example.test/sponsors/'],
        ['sponsored records', 'https://publication.example.test/sponsored-records/'],
        ['sponsor archive', 'https://publication.example.test/sponsor-archive/'],
        ['advertisement records', 'https://publication.example.test/advertisement-records/']
      ]

      expect(references).to eq(expected_references)
      expect(payload.fetch('markdown')).to include(
        'Readers may contact [sponsors](https://publication.example.test/sponsors/) for preservation funding.',
        'Consult the [sponsored records](https://publication.example.test/sponsored-records/) before evaluating the evidence.',
        'Review the [sponsor archive](https://publication.example.test/sponsor-archive/) for the complete chronology.'
      )
      expect_complete_raw_table_material(payload)
      expect(payload.fetch('html')).not_to include('sponsor-control', 'sponsored-control')
      expect(payload.fetch('markdown')).not_to include('sponsor-control', 'sponsored-control')
      expect(page.evaluate('document.body.outerHTML')).to eq(before)
    end
  end
end
