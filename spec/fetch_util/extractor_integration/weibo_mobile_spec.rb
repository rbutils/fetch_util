# frozen_string_literal: true

RSpec.describe 'FetchUtil extractor integration' do
  include_context 'extractor integration helpers'

  it "extracts a mobile Weibo status instead of comments" do
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
                <div class="weibo-text">任素汐演唱会在下沉市场口碑爆棚，不少网友纷纷邀请她去自己城市开演唱会，与此前的谢娜的风评形成了两个极端，不少官媒点评任素汐才是跨界演唱会的正确范例。 此后任素汐在评论区留言：“希望大家不要用表扬一位女性去诋毁另一位女性。务必。谢谢。”姐真的是特别好的一个人<span class="url-icon"><img alt="[泪]" src="https://face.t.sinajs.cn/t4/appstyle/expression/ext/normal/87/201810_lei_mobile.png"></span><br><br><a href="/search?containerid=100103type%3D1%26q%3D任素汐拒绝用女性对比拉踩">#任素汐拒绝用女性对比拉踩#</a></div>
                <div class="weibo-media-wraps weibo-media f-media media-b"><ul class="m-auto-list"><li><img src="https://wx3.sinaimg.cn/orj360/006H9hSBly1ieo6j378z1j30u01hc0ui.jpg"><span class="video-icon"></span></li></ul><span>00:35</span></div>
              </div>
            </div>
            <div class="card-wrap">
              <div class="card-main">
                <h4>不能说的秘密你教我怎么说</h4>
                <h3>她只是在影视方面特别的突出，唱歌并不算跨界。驴得水的时候那首《我要你》就算出道糊坛了。</h3>
                <p><a>喵巨富</a><span>:</span><span>电影院的音响听她清唱我要你绝了</span></p>
              </div>
            </div>
            <div class="card-wrap">
              <div class="card-main">
                <h4>不一样的美男子11111</h4>
                <h3>任素汐没有跨界，她的歌基本上都是自己写的或者是自己创作的。</h3>
              </div>
            </div>
          </main>
        </body>
      </html>
    HTML

    extract_from_url("https://m.weibo.cn/status/5315784902447884", html) do |payload|
      expect_content_type(payload, "article")
      expect(payload["markdown"]).to include("# Music_Data - 微博正文")
      expect(payload["markdown"]).to include("任素汐演唱会在下沉市场口碑爆棚")
      expect(payload["markdown"]).to include("#任素汐拒绝用女性对比拉踩#")
      expect(payload["markdown"]).not_to include("不能说的秘密你教我怎么说")
      expect(payload["markdown"]).not_to include("电影院的音响听她清唱我要你绝了")
      expect(payload["warnings"]).not_to include("multi_topic_page")
      expect_warnings(payload, exclude: %w[empty_extraction short_extraction url_content_mismatch consent_interstitial])
      expect(payload["suspect"]).to be(false)
    end
  end
end
