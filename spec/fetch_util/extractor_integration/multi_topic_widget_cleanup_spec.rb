# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'FetchUtil extractor integration - multi-topic widget cleanup' do
  include_context 'extractor integration helpers'

  it 'does not flag the UrduPoint live news page as a newsletter-style multi-topic page' do
    cards = 5.times.map do |i|
      <<~HTML
        <div class="story-card">
          <h3>Related update #{i + 1}</h3>
          <a href="/daily/latest-news/topic-#{i + 1}.html">Read more about topic #{i + 1}</a>
        </div>
      HTML
    end.join

    html = <<~HTML
      <html>
        <head>
          <title>سمندر میں لاپتا طیارے کی تازہ ترین خبر</title>
        </head>
        <body>
          <main>
            <article>
              <h1>سمندر میں لاپتا طیارے کی تازہ ترین خبر</h1>
              <p>یہ ایک ہی موضوع پر مبنی خبر ہے جس میں بنیادی تفصیل، پس منظر، اور ایک مسلسل رپورٹ شامل ہے۔</p>
              <p>مزید رپورٹنگ بھی اسی واقعے کی وضاحت کرتی ہے اور قاری کو ایک ہی قصے میں رکھتی ہے۔</p>
            </article>
          </main>
          <aside class="related-feed sidebar">
            #{cards}
          </aside>
        </body>
      </html>
    HTML

    with_url_page('https://www.urdupoint.com/daily/livenews/2026-07-07/news-4866441.html', html) do |page|
      payload = extract(page)

      expect_content_type(payload, 'article')
      expect(payload['contentFormat']).to be_nil
      expect(payload['warnings']).not_to include('multi_topic_page')
    end
  end

  it 'does not flag the Sakshi article as liveblog-style multi-topic content' do
    html = <<~HTML
      <html>
        <head>
          <title>నిజ్జర్‌ హత్య వెనుక లారెన్స్ బిష్ణోయ్ ముఠా?</title>
        </head>
        <body>
          <main>
            <article>
              <h1>నిజ్జర్‌ హత్య వెనుక లారెన్స్ బిష్ణోయ్ ముఠా?</h1>
              <p>ఇది ఒకే విషయంపై వచ్చిన వివరమైన కథనం. ప్రధాన అంశం, నేపథ్యం, మరియు దర్యాప్తు వివరాలు వరుసగా కొనసాగుతాయి.</p>
              <p>ఆ కథనంలో ఒకే నరేటివ్ కొనసాగుతుందే తప్ప వేరే బ్రేకింగ్ అప్డేట్ల సమాహారం కాదు.</p>
            </article>
          </main>
          <aside class="related_liveblog article-related-content">
            <div class="story-card liveblog">
              <h2>Related live update</h2>
              <time datetime="2026-07-08T07:50:00+05:30">07:50</time>
              <p>Background detail on the same story.</p>
            </div>
          </aside>
        </body>
      </html>
    HTML

    with_url_page('https://www.sakshi.com/telugu-news/international/us-charges-lawrence-bishnoi-goldy-brar-nijjar-assassination-2837548', html) do |page|
      payload = extract(page)

      expect_content_type(payload, 'article')
      expect(payload['contentFormat']).to be_nil
      expect(payload['warnings']).not_to include('multi_topic_page')
    end
  end

  it 'does not flag the Chosun court article as liveblog-style multi-topic content' do
    html = <<~HTML
      <html>
        <head>
          <title>교사가 초등학생에 “사기꾼”... 대법원은 ‘참교육’으로 봤다</title>
        </head>
        <body>
          <main>
            <article>
              <h1>교사가 초등학생에 “사기꾼”... 대법원은 ‘참교육’으로 봤다</h1>
              <p>이 기사는 한 사건을 중심으로 구성된 단일 기사이며, 본문은 계속 같은 맥락을 유지한다.</p>
              <p>중간에 섞인 관련 카드나 추천 영역은 본문이 아니라 주변 크롬이다.</p>
            </article>
          </main>
          <aside class="article-related-content sidebar">
            <div class="story-card liveblog">
              <h2>Related story</h2>
              <time datetime="2026-07-07T09:19:27.428Z">09:19</time>
              <p>More coverage on the same subject.</p>
            </div>
          </aside>
        </body>
      </html>
    HTML

    with_url_page('https://www.chosun.com/national/court_law/2026/07/07/WEYLMJRZ7FHYZGL3CF6COI7DPM/', html) do |page|
      payload = extract(page)

      expect_content_type(payload, 'article')
      expect(payload['contentFormat']).to be_nil
      expect(payload['warnings']).not_to include('multi_topic_page')
    end
  end

  it 'does not flag the Chosun sports article as liveblog-style multi-topic content' do
    html = <<~HTML
      <html>
        <head>
          <title>'아니 선발이 10K 인생투를 해버리네' 고우석 ML 데뷔전 내일로 미뤘다[SC 리뷰]</title>
        </head>
        <body>
          <main>
            <article>
              <h1>'아니 선발이 10K 인생투를 해버리네' 고우석 ML 데뷔전 내일로 미뤘다[SC 리뷰]</h1>
              <p>이 기사는 한 경기를 다루는 단일 기사이며, 본문은 계속 하나의 주제로 이어진다.</p>
              <p>주변의 관련 카드와 추천 영역은 본문이 아니라 추출 후 제거되어야 하는 주변 요소다.</p>
            </article>
          </main>
          <aside class="article-related-content sidebar">
            <div class="story-card liveblog">
              <h2>Related story</h2>
              <time datetime="2026-07-08T03:15:12.763Z">03:15</time>
              <p>More coverage on the same subject.</p>
            </div>
          </aside>
        </body>
      </html>
    HTML

    with_url_page('https://www.chosun.com/sports/world-baseball/2026/07/08/MQ3WIZLEGQ2WCZDDGI3TCMDGGI/', html) do |page|
      payload = extract(page)

      expect_content_type(payload, 'article')
      expect(payload['contentFormat']).to be_nil
      expect(payload['warnings']).not_to include('multi_topic_page')
    end
  end
end
