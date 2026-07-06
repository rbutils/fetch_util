# frozen_string_literal: true

RSpec.describe 'FetchUtil NetEase News extractor integration' do
  include_context 'extractor integration helpers'

  it 'extracts 163.com article bodies without related recommendation lists' do
    html = <<~HTML
      <html lang="zh-CN">
        <head>
          <title>中国海军成功组织潜射战略导弹试射</title>
          <meta property="og:site_name" content="网易新闻">
          <meta name="description" content="中国海军1艘战略核潜艇成功发射1发携载训练模拟弹头的潜射战略导弹。">
        </head>
        <body>
          <div class="post_main">
            <h1 class="post_title">中国海军成功组织潜射战略导弹试射</h1>
            <div class="post_info">2026-07-06 18:09:22 来源: 央视新闻客户端 北京</div>
            <div class="post_content" id="content">
              <a class="post_top_tie_count" href="https://comment.tie.163.com/L162R68C0001899O.html">2948</a>
              <div class="post_top_share"><span class="post_top_share_title">分享至</span></div>
              <div class="post_body">
                <p>（原标题：中国海军成功组织潜射战略导弹试射）</p>
                <p>导弹出水瞬间</p>
                <p>7月6日12时01分，中国海军1艘战略核潜艇成功发射1发携载训练模拟弹头的潜射战略导弹，准确落入预定海域。</p>
                <p>此次发射训练检验了武器装备性能，达到了预期目的。</p>
                <p>图为导弹发射升空，现场组织严密，海空安全态势保持稳定。</p>
                <p>本文来源：央视新闻客户端 责任编辑：王晓易</p>
              </div>
              <div id="tie" class="tie-area"><h3>网易跟贴</h3><p>跟贴 191 参与 2948</p></div>
              <div class="post_recommends js-tab-mod">
                <div class="post_recommends_titles">
                  <div class="post_recommends_title active">相关推荐</div>
                  <div class="post_recommends_title">热点推荐</div>
                </div>
                <ul class="post_recommends_list">
                  <li class="post_recommend"><h3><a href="https://www.163.com/v/video/VW08JOD62.html">佩斯科夫：试射导弹是中国的主权权利中国不会对任何国家造成威胁</a></h3></li>
                  <li class="post_recommend"><h3><a href="https://www.163.com/v/video/VW08SCVUU.html">大胆开麦：乌外长称乌克兰需要全球数千枚爱国者储备导弹</a></h3></li>
                </ul>
              </div>
            </div>
          </div>
        </body>
      </html>
    HTML

    url = 'https://www.163.com/news/article/L162R68C0001899O.html'

    extract_from_url(url, html) do |payload|
      expect_content_type(payload, 'article')
      expect(payload['markdown']).to include('中国海军1艘战略核潜艇成功发射1发携载训练模拟弹头的潜射战略导弹')
      expect(payload['markdown']).to include('此次发射训练检验了武器装备性能')
      expect(payload['markdown']).not_to include('相关推荐')
      expect(payload['markdown']).not_to include('热点推荐')
      expect(payload['markdown']).not_to include('佩斯科夫：试射导弹')
      expect(payload['markdown']).not_to include('网易跟贴')
      expect_warnings(payload, exclude: %w[empty_extraction short_extraction url_content_mismatch consent_interstitial])
    end
  end
end
