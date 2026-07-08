# frozen_string_literal: true

RSpec.describe 'FetchUtil YNA extractor integration' do
  include_context 'extractor integration helpers'

  it 'extracts YNA /view/AKR article pages as articles instead of lists' do
    expect_fixture_article(
      url: 'https://www.yna.co.kr/view/AKR20260708017500004',
      fixture_path: File.expand_path('../../fixtures/yna_article.html', __dir__),
      includes: [
        '(서울=연합뉴스) 정준영 기자',
        '서울 양천구(구청장 이기재)는 공공형 실내놀이터인 서울형 키즈카페 신월7동점이 개관했다고 8일 밝혔다.',
        '이용 대상은 서울시에 거주하는 0∼6세 영유아다.'
      ],
      excludes: %w[
        프리미엄뉴스
        인터넷맞춤형
      ],
      warning_excludes: %w[empty_extraction short_extraction url_content_mismatch multi_topic_page consent_interstitial],
      suspect: false
    )
  end
end
