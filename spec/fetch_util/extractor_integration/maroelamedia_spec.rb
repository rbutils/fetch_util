# frozen_string_literal: true

RSpec.describe 'FetchUtil Maroela Media extractor integration' do
  include_context 'extractor integration helpers'

  it 'uses shared WordPress extraction for the article, credit and complete prose excerpt' do
    html = fixture_contents(File.expand_path('../fixtures/maroelamedia_article.html', __dir__))
    url = 'https://www.maroelamedia.co.za/nuus/sa-nuus/eskom-verwelkom-hofbevel-wat-trillian-dwing-om-miljoene-terug-te-betaal'
    lead = 'Eskom het ŉ hofbeslissing verwelkom wat die konsultantefirma Trillian Capital beveel om die R600 miljoen ' \
           'wat hy onwettig van die sukkelende kragvoorsiener verhaal het, terug te betaal.'

    extract_from_url(url, html) do |payload|
      expect(payload['contentType']).to eq('article')
      expect(payload['title']).to eq('Eskom verwelkom hofbevel wat Trillian dwing om miljoene terug te betaal')
      expect(payload['excerpt']).to eq(lead)
      expect(payload['markdown']).to include(lead, 'Nhlanhla Phillips/African News Agency/ANA', 'die koste van drie advokate betaal')
      expect(payload['html']).to include('Nhlanhla Phillips/African News Agency/ANA')
      expect(payload['markdown']).not_to include('O wee, die gesang is uit!', '- Maroela Media')
      expect(payload['warnings']).not_to include('empty_extraction', 'short_extraction', 'url_content_mismatch', 'consent_interstitial')
    end
  end
end
