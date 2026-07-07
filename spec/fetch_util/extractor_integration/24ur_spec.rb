# frozen_string_literal: true

RSpec.describe 'FetchUtil 24ur extractor integration' do
  include_context 'extractor integration helpers'

  it 'extracts 24ur article bodies without social consent chrome or false URL mismatch warnings' do
    # 24ur's profile scopes article text and removes embedded social consent prompts.
    expect_fixture_article(
      url: 'https://www.24ur.com/sport/kosarka/oranzni-kosarkarski-zmaji-po-notah-novega-organizatorja.html',
      fixture_path: File.expand_path('../../fixtures/24ur_article.html', __dir__),
      includes: [
        'Anthony Cowan',
        'prvič oblekel zeleno-oranžni dres Cedevite Olimpije',
        'organizatorja igre'
      ],
      excludes: ['Za ogled potrebujemo tvojo privolitev', 'Omogoči piškotke'],
      warning_excludes: %w[empty_extraction short_extraction url_content_mismatch consent_interstitial]
    )
  end
end
