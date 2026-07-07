# frozen_string_literal: true

RSpec.describe 'FetchUtil extractor integration' do
  include_context 'extractor integration helpers'

  it 'extracts Dnevnik article bodies without footer or false warning noise' do
    expect_fixture_article(
      url: 'https://www.dnevnik.bg/biznes/2026/07/06/4932760_sled_sreshta_mejdu_radev_i_erdogan_dogovorut_s_botash/',
      fixture_path: File.expand_path('../../fixtures/dnevnik_article.html', __dir__),
      includes: [
        'Договорът между "Булгаргаз" и турската държавна компания "Боташ" се замразява',
        'Страната дължи по 500 хил. евро на ден'
      ],
      excludes: ['Дневник и Капитал са сертифицирани', 'Продължете да четете с пълен достъп'],
      warning_excludes: %w[url_content_mismatch paywall_partial_content empty_extraction short_extraction consent_interstitial]
    )
  end
end
