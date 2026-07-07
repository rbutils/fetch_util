# frozen_string_literal: true

RSpec.describe 'FetchUtil Kurir article extraction' do
  include_context 'extractor integration helpers'

  it 'extracts Kurir article bodies without tracking-link feed noise or mismatch warnings' do
    expect_fixture_article(
      url: 'https://www.kurir.rs/techvision/vesti/10040514/kako-prepoznati-i-ukloniti-laznu-ekstenziju-iz-chrome-a',
      fixture_path: File.expand_path('../../fixtures/kurir_article.html', __dir__),
      includes: [
        'U slučaju da imate instaliranu Perplexity AI ekstenziju',
        'Prevaru su otkrili bezbednosni stručnjaci iz Majkrosoftovog tima za pretnje'
      ],
      excludes: [
        'cdn2.midas-network.com/api/click/article',
        'Hitno je obrišite!',
        'Komentariši'
      ],
      warning_excludes: %w[empty_extraction short_extraction truncated_content url_content_mismatch consent_interstitial]
    )
  end
end
