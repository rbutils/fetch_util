# frozen_string_literal: true

RSpec.describe 'FetchUtil shared headline extraction' do
  include_context 'extractor integration helpers'

  it 'preserves long owned headlines and summaries while ignoring hidden and navigation records' do
    title = ('A fully materialized headline explains the regional investigation and its public findings. ' * 5).strip
    stories = (1..4).map do |number|
      <<~HTML
        <article><h2><a href="/reports/#{number}">#{title} Report #{number}</a></h2>
          <p>Owned summary #{number} supplies the important context for this independent report.</p></article>
      HTML
    end.join
    html = <<~HTML
      <html><head><title>Independent headlines</title></head><body>
        <nav><a href="/menu">Navigation record must stay outside the list</a></nav>
        <main><h1>Independent headlines</h1>#{stories}
          <a href="/reports/1?utm_source=duplicate">Duplicate alias must not replace the first headline</a>
          <article style="display:none"><h2><a href="/hidden">Hidden source headline must not be represented</a></h2></article>
        </main>
      </body></html>
    HTML

    with_url_page('https://headlines.example/', html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)
      markdown = payload.fetch('markdown')

      expect(payload.fetch('contentType')).to eq('list')
      offsets = (1..4).map do |number|
        expect(markdown).to include("#{title} Report #{number}", "Owned summary #{number}")
        markdown.index("https://headlines.example/reports/#{number}")
      end
      expect(offsets).to all(be_a(Integer))
      expect(offsets).to eq(offsets.sort)
      expect(markdown).not_to include('Navigation record', 'Duplicate alias', 'Hidden source headline')
    end
  end
end
