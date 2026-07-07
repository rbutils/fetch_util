# frozen_string_literal: true

RSpec.describe 'FetchUtil Novosti extraction' do
  include_context 'extractor integration helpers'

  it 'extracts Novosti article bodies without false URL mismatch warnings' do
    html = File.read(File.expand_path('../../fixtures/novosti_article.html', __dir__))
    url = 'https://www.novosti.rs/vesti/politika/1625167/cedomir-antic-ako-zele-ravnopravnost-srba-neka-delovima-podgorice-cetinja-prave-svoj-fasisticki-diznilend'

    extract_from_url(url, html) do |payload|
      expect_content_type(payload, 'article')
      expect(payload['markdown']).to include('# ČEDOMIR ANTIĆ: Ako ne žele ravnopravnost Srba')
      expect(payload['markdown']).to include('pitanje ravnopravnosti Srba u Crnoj Gori')
      expect(payload['markdown']).to include('srpski jezik, ćirilica i istorijsko nasleđe')
      expect(payload['markdown']).not_to include('REKLAMA')
      expect(payload['markdown']).not_to include('Preporučujemo')
      expect(payload['markdown']).not_to include('Pratite nas i putem iOS')
      expect_warnings(payload, exclude: %w[empty_extraction short_extraction url_content_mismatch consent_interstitial])
      expect(payload['suspect']).to be(false)
    end
  end
end
