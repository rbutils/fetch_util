# frozen_string_literal: true

RSpec.describe 'FetchUtil Milliyet live extractor integration' do
  include_context 'extractor integration helpers'

  it 'extracts Milliyet live article bodies without false multi-topic warnings' do
    expect_fixture_article(
      url: 'https://www.milliyet.com.tr/dunya/live-tarihi-nato-zirvesi-basladi-trump-ankarada-7618835',
      fixture_path: File.expand_path('../../fixtures/milliyet_live_article.html', __dir__),
      includes: ['Tarihi NATO Zirvesi başladı', 'ABD Başkanı Trump Ankara Havalimanı', 'Milli Savunma Bakanı Yaşar Güler'],
      excludes: ['Günün en çok okunanları'],
      warning_excludes: %w[multi_topic_page empty_extraction short_extraction url_content_mismatch consent_interstitial]
    )
  end
end
