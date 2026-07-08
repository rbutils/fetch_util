# frozen_string_literal: true

RSpec.describe 'FetchUtil extractor integration' do
  include_context 'extractor integration helpers'

  it 'extracts Walla articles without multi-topic false positives' do
    expect_fixture_article(
      url: 'https://news.walla.co.il/item/3851857',
      fixture_path: File.expand_path('../../fixtures/walla_article.html', __dir__),
      includes: [
        'במהלך פסגת נאט"ו באנקרה',
        'אם ארה"ב תתקוף שוב - נסגור את מצר הורמוז'
      ],
      excludes: ['עוד באותו נושא:'],
      warning_excludes: %w[multi_topic_page]
    )
  end
end
