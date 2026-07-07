# frozen_string_literal: true

RSpec.describe 'FetchUtil Index.hr extractor integration' do
  include_context 'extractor integration helpers'

  it 'extracts Index.hr article bodies without stale_content on recirculated sport articles' do
    html = File.read(File.expand_path('../../fixtures/index_hr_article.html', __dir__))

    extract_from_url('https://www.index.hr/sport/clanak/dinamo-vraca-projekt-na-kojemu-je-godinama-zaradjivao-milijune-evo-svih-detalja/2796419.aspx', html) do |payload|
      expect(payload['contentType']).to eq('article')
      expect(payload['title']).to eq('Dinamo vraća projekt na kojemu je godinama zarađivao milijune. Evo svih detalja - Index.hr')
      expect(payload['publishedTime']).to be_nil
      expect(payload['markdown']).to include('DINAMO će sljedeće sezone po prvi put nakon gašenja projekta 2022. godine')
      expect(payload['markdown']).to include('Dinamova B momčad će domaće utakmice igrati u Zaprešiću')
      expect(payload['markdown']).not_to include('Komentari')
      expect(payload['warnings']).not_to include('stale_content')
      expect(payload['warnings']).not_to include('url_content_mismatch')
      expect(payload['warnings']).not_to include('consent_interstitial')
    end
  end
end
