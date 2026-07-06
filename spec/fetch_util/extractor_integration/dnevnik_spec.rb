# frozen_string_literal: true

RSpec.describe 'FetchUtil extractor integration' do
  include_context 'extractor integration helpers'

  it 'extracts Dnevnik article bodies without footer or false warning noise' do
    html = File.read(File.expand_path('../../fixtures/dnevnik_article.html', __dir__))

    url = 'https://www.dnevnik.bg/biznes/2026/07/06/4932760_sled_sreshta_mejdu_radev_i_erdogan_dogovorut_s_botash/'

    extract_from_url(url, html) do |payload|
      expect_content_type(payload, 'article')
      expect(payload['markdown']).to include('Договорът между "Булгаргаз" и турската държавна компания "Боташ" се замразява')
      expect(payload['markdown']).to include('Страната дължи по 500 хил. евро на ден')
      expect(payload['markdown']).not_to include('Дневник и Капитал са сертифицирани')
      expect(payload['markdown']).not_to include('Продължете да четете с пълен достъп')
      expect_warnings(payload, exclude: %w[url_content_mismatch paywall_partial_content empty_extraction short_extraction consent_interstitial])
      expect(payload['suspect']).to be(false)
    end
  end
end
