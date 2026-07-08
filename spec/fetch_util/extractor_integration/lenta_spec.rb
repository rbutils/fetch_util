# frozen_string_literal: true

RSpec.describe 'FetchUtil Lenta extractor integration' do
  include_context 'extractor integration helpers'

  it 'extracts Lenta articles without short_extraction warnings' do
    expect_fixture_article(
      url: 'https://lenta.ru/news/2026/07/08/v-ssha-nazvali-nakazaniem-ataku-na-iran/',
      fixture_path: File.expand_path('../../fixtures/lenta_article.html', __dir__),
      includes: [
        'Атаки на [Иран](',
        'Это наказание. Это будет продолжатся некоторое время',
        'Ранее Центральное командование ВС США (CENTCOM) [сообщило]('
      ],
      excludes: %w[Главная Новости Реклама],
      warning_excludes: %w[empty_extraction short_extraction url_content_mismatch consent_interstitial]
    )
  end
end
