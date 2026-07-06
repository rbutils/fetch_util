# frozen_string_literal: true

RSpec.describe 'FetchUtil extractor integration for SegmentFault articles' do
  include_context 'extractor integration helpers'

  it 'classifies SegmentFault article pages as articles instead of lists' do
    html = <<~HTML
      <html lang="zh-CN">
        <head>
          <title>记录ChatGPT 因为 Cyber Abuse 莫名其妙被封号的解封方案 - SegmentFault 思否</title>
          <meta property="og:site_name" content="SegmentFault 思否">
          <meta name="description" content="记录一次账号封禁和恢复过程。">
        </head>
        <body>
          <nav>
            <a href="/questions">问答</a>
            <a href="/blogs">博客</a>
            <a href="/news">资讯</a>
            <a href="/tags">标签</a>
          </nav>
          <main>
            <h1>记录ChatGPT 因为 Cyber Abuse 莫名其妙被封号的解封方案，以及解封后 Pro 会员消失的真相</h1>
            <div class="article-author"><a href="/u/example">示例作者</a></div>
            <aside>
              <a href="/a/1190000047950203">Apache Doris Python UDF：让 SQL 直接调用 Python 生态</a>
              <a href="/a/1190000047947445">SeaTunnel 2.3.11 用 Docker 部署，实现 Kafka 同步 Hive</a>
            </aside>
            <article class="article fmt article-content ">
              <p>记录ChatGPT 因为 Cyber Abuse 莫名其妙被封号的解封方案，以及解封后 Pro 会员消失的真相</p>
              <p>事先声明，用的 ChatGPT 账号不是乱买来的，而是我自己的从 2023 年用到现在的，这次突然封号，让我感到莫名其妙！</p>
              <p>在 6.19 号，我先收到了一个警告邮件，说我 Cyber Abuse 网络滥用，但是这个邮箱我平常不看，不知道这回事。</p>
              <p>直到 6.27 我发现 ChatGPT 被退出登录，再重新登录说账号不存在，我就懵了。</p>
              <p>打开我的 outlook 邮箱一看，收到了封号的邮件，原因还是「Cyber Abuse 网络滥用」。</p>
              <p>去查了一下，没人说清楚这个 Cyber Abuse 是什么，只能按官方申诉流程补充说明。</p>
              <p>最后账号解封后，Pro 会员没有立刻恢复，需要继续联系账单支持确认订阅状态。</p>
            </article>
            <section class="comments"><p>评论内容不属于正文。</p></section>
          </main>
        </body>
      </html>
    HTML

    extract_from_url('https://segmentfault.com/a/1190000047942575', html) do |payload|
      expect_content_type(payload, 'article')
      expect(payload['markdown']).to include('事先声明，用的 ChatGPT 账号不是乱买来的')
      expect(payload['markdown']).to include('Pro 会员没有立刻恢复')
      expect(payload['markdown']).not_to include('Apache Doris Python UDF')
      expect(payload['markdown']).not_to include('评论内容不属于正文')
      expect_warnings(payload, exclude: %w[empty_extraction short_extraction url_content_mismatch consent_interstitial])
    end
  end
end
