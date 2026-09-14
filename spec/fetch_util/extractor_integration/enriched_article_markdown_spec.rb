# frozen_string_literal: true

RSpec.describe 'FetchUtil enriched article structure' do
  include_context 'extractor integration helpers'

  [
    %w[sports SportsEvent sports_event],
    %w[property House property],
    %w[product Product product]
  ].each do |path, schema_type, content_type|
    it "preserves owned structure and destinations when enriching #{content_type} HTML" do
      data = { '@context' => 'https://schema.org', '@type' => schema_type, 'name' => 'Detailed report' }
      if path == 'sports'
        data.merge!('homeTeam' => { 'name' => 'North Club' }, 'awayTeam' => { 'name' => 'South Club' },
                    'startDate' => '2026-09-14T12:00:00Z', 'location' => { 'name' => 'River Ground' })
      else
        data['offers'] = { '@type' => 'Offer', 'price' => '900', 'priceCurrency' => 'USD' }
      end
      description = path == 'property' ? 'house listing' : 'detailed account'
      purchase_control = path == 'product' ? '<button class="add-to-cart">Buy this product</button>' : ''
      html = <<~HTML
        <html><head><title>Detailed report</title>
          <script type="application/ld+json">#{JSON.generate(data)}</script>
        </head><body><main><article><h1>Detailed report</h1>
          <p>This #{description} records the original observations, their practical context, and the evidence available to readers. Its sections explain the important distinctions without replacing the source material with a short summary.</p>
          #{purchase_control}
          <h2>First-hand observations</h2>
          <p>The <a href="/evidence">supporting evidence</a> describes the measurements and circumstances in detail. The account preserves <strong>important qualifications</strong> alongside the observations so that readers can evaluate the complete record.</p>
          <ul><li>Independent review completed</li><li>Original records remain available</li></ul>
          <h3>Further context</h3>
          <p>These additional notes explain how the observations relate to earlier records. They retain the distinctions needed to interpret the account and provide a complete description of the underlying circumstances.</p>
        </article></main></body></html>
      HTML

      extract_from_url("https://records.example/#{path}/detailed-report", html) do |payload|
        expect(payload.fetch('contentType')).to eq(content_type)
        markdown = payload.fetch('markdown')
        expect(markdown).to include('## First-hand observations', '### Further context')
        expect(markdown).to include('[supporting evidence](https://records.example/evidence)', '**important qualifications**')
        expect(markdown).to match(/^- +Independent review completed$/)
        expect(markdown).to match(/^- +Original records remain available$/)
        expect(markdown.scan(/^\#{1,2} Detailed report$/).length).to eq(1)
        expect(markdown.lines.first.strip).to match(/^\#{1,2} Detailed report$/)
        expect(markdown).to include('- Price: $900') unless path == 'sports'
      end
    end
  end
end
