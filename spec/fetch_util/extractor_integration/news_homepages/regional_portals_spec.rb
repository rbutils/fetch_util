# frozen_string_literal: true

RSpec.describe 'FetchUtil extractor integration' do
  include_context 'extractor integration helpers'

  let(:regional_cards) do
    (1..4).map do |index|
      headline = "Regional headline #{index} #{"complete materialized wording " * 9}"
      %(<section><h2><a href="/report/#{index}">#{headline}</a></h2><p>Owned story synopsis #{index}.</p></section>)
    end.join
  end

  it 'recognizes an unknown-host regional index without route or hostname tables' do
    html = <<~HTML
      <html><head><title>Regional headlines</title><meta name="description" content="The latest news from each regional desk."></head><body>
      <nav><a href="/unowned-navigation">Outside navigation</a></nav>
      <main><h1>Regional headlines</h1>#{regional_cards}
      <section style="display:none"><a href="/hidden">Hidden story that must remain absent from results</a></section></main>
      </body></html>
    HTML
    with_url_page('https://regional-index.example/desk/independent-label', html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)
      expect(payload['contentType']).to eq('list')
      markdown = payload.fetch('markdown')
      destinations = (1..4).map { |index| "https://regional-index.example/report/#{index}" }
      offsets = destinations.map { |url| markdown.index(url) }
      expect(offsets).to all(be_a(Integer))
      expect(offsets).to eq(offsets.sort)
      (1..4).each do |index|
        expect(markdown).to include("Regional headline #{index} #{"complete materialized wording " * 9}".strip)
        expect(markdown).to include("Owned story synopsis #{index}.")
      end
      expect(markdown).not_to include('Outside navigation', 'Hidden story')
    end
  end

  it 'preserves a focal article instead of turning its related records into a regional index' do
    body = (1..4).map { |index| "<p>Authored report paragraph #{index} #{"with the complete factual account and source context " * 5}</p>" }.join
    html = <<~HTML
      <html><head><title>Latest regional news analysis</title></head><body>
      <main><article><h1>Latest regional news analysis</h1>#{body}</article>#{regional_cards}</main>
      </body></html>
    HTML
    with_url_page('https://regional-index.example/desk/analysis', html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)
      expect(payload['contentType']).to eq('article')
      (1..4).each { |index| expect(payload.fetch('markdown')).to include("Authored report paragraph #{index}") }
    end
  end
end
