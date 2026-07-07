# frozen_string_literal: true

RSpec.describe 'FetchUtil Daryo extractor integration' do
  include_context 'extractor integration helpers'

  it 'extracts Daryo article bodies without source or comments chrome' do
    # Daryo's profile scopes the post body while dropping source/share/comment chrome.
    expect_fixture_article(
      url: 'https://daryo.uz/2026/07/07/kuniga-bir-marta-qozogistonda-transport-vositalari-kirishiga-cheklov-ornatildi',
      fixture_path: File.expand_path('../../fixtures/daryo_article.html', __dir__),
      includes: [
        'Qozog‘iston yonilg‘i-moylash materiallarining chegaradan noqonuniy olib chiqib ketilishining oldini olish',
        'Vazir o‘rinbosarining so‘zlariga ko‘ra'
      ],
      excludes: ['Manba: Tengrinews', 'Izoh qoldirish uchun'],
      warning_excludes: %w[empty_extraction short_extraction url_content_mismatch consent_interstitial]
    )
  end
end
