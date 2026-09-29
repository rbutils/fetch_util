# frozen_string_literal: true

RSpec.describe 'FetchUtil extractor integration' do
  include_context 'extractor integration helpers'

  it 'extracts Walla articles with topical links and without multi-topic false positives' do
    expect_fixture_article(
      url: 'https://news.walla.co.il/item/3851857',
      fixture_path: File.expand_path('../../fixtures/walla_article.html', __dir__),
      includes: [
        'במהלך פסגת נאט"ו באנקרה',
        'אם ארה"ב תתקוף שוב - נסגור את מצר הורמוז',
        'עוד באותו נושא:',
        'https://tags.walla.co.il/%D7%93%D7%95%D7%A0%D7%9C%D7%93_%D7%98%D7%A8%D7%90%D7%9E%D7%A4',
        'https://tags.walla.co.il/%D7%A0%D7%90%D7%98%22%D7%95',
        'https://tags.walla.co.il/%D7%90%D7%99%D7%A8%D7%90%D7%9F',
        'https://tags.walla.co.il/%D7%94%D7%9E%D7%96%D7%A8%D7%97_%D7%94%D7%AA%D7%99%D7%9B%D7%95%D7%9F',
        'https://tags.walla.co.il/%D7%A1%D7%A4%D7%A8%D7%93'
      ],
      excludes: [],
      warning_excludes: %w[multi_topic_page empty_content short_content url_content_mismatch],
      suspect: true
    )
  end
end
