# frozen_string_literal: true

RSpec.describe 'FetchUtil extractor integration for Der Standard articles' do
  include_context 'extractor integration helpers'

  it 'extracts Der Standard article bodies without consent-list false positives' do
    expect_fixture_article(
      url: 'https://www.derstandard.at/story/3000000298956/die-ukraine-droht-den-krieg-zu-verlieren-wie-konnte-es-so-weit-kommen',
      fixture_path: File.expand_path('../../fixtures/derstandard_article.html', __dir__),
      includes: [
        'Ukrainekrieg',
        'Mit großer Tapferkeit haben sich die Ukrainer gegen den russischen Überfall 2022 gewehrt',
        'Schon nach wenigen Monaten habe man im Kreml realisiert'
      ],
      excludes: ['Mit Werbung weiterlesen', 'Optionen verwalten'],
      warning_excludes: %w[empty_extraction short_extraction url_content_mismatch consent_interstitial]
    )
  end
end
