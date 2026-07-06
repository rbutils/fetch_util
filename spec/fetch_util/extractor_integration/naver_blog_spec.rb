# frozen_string_literal: true

require 'cgi'

RSpec.describe 'FetchUtil Naver Blog extractor integration' do
  include_context 'extractor integration helpers'

  def naver_blog_post_frame_html
    <<~HTML
      <html>
        <head>
          <title>강화 바다다 캠핑장 2박 3일 후기 여름 오토.. : 네이버블로그</title>
        </head>
        <body>
          <iframe id="mainFrame" name="mainFrame" src="/PostView.naver?blogId=vlrmb1&amp;logNo=224319180884" srcdoc="#{CGI.escapeHTML(naver_blog_post_view_html)}"></iframe>
        </body>
      </html>
    HTML
  end

  def naver_blog_post_view_html
    <<~HTML
      <html>
        <head>
          <title>강화 바다다 캠핑장 2박 3일 후기 여름 오토캠핑은 여기!</title>
        </head>
        <body>
          <div id="blog-menu">프롤로그 블로그 지도 서재 메모 안부</div>
          <div class="se-module se-module-text se-title-text">
            <span>강화 바다다 캠핑장 2박 3일 후기 여름 오토캠핑은 여기!</span>
          </div>
          <span class="nick">멜팅리미</span>
          <div class="se-main-container">
            <div class="se_component_wrap">
              <p>안녕하세요. 작은 행복들을 찾아 떠나는 ‘멜팅리미’ 입니다.</p>
              <blockquote>7월 여름 오토캠핑의 묘미 강화 바다다 캠핑장 2박 3일 힐링 여행 시작</blockquote>
              <p>오늘은 작년 7월 푸르른 여름날 다녀왔던 강화 바다다 캠핑장에서의 2박 3일 캠핑 기록을 드디어 꺼내보려고 합니다.</p>
              <p>오토캠핑만의 설렘은 언제 겪어도 참 기분이 좋은 것 같아요.</p>
            </div>
            <div class="post_btn">공감 댓글 공유하기</div>
          </div>
        </body>
      </html>
    HTML
  end

  it 'extracts article content from the rendered Naver Blog mainFrame iframe' do
    extract_from_url('https://blog.naver.com/vlrmb1/224319180884', naver_blog_post_frame_html) do |payload|
      expect_content_type(payload, 'article')
      expect(payload['markdown']).to include('# 강화 바다다 캠핑장 2박 3일 후기 여름 오토캠핑은 여기!')
      expect(payload['markdown']).to include('작은 행복들을 찾아 떠나는')
      expect(payload['markdown']).to include('강화 바다다 캠핑장 2박 3일 힐링 여행 시작')
      expect(payload['markdown']).not_to include('공감 댓글 공유하기')
      expect_warnings(payload, exclude: %w[empty_extraction short_extraction url_content_mismatch])
    end
  end

  it 'also extracts direct PostView URLs' do
    extract_from_url('https://blog.naver.com/PostView.naver?blogId=vlrmb1&logNo=224319180884', naver_blog_post_view_html) do |payload|
      expect_content_type(payload, 'article')
      expect(payload['markdown']).to include('오토캠핑만의 설렘')
      expect_warnings(payload, exclude: %w[empty_extraction short_extraction url_content_mismatch])
    end
  end
end
