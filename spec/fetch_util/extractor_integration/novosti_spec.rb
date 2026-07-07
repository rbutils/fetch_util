# frozen_string_literal: true

RSpec.describe 'FetchUtil Novosti extraction' do
  include_context 'extractor integration helpers'

  it 'extracts Novosti article bodies without false URL mismatch warnings' do
    expect_fixture_article(
      url: 'https://www.novosti.rs/vesti/politika/1625167/cedomir-antic-ako-zele-ravnopravnost-srba-neka-delovima-podgorice-cetinja-prave-svoj-fasisticki-diznilend',
      fixture_path: File.expand_path('../../fixtures/novosti_article.html', __dir__),
      includes: [
        '# ČEDOMIR ANTIĆ: Ako ne žele ravnopravnost Srba',
        'pitanje ravnopravnosti Srba u Crnoj Gori',
        'srpski jezik, ćirilica i istorijsko nasleđe'
      ],
      excludes: ['REKLAMA', 'Pratite nas i putem iOS'],
      warning_excludes: %w[empty_extraction short_extraction url_content_mismatch consent_interstitial]
    )
  end
end
