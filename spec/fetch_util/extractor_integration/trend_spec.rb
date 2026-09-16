# frozen_string_literal: true

RSpec.describe 'FetchUtil Trend.az extractor integration' do
  include_context 'extractor integration helpers'

  it 'extracts complete Trend articles through shared reader handling' do
    url = 'https://www.trend.az/business/green-economy/4204857.html'
    html = fixture_contents(File.expand_path('../../fixtures/trend_article.html', __dir__))

    with_url_page(url, html) do |page|
      document_without_scripts = <<~JS
        (() => {
          const clone = document.documentElement.cloneNode(true);
          clone.querySelectorAll("head script").forEach((script) => script.remove());
          return clone.outerHTML;
        })()
      JS
      source = page.evaluate(document_without_scripts)
      payload = extract_payload(page)

      expect(payload['markdown']).to eq(<<~MARKDOWN.chomp)
        # # Uzbekistan presents green energy experience in Tajikistan

        Uzbekistan presented its experience in renewable energy development in Tajikistan and described practical work on cleaner power systems.

        Participants discussed global trends in renewable energy development, regional cooperation, and how to turn shared planning into investment.

        The sides reviewed next steps for future projects, knowledge-sharing, and wider energy collaboration across Central Asia.
      MARKDOWN
      expect(payload['html']).not_to include('Latest Premium Azerbaijan Politics Economy', 'Follow Trend on Whatsapp', 'Archive')
      expect(payload).to include(
        'title' => '# Uzbekistan presents green energy experience in Tajikistan',
        'contentType' => 'article',
        'readerMode' => true,
        'hostAware' => false,
        'warnings' => [],
        'suspect' => false
      )
      expect(page.evaluate(document_without_scripts)).to eq(source)
    end
  end
end
