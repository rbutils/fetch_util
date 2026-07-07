RSpec.describe 'FetchUtil Blick extractor integration' do
  include_context 'extractor integration helpers'

  it 'extracts Blick live ticker article bodies without CMP or mismatch warnings' do
    expect_fixture_article(
      url: 'https://www.blick.ch/ausland/was-wuerde-ein-verlust-pokrowsks-fuer-die-ukraine-bedeuten-id17193095.html',
      fixture_path: File.expand_path('../../fixtures/blick_article.html', __dir__),
      includes: [
        'Darum gehts',
        'Russland greift die Ukraine unvermindert an',
        'US-Präsident Donald Trump hatte vor den Genfer Ukraine-Verhandlungen mit einem Ultimatum am Donnerstag gedroht.'
      ],
      excludes: [
        'Externe Inhalte',
        'Möchtest du diesen und weitere externe Beiträge'
      ],
      warning_excludes: %w[empty_extraction short_extraction url_content_mismatch consent_interstitial],
      suspect: true
    )
  end
end
