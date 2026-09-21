# frozen_string_literal: true

RSpec.describe 'FetchUtil extractor integration' do
  include_context 'extractor integration helpers'

  it "preserves every visible mobile Weibo status record in source order" do
    replies = Array.new(12) do |index|
      number = format("%02d", index + 1)
      <<~HTML
        <div class="card-wrap">
          <div class="card-main">
            <h4>回复标题 #{number}</h4>
            <p><a href="/profile/commenter-#{number}">评论者 #{number}</a><span>:</span><span>可见回复 #{number}</span></p>
          </div>
        </div>
      HTML
    end.join

    html = <<~HTML
      <html lang="zh-CN">
        <head>
          <title>微博</title>
          <meta property="og:site_name" content="m.weibo.cn">
        </head>
        <body>
          <main>
            <div class="card-wrap">
              <header class="weibo-top m-box">
                <div class="m-text-box">
                  <a href="/profile/6134393125"><h3 class="m-text-cut">Music_Data</h3></a>
                  <h4 class="m-text-cut"><span class="time">7-1 02:22</span><span class="from"> 来自 iPhone 16 Pro Max</span><span class="time">已编辑</span></h4>
                </div>
                <div class="m-add-box m-followBtn"><h4>关注</h4></div>
              </header>
            </div>
            <div class="card-wrap">
              <div class="weibo-og">
                 <div class="weibo-text">清晨的城市迎来一场小型音乐会，许多观众留言邀请乐队去自己的城市演出，现场气氛十分热烈。 演出结束后，主唱在评论区留言：“感谢大家的支持与建议。下次再见。”这是一段轻松的记录<span class="url-icon"><img alt="[泪]" src="https://face.t.sinajs.cn/t4/appstyle/expression/ext/normal/87/201810_lei_mobile.png"></span><br><br><a href="/search?containerid=100103type%3D1%26q%3D任素汐拒绝用女性对比拉踩">#今日舞台记录#</a></div>
                <div class="weibo-media-wraps weibo-media f-media media-b"><ul class="m-auto-list"><li><img src="https://wx3.sinaimg.cn/orj360/006H9hSBly1ieo6j378z1j30u01hc0ui.jpg"><span class="video-icon"></span></li></ul><span>00:35</span></div>
              </div>
            </div>
            #{replies}
          </main>
        </body>
      </html>
    HTML

    extract_from_url("https://m.weibo.cn/status/5315784902447884", html) do |payload|
      expect_content_type(payload, "social")
      expect(payload).to include("socialKind" => "post", "platform" => "Weibo", "handle" => "6134393125")
      expect(payload).to include("title" => "Music_Data", "byline" => "Music_Data")
      expect(payload["markdown"]).to include("Music\\_Data")
      expect(payload["markdown"]).to include("清晨的城市迎来一场小型音乐会")
      expect(payload["markdown"]).to include("#今日舞台记录#")
      expect(payload["markdown"]).to include("https://wx3.sinaimg.cn/orj360/006H9hSBly1ieo6j378z1j30u01hc0ui.jpg")
      expected_replies = Array.new(12) { |index| "可见回复 #{format("%02d", index + 1)}" }
      reply_positions = expected_replies.map { |reply| payload["markdown"].index(reply) }
      expect(payload["markdown"].scan(/可见回复 \d{2}/)).to eq(expected_replies)
      expect(reply_positions).to eq(reply_positions.sort)
      expect(payload["warnings"]).not_to include("multi_topic_page")
      expect_warnings(payload, exclude: %w[empty_extraction short_extraction url_content_mismatch consent_interstitial])
      expect(payload["suspect"]).to be(false)
    end
  end
end
