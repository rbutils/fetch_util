# frozen_string_literal: true

RSpec.describe 'FetchUtil Danas extraction' do
  include_context 'extractor integration helpers'

  it 'extracts Danas article bodies without share, tags, or comment chrome' do
    expect_fixture_article(
      url: 'https://www.danas.rs/vesti/drustvo/vucic-rupe-na-pitevima-aplikacija',
      fixture_path: File.expand_path('../../fixtures/danas_article.html', __dir__),
      includes: [
        'Predsednik Aleksandar Vučić ponovo',
        'Saobraćajni inženjer Igor Velić',
        'Zoran Đajić',
        'Kraljevo je još u avgustu 2022. godine dobilo aplikaciju'
      ],
      excludes: [
        'Pratite nas na našoj Facebook i Instagram stranici',
        'Komentari',
        'Najčitanije',
        'Ostali komentari'
      ],
      warning_excludes: %w[empty_extraction short_extraction url_content_mismatch consent_interstitial]
    )
  end
end
