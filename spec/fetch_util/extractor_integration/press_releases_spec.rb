# frozen_string_literal: true

RSpec.describe 'FetchUtil press release extraction' do
  include_context 'extractor integration helpers'

  it 'extracts PR Newswire release bodies instead of category lists or repost warnings' do
    html = fixture_contents(File.expand_path('../../fixtures/prnewswire_press_release.html', __dir__))

    extract_from_url('https://www.prnewswire.com/news-releases/example-robotics-announces-new-fleet-platform-302500001.html', html) do |payload|
      expect_content_type(payload, 'press_release')
      expect(payload['markdown']).to include('Example Robotics release fixture: a depot board groups robot')
      expect(payload['markdown']).to include('Example Robotics labels the synthetic platform')
      expect(payload['markdown']).not_to include('Other Company Announces Update')
      expect(payload['warnings']).not_to include('syndicated_repost')
      expect(payload['warnings']).not_to include('stale_content')
    end
  end

  it 'keeps Google company-news articles as body content instead of category lists' do
    html = fixture_contents(File.expand_path('../../fixtures/google_company_news_article.html', __dir__))

    extract_from_url('https://blog.google/company-news/google-shares-new-tools-for-small-businesses/', html) do |payload|
      expect_content_type(payload, 'article')
      expect(payload['markdown']).to include('Google company-news fixture: a sample merchant workspace')
      expect(payload['markdown']).to include('The synthetic controls enter a staged regional rollout')
      expect(payload['markdown']).not_to include('Search update expands')
    end
  end

  it 'classifies strong corporate newsroom releases as press releases without stale warnings' do
    html = fixture_contents(File.expand_path('../../fixtures/apple_newsroom_press_release.html', __dir__))

    extract_from_url('https://www.apple.com/newsroom/2021/05/apple-introduces-new-accessibility-features/', html) do |payload|
      expect_content_type(payload, 'press_release')
      expect(payload['markdown']).to include('Apple accessibility fixture: the sample release groups mobility')
      expect(payload['warnings']).not_to include('stale_content')
      expect(payload['warnings']).not_to include('multi_topic_page')
    end
  end

  it 'extracts Amazon Freight newsroom article bodies' do
    html = fixture_contents(File.expand_path('../../fixtures/amazon_freight_newsroom_article.html', __dir__))

    extract_from_url('https://freight.amazon.com/newsroom/amazon-freight-expands-shipping-options', html) do |payload|
      expect_content_type(payload, 'press_release')
      expect(payload['markdown']).to include('Amazon Freight announced a synthetic lane-record update')
      expect(payload['markdown']).to include('A portal workflow exposes booking')
      expect(payload['warnings']).not_to include('stale_content')
    end
  end

  it 'does not bypass Business Wire access walls' do
    html = <<~HTML
      <html>
        <head><title>Access Error</title></head>
        <body><main><h1>Access Error</h1><p>The request was declined before the page could load.</p></main></body>
      </html>
    HTML

    extract_from_url('https://www.businesswire.com/news/home/20260709000001/en/example-release', html) do |payload|
      expect_content_type(payload, 'interstitial')
      expect(payload['warnings']).to include('access_error_interstitial')
      expect(payload['markdown']).to include('Access Error')
    end
  end

  it 'leaves a dated press release index to generic list extraction' do
    html = <<~HTML
      <html><head><title>Press releases</title></head><body><main><h1>Press releases</h1>
        <article class="release"><a href="/news/one">Launches new service</a><time>July 1, 2026</time></article>
        <article class="release"><a href="/news/two">Reports results</a><time>July 2, 2026</time></article>
        <article class="release"><a href="/news/three">Announces expansion</a><time>July 3, 2026</time></article>
        <article class="release"><a href="/news/four">Opens new office</a><time>July 4, 2026</time></article>
      </main></body></html>
    HTML

    extract_from_url('https://news.example.test/press-releases', html) do |payload|
      expect_content_type(payload, 'list')
      expect(payload['markdown']).to include('Launches new service')
      expect(payload['markdown']).not_to include('Price:')
    end
  end
end
