# frozen_string_literal: true

RSpec.describe 'FetchUtil Yle live extractor integration' do
  include_context 'extractor integration helpers'

  it 'extracts only the selected Yle live article item' do
    expect_fixture_article(
      url: 'https://yle.fi/a/74-20235117/64-3-304362',
      fixture_path: File.expand_path('../../fixtures/yle_live_article.html', __dir__),
      includes: [
        'Trump on saapunut Ankaraan',
        'Yhdysvaltain presidentti Donald Trump on saapunut Turkin pääkaupunkiin Ankaraan',
        'Lähde: Reuters'
      ],
      excludes: ['Rutte: Naton ja EU:n tiivistettävä yhteistyötä', 'Yle seuraa tiistaina alkavaa Nato-kokousta', 'Videosoitin'],
      warning_excludes: %w[multi_topic_page empty_extraction short_extraction url_content_mismatch consent_interstitial]
    )
  end
end
