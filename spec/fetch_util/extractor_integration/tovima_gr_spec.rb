# frozen_string_literal: true

RSpec.describe 'FetchUtil To Vima extractor integration' do
  include_context 'extractor integration helpers'

  it 'extracts To Vima article bodies without Google preferred-source chrome' do
    expect_fixture_article(
      url: 'https://www.tovima.gr/2026/07/07/world/i-nea-eksisosi-sto-nato-eyropaiki-aytonomia-amerikanikes-pieseis-kai-o-rolos-tis-tourkias/',
      fixture_path: File.expand_path('../../fixtures/tovima_gr_article.html', __dir__),
      includes: [
        'Καθώς οι ηγέτες των χωρών του ΝΑΤΟ καταφτάνουν στην Άγκυρα',
        'Οι ευρωπαϊκές πρωτεύουσες αναζητούν κοινές λύσεις χρηματοδότησης'
      ],
      excludes: ['Κάντε TO BHMA προτιμώμενη πηγή', 'google-preferred-source', 'googletag.cmd.push'],
      warning_excludes: %w[empty_extraction short_extraction url_content_mismatch consent_interstitial]
    )
  end
end
