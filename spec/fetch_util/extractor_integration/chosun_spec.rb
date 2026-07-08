# frozen_string_literal: true

RSpec.describe 'FetchUtil Chosun extractor integration' do
  include_context 'extractor integration helpers'

  let(:court_html) do
    <<~HTML
      <html lang="ko">
        <head>
          <title>교사가 초등학생에 사기꾼... 대법원은 참교육으로 봤다 | 조선일보</title>
          <meta property="og:site_name" content="조선일보">
          <meta property="article:content_tier" content="premium">
          <script type="application/ld+json">
            {"@context":"https://schema.org","@type":"NewsArticle","headline":"교사가 초등학생에 사기꾼... 대법원은 참교육으로 봤다","isAccessibleForFree":"False"}
          </script>
        </head>
        <body>
          <main>
            <article>
              <h1>교사가 초등학생에 사기꾼... 대법원은 참교육으로 봤다</h1>
              <p class="byline">김나영 기자</p>
              <p>대법원은 교사의 발언이 단순한 모욕이 아니라 학생을 지도하는 과정에서 나온 훈계의 성격이 강하다고 봤다. 재판부는 사건의 전후 맥락과 학생의 행동을 함께 살폈고, 교실 안에서 벌어진 긴장과 오해를 분리해서 검토했다.</p>
              <p>판결문에는 발언이 이루어진 상황, 피해 학생과 교사의 관계, 그리고 당시 학교 현장에서 벌어진 혼란이 비교적 길게 정리돼 있다. 공개된 기사 본문만으로도 사건의 핵심 쟁점은 충분히 이해되며, 독자는 사실관계와 판단 근거를 따라갈 수 있다.</p>
              <p>재판부는 교사가 폭언이나 물리적 가해를 한 정황은 없었고, 문제의 표현 역시 전체적인 교육적 상황 속에서 판단해야 한다고 설명했다. 이 판단은 교권과 아동 보호의 경계를 둘러싼 논쟁으로 이어졌고, 이후 유사 사건의 기준에도 영향을 미쳤다.</p>
              <p>기사 본문은 1심과 2심의 판단 차이, 대법원의 시각, 그리고 교육적 지도와 인권 보호 사이의 균형이라는 질문까지 담고 있다. 따라서 외부의 안내가 없어도 기사 자체는 충분히 완결적이다.</p>
            </article>
            <section class="article-related-content">
              <h2>관련기사</h2>
              <div class="story-card">교권 논란을 다룬 다른 기사</div>
            </section>
            <aside class="story-card">
              <p>추천기사: 조선일보 교육 이슈</p>
            </aside>
          </main>
        </body>
      </html>
    HTML
  end

  let(:sports_html) do
    <<~HTML
      <html lang="ko">
        <head>
          <title>'아니 선발이 10K 인생투를 해버리네' 고우석 ML 데뷔전 내일로 미뤘다[SC 리뷰] | 조선일보</title>
          <meta property="og:site_name" content="조선일보">
          <meta property="article:content_tier" content="premium">
          <script type="application/ld+json">
            {"@context":"https://schema.org","@type":"NewsArticle","headline":"'아니 선발이 10K 인생투를 해버리네' 고우석 ML 데뷔전 내일로 미뤘다[SC 리뷰]","isAccessibleForFree":"False"}
          </script>
        </head>
        <body>
          <main>
            <article>
              <h1>'아니 선발이 10K 인생투를 해버리네' 고우석 ML 데뷔전 내일로 미뤘다[SC 리뷰]</h1>
              <p class="byline">스포츠조선</p>
              <p>고우석은 메이저리그 첫 등판을 앞두고 팀에 합류했지만, 경기 흐름과 선발 투수의 호투 때문에 마운드에 오를 기회를 얻지 못했다. 팬들은 데뷔전을 하루 더 기다리게 됐고, 현장 분위기도 기대와 아쉬움이 함께 섞였다.</p>
              <p>미네소타는 접전 속에서도 선발진과 불펜 운용으로 경기를 정리했고, 고우석은 로스터에 등록된 뒤에도 여유 있는 상황을 기다리는 입장이 됐다. 공개된 본문은 경기 요약과 로스터 이동 배경, 그리고 교체 사정까지 충분히 담고 있다.</p>
              <p>기사 말미에는 빅리그 데뷔가 최소 하루 밀렸다는 점과 앞으로의 등판 가능성이 정리된다. 이 흐름만 따라가도 독자는 왜 등판이 미뤄졌는지, 다음 기회가 어떤 조건에서 열릴지 이해할 수 있다.</p>
              <p>결국 이 페이지는 경기 결과와 선수의 데뷔 일정이라는 두 축이 모두 드러나는 완결된 기사다. 본문은 경기의 맥락을 이해하는 데 필요한 정보만 담고 있다.</p>
            </article>
            <section class="article-related-content">
              <h2>관련기사</h2>
              <div class="story-card">고우석 관련 다른 기사</div>
            </section>
            <aside class="story-card">
              <p>추천기사: 메이저리그 소식</p>
            </aside>
          </main>
        </body>
      </html>
    HTML
  end

  it 'extracts the public Chosun court article without false paywall or multi-topic warnings' do
    extract_from_url(
      'https://www.chosun.com/national/court_law/2026/07/07/WEYLMJRZ7FHYZGL3CF6COI7DPM/',
      court_html
    ) do |payload|
      expect_content_type(payload, 'article')
      expect(payload['markdown']).to include('대법원은 교사의 발언이 단순한 모욕이 아니라 학생을 지도하는 과정에서 나온 훈계의 성격이 강하다고 봤다')
      expect(payload['markdown']).not_to include('관련기사')
      expect(payload['markdown']).not_to include('추천기사')
      expect_warnings(payload, exclude: %w[multi_topic_page paywall_partial_content empty_extraction short_extraction url_content_mismatch consent_interstitial])
    end
  end

  it 'extracts the public Chosun sports article without false paywall or multi-topic warnings' do
    extract_from_url(
      'https://www.chosun.com/sports/world-baseball/2026/07/08/MQ3WIZLEGQ2WCZDDGI3TCMDGGI/',
      sports_html
    ) do |payload|
      expect_content_type(payload, 'article')
      expect(payload['markdown']).to include('고우석은 메이저리그 첫 등판을 앞두고 팀에 합류했지만')
      expect(payload['markdown']).not_to include('관련기사')
      expect(payload['markdown']).not_to include('추천기사')
      expect_warnings(payload, exclude: %w[multi_topic_page paywall_partial_content empty_extraction short_extraction url_content_mismatch consent_interstitial])
    end
  end
end
