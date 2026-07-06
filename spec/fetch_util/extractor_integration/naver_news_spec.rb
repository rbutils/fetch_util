# frozen_string_literal: true

RSpec.describe 'FetchUtil Naver News extractor integration' do
  include_context 'extractor integration helpers'

  it 'extracts the Naver News article body without logo or related-news lists' do
    html = <<~HTML
      <html lang="ko">
        <head>
          <title>[속보] 삼성전자 2분기 영업이익 89.4조… 작년 대비 1810.3%↑</title>
          <meta property="og:site_name" content="네이버 뉴스">
          <meta name="description" content="삼성전자가 올해 2분기 89조4000억원의 영업이익을 기록했다.">
        </head>
        <body>
          <header class="Ngnb"><a>뉴스</a><a>연예</a><a>스포츠</a></header>
          <aside class="rankingnews">
            <h2>많이 본 뉴스</h2>
            <a href="/article/999/000000001">대통령실 오늘의 주요뉴스</a>
            <a href="/article/999/000000002">네이버 로고 뉴스 목록</a>
          </aside>
          <main id="ct">
            <h1 class="media_end_head_title">[속보] 삼성전자 2분기 영업이익 89.4조… 작년 대비 1810.3%↑</h1>
            <div class="media_end_head_journalist_name">국민일보</div>
            <div id="newsctArticle" class="newsct_article">
              <article id="dic_area">
                삼성전자가 올해 2분기 89조4000억원의 영업이익을 기록하며 3분기 연속 역대 최대 실적 기록을 이어갔다.
                <span class="end_photo_org"><img src="https://imgnews.pstatic.net/image/005/2026/07/07/samsung.jpg" alt="서울 삼성전자 서초사옥. 연합뉴스"></span>
                <em class="img_desc">서울 삼성전자 서초사옥. 연합뉴스</em>
                <p>삼성전자는 연결 기준 올해 2분기 영업이익이 89조4000억원으로 지난해 동기보다 1810.3% 증가한 것으로 잠정 집계됐다고 7일 공시했다.</p>
                <p>매출은 171조원으로 작년 동기 대비 129.3% 증가했다.</p>
                <p>반도체 공급 부족과 메모리 가격 강세가 심화한 영향으로 풀이된다.</p>
                <div class="media_end_linked_more"><a>함께 볼만한 뉴스</a></div>
                <div class="u_cbox">댓글 128</div>
                <div class="media_end_head_share">공유하기</div>
              </article>
            </div>
          </main>
        </body>
      </html>
    HTML

    extract_from_url('https://n.news.naver.com/article/005/0001859382', html) do |payload|
      expect_content_type(payload, 'article')
      expect(payload['markdown']).to include('삼성전자가 올해 2분기 89조4000억원의 영업이익')
      expect(payload['markdown']).to include('반도체 공급 부족과 메모리 가격 강세')
      expect(payload['markdown']).not_to include('대통령실 오늘의 주요뉴스')
      expect(payload['markdown']).not_to include('네이버 로고 뉴스 목록')
      expect(payload['markdown']).not_to include('함께 볼만한 뉴스')
      expect(payload['markdown']).not_to include('댓글 128')
      expect_warnings(payload, exclude: %w[empty_extraction short_extraction url_content_mismatch consent_interstitial])
    end
  end
end
