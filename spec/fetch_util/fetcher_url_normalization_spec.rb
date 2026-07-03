# frozen_string_literal: true

require 'spec_helper'

RSpec.describe FetchUtil::Fetcher do
  include_context 'fetcher spec helpers'

  it 'normalizes challenge and tracking query params from result urls' do
    challenge_url = 'https://www.freedesktop.org/software/systemd/man/latest/systemd.service.html'
    challenge_current_url = "#{challenge_url}?__goaway_challenge=meta-refresh&__goaway_id=abc123&utm_source=test"
    challenge_canonical_url = "#{challenge_url}?__goaway_challenge=meta-refresh&__goaway_id=abc123"
    challenge_page = page_at(challenge_current_url)
    challenge_payload = payload_with(
      canonicalUrl: challenge_canonical_url,
      title: 'systemd.service'
    )

    stub_browser_extraction(challenge_url, page: challenge_page, payload: challenge_payload)

    result = fetch_with_dependencies(challenge_url)

    expect(result.final_url).to eq(challenge_url)
    expect(result.canonical_url).to eq(challenge_url)
    expect(result.metadata[:content_url]).to eq(challenge_url)
  end

  it 'normalizes Digi24-style gr tracking query params from result urls' do
    tracked_url = 'https://www.digi24.ro/'
    tracked_query = '?__grsc=cookieIsUndef0&__grts=59151633&__grua=06b4a7e6274c16710a1f6ac7ae09eff9&__grrn=1'
    tracked_page = page_at("#{tracked_url}#{tracked_query}")
    tracked_payload = payload_with(
      canonicalUrl: "#{tracked_url}#{tracked_query}",
      title: 'Digi24 - Stiri - Informația la putere!',
      contentType: 'list',
      warnings: ['homepage_index_page']
    )

    stub_browser_extraction(tracked_url, page: tracked_page, payload: tracked_payload)

    result = fetch_with_dependencies(tracked_url)

    expect(result.final_url).to eq(tracked_url)
    expect(result.canonical_url).to eq(tracked_url)
    expect(result.metadata[:content_url]).to eq(tracked_url)
  end

  it 'preserves instagram next redirect targets when the current session is bounced to login' do
    login_url = 'https://www.instagram.com/accounts/login/?next=%2Fcristiano%2F&utm_source=ig_web'
    normalized_login_url = 'https://www.instagram.com/accounts/login/?next=%2Fcristiano%2F'
    redirected_page = page_at(login_url)
    redirected_payload = payload_with(
      title: 'Cristiano Ronaldo (@cristiano)',
      markdown: '# Cristiano Ronaldo (@cristiano)\n\nOriginal content on this Instagram page for cristiano is not available without login.',
      canonicalUrl: login_url,
      siteName: 'Instagram'
    )

    stub_browser_extraction('https://www.instagram.com/cristiano/', page: redirected_page, payload: redirected_payload)

    result = fetch_with_dependencies('https://www.instagram.com/cristiano/')

    expect(result.final_url).to eq(normalized_login_url)
    expect(result.canonical_url).to eq(normalized_login_url)
    expect(result.metadata[:content_url]).to eq(normalized_login_url)
  end

  it 'does not inspect instagram network traffic for login-required payloads' do
    instagram_page = page_at('https://www.instagram.com/cristiano/')
    instagram_payload = payload_with(
      title: 'Cristiano Ronaldo (@cristiano)',
      excerpt: '673M Followers, 643 Following, 4,027 Posts.',
      siteName: 'Instagram',
      markdown: [
        '# Cristiano Ronaldo (@cristiano)',
        '- Access notice: Instagram login required',
        '- Image: https://cdn.example.test/cristiano.jpg',
        '',
        'Original content on this Instagram page for cristiano is not available without login.'
      ].join("\n")
    )

    expect(instagram_page).not_to receive(:network)
    stub_browser_extraction('https://www.instagram.com/cristiano/', page: instagram_page, payload: instagram_payload)

    result = fetch_with_dependencies('https://www.instagram.com/cristiano/')

    expect(result.markdown).to eq(instagram_payload['markdown'])
    expect(result.excerpt).to eq('673M Followers, 643 Following, 4,027 Posts.')
  end

  it 'flags cross-domain redirects in warnings' do
    redirected_page = page_at('https://www.economx.hu/gazdasag/some-article')
    redirect_payload = payload_with(
      title: 'Gazdasági hírek',
      markdown: "# Gazdasági hírek\n\nA magyar gazdaság...",
      warnings: []
    )

    stub_browser_extraction('https://www.napi.hu/gazdasag/some-article', page: redirected_page, payload: redirect_payload)

    result = fetch_with_dependencies('https://www.napi.hu/gazdasag/some-article')

    expect(result.warnings).to include('cross_domain_redirect')
    expect(result.suspect).to eq(true)
  end

  it 'flags PDF document URLs explicitly' do
    pdf_page = page_at('https://arxiv.org/pdf/1706.03762')
    pdf_payload = payload_with(
      title: '1706.03762',
      markdown: '',
      contentType: 'article',
      warnings: []
    )

    stub_browser_extraction('https://arxiv.org/pdf/1706.03762', page: pdf_page, payload: pdf_payload)

    result = fetch_with_dependencies('https://arxiv.org/pdf/1706.03762')

    expect(result.suspect).to eq(true)
    expect(result.warnings).to include('pdf_document')
  end

  it 'does not flag non-PDF article URLs as PDF documents' do
    article_page = page_at('https://example.com/articles/1706-03762')
    article_payload = payload_with(
      title: 'A transformer article',
      markdown: '# A transformer article\n\nReadable HTML article text.',
      warnings: []
    )

    stub_browser_extraction('https://example.com/articles/1706-03762', page: article_page, payload: article_payload)

    result = fetch_with_dependencies('https://example.com/articles/1706-03762')

    expect(result.warnings).not_to include('pdf_document')
  end

  it 'does not flag same-domain redirects as cross-domain' do
    same_domain_page = page_at('https://www.example.com/new-path')
    same_payload = payload_with(warnings: [])

    stub_browser_extraction('https://www.example.com/old-path', page: same_domain_page, payload: same_payload)

    result = fetch_with_dependencies('https://www.example.com/old-path')

    expect(result.warnings).not_to include('cross_domain_redirect')
  end

  it 'does not flag www-only differences as cross-domain redirects' do
    www_page = page_at('https://www.spectator.com/article')
    www_payload = payload_with(warnings: [])

    stub_browser_extraction('https://spectator.com/article', page: www_page, payload: www_payload)

    result = fetch_with_dependencies('https://spectator.com/article')

    expect(result.warnings).not_to include('cross_domain_redirect')
  end

  it 'flags cross-domain redirect for co.uk TLD changes' do
    uk_page = page_at('https://www.spectator.com/article')
    uk_payload = payload_with(warnings: [])

    stub_browser_extraction('https://www.spectator.co.uk/article', page: uk_page, payload: uk_payload)

    result = fetch_with_dependencies('https://www.spectator.co.uk/article')

    expect(result.warnings).to include('cross_domain_redirect')
  end

  it 'flags aggregator_redirect_url for news.google.com URLs' do
    google_news_page = page_at('https://www.reuters.com/world/europe/article-123')
    google_news_payload = payload_with(warnings: [])

    stub_browser_extraction(
      'https://news.google.com/rss/articles/some-encoded-id',
      page: google_news_page,
      payload: google_news_payload
    )

    result = fetch_with_dependencies('https://news.google.com/rss/articles/some-encoded-id')

    expect(result.warnings).to include('aggregator_redirect_url')
    expect(result.suspect).to eq(true)
  end

  it 'flags aggregator_redirect_url for AMP cache URLs' do
    amp_page = page_at('https://www.example.com/article')
    amp_payload = payload_with(warnings: [])

    stub_browser_extraction('https://cdn.ampproject.org/c/s/www.example.com/article', page: amp_page, payload: amp_payload)

    result = fetch_with_dependencies('https://cdn.ampproject.org/c/s/www.example.com/article')

    expect(result.warnings).to include('aggregator_redirect_url')
  end

  it 'flags aggregator_redirect_url for AMP cache subdomain URLs' do
    amp_sub_page = page_at('https://www.example.com/article')
    amp_sub_payload = payload_with(warnings: [])

    stub_browser_extraction(
      'https://www-example-com.cdn.ampproject.org/c/s/www.example.com/article',
      page: amp_sub_page,
      payload: amp_sub_payload
    )

    result = fetch_with_dependencies('https://www-example-com.cdn.ampproject.org/c/s/www.example.com/article')

    expect(result.warnings).to include('aggregator_redirect_url')
  end

  it 'flags aggregator_redirect_url for Google redirect URLs' do
    google_redir_page = page_at('https://www.example.com/article')
    google_redir_payload = payload_with(warnings: [])

    stub_browser_extraction(
      'https://www.google.com/url?q=https://www.example.com/article',
      page: google_redir_page,
      payload: google_redir_payload
    )

    result = fetch_with_dependencies('https://www.google.com/url?q=https://www.example.com/article')

    expect(result.warnings).to include('aggregator_redirect_url')
  end

  it 'does not flag regular publisher URLs as aggregator_redirect_url' do
    regular_page = page_at('https://www.reuters.com/world/europe/article-123')
    regular_payload = payload_with(warnings: [])

    stub_browser_extraction('https://www.reuters.com/world/europe/article-123', page: regular_page, payload: regular_payload)

    result = fetch_with_dependencies('https://www.reuters.com/world/europe/article-123')

    expect(result.warnings).not_to include('aggregator_redirect_url')
  end

  it 'does not flag google.com search URLs as aggregator_redirect_url' do
    search_page = page_at('https://www.google.com/search?q=test')
    search_payload = payload_with(contentType: 'search', warnings: [])

    stub_browser_extraction('https://www.google.com/search?q=test', page: search_page, payload: search_payload)

    result = fetch_with_dependencies('https://www.google.com/search?q=test')

    expect(result.warnings).not_to include('aggregator_redirect_url')
  end
end
