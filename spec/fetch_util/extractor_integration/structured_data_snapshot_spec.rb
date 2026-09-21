# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'structured data snapshot' do
  include_context 'extractor integration helpers'

  def structured_data_test_source
    root = File.expand_path('../../..', __dir__)
    source = File.readlines(File.join(root, 'websieve/manifest.txt'), chomp: true)
                 .reject { |line| line.empty? || line.start_with?('#') }
                 .map { |path| File.read(File.join(root, 'websieve', path)) }.join("\n")
    outro = File.read(File.join(root, 'websieve/99_outro.js'))
    source.delete_suffix(outro) + <<~JAVASCRIPT + outro
      window.__structuredDataSnapshot = function() {
        var originalParse = JSON.parse;
        var parseCount = 0;
        JSON.parse = function(value) {
          parseCount += 1;
          return originalParse(value);
        };

        try {
          var first = structuredDataNodes()[0];
          var repeated = structuredDataNode("Article");
          document.querySelector('script[type="application/ld+json"]').textContent = JSON.stringify({
            "@type": "Article",
            "headline": "Updated headline"
          });
          var updated = structuredDataNode("Article");
          return JSON.stringify({
            parseCount: parseCount,
            first: first && first.headline,
            repeated: repeated && repeated.headline,
            updated: updated && updated.headline
          });
        } finally {
          JSON.parse = originalParse;
        }
      };
    JAVASCRIPT
  end

  it 'reuses parsed JSON-LD until a source script changes' do
    html = <<~HTML
      <html><head>
        <script type="application/ld+json">
          {"@type":"Article","headline":"Original headline"}
        </script>
      </head><body><main>Article body</main></body></html>
    HTML

    with_url_page('https://example.test/article', html) do |page|
      page.add_script_tag(content: structured_data_test_source)
      result = JSON.parse(page.evaluate('window.__structuredDataSnapshot()'))

      expect(result).to eq(
        'parseCount' => 2,
        'first' => 'Original headline',
        'repeated' => 'Original headline',
        'updated' => 'Updated headline'
      )
    end
  end
end
