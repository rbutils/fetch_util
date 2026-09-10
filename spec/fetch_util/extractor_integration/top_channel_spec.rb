# frozen_string_literal: true

RSpec.describe 'FetchUtil Top Channel extractor integration' do
  include_context 'extractor integration helpers'

  it 'generically preserves Top Channel article body and removes surrounding feeds' do
    expect_fixture_article(
      url: 'https://top-channel.tv/2026/07/07/festofsh-me-engjejt-atje-ku-je-edlira-cepani-publikon-foton-me-te-shoqin-e-ndjere-mesazhi-prekes-per-bogdanin-ne-diten-e-tij-te-lindjes/',
      fixture_path: File.expand_path('../fixtures/top_channel_article.html', __dir__),
      includes: [
        'Edlira Çepani ka kujtuar me një mesazh zemre bashkëshortin e saj të ndjerë',
        'Bogdani u nda nga jeta parakohe në vitin 2024'
      ],
      excludes: ['Sponsored', 'cookie', 'Më shumë', 'Lajmet e fundit'],
      warning_excludes: %w[empty_extraction short_extraction truncated_content url_content_mismatch consent_interstitial]
    )
  end
end
