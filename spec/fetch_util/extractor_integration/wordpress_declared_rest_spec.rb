# frozen_string_literal: true

require 'json'
require 'nokogiri'

RSpec.describe 'FetchUtil source-declared WordPress REST fallback' do
  include_context 'extractor integration helpers'

  let(:page_url) { 'https://neutral.example/news_42' }
  let(:posts_url) { 'https://neutral.example/wp-json/wp/v2/posts/42' }
  let(:source_title) { 'Neutral source record title' }
  let(:published_at) { '2026-10-01T12:00:00Z' }
  let(:paragraphs) do
    [
      'REST paragraph alpha: The project records its original research in an independently identified public article. ' \
      'Its first section explains the observations, the evidence collected by the authors, and their limitations.',
      'REST paragraph beta: A second team compared the published measurements with an earlier experiment. ' \
      'They documented both the matching results and the differences so readers could assess the complete account.',
      'REST paragraph gamma: The final discussion places those findings in context and describes questions that remain open. ' \
      'The source preserves the original ordering of this discussion and links to the supporting material.'
    ]
  end
  let(:rendered_body) do
    prose = paragraphs.map { |text| "<p>#{text}</p>" }.join
    "#{prose}<pre><code>measurement = 42</code></pre><p><a href=\"/evidence\">Supporting evidence</a></p>"
  end

  def article_html(body: '', declarations: nil, head: '')
    declarations ||= "<link rel='alternate' type='application/json' href='#{posts_url}'>"
    <<~HTML
      <!doctype html><html><head><meta name="generator" content="WordPress 6.8">
      <link rel="canonical" href="#{page_url}"><meta property="article:published_time" content="#{published_at}">
      #{declarations}#{head}<title>#{source_title}</title></head>
      <body><main><article><h1>#{source_title}</h1>#{body}</article></main></body></html>
    HTML
  end

  def rest_record(body: rendered_body, id: 42, link: page_url, title: source_title, protected: false)
    { id: id, link: link, title: { rendered: title }, content: { rendered: body, protected: protected },
      date: '2001-01-01T00:00:00' }.to_json
  end

  def run_declared_extraction(html:, responses: {})
    requests = []
    browser = Ferrum::Browser.new(
      headless: true, browser_path: required_browser_path,
      timeout: 10, window_size: [1280, 900], browser_options: { 'no-sandbox': nil }
    )
    page = browser.create_page
    page.bypass_csp
    page.network.intercept(pattern: '*')
    page.on(:request) do |request|
      requests << request.url
      if request.url == page_url
        request.respond(body: html, responseHeaders: { 'content-type' => 'text/html; charset=UTF-8' })
      elsif responses.key?(request.url)
        response = responses.fetch(request.url)
        headers = { 'content-type' => response.fetch(:content_type, 'application/json; charset=UTF-8') }
        headers.merge!(response.fetch(:headers, {}))
        request.respond(status: response.fetch(:status, 200), body: response.fetch(:body), responseHeaders: headers)
      else
        request.abort
      end
    end
    page.go_to(page_url)
    before = page.evaluate('document.body.innerHTML')
    payload = extract_payload(page)
    [payload, requests, before, page.evaluate('document.body.innerHTML')]
  ensure
    begin
      page&.close
    ensure
      browser&.quit
    end
  end

  def expect_declared_material(payload)
    document = Nokogiri::HTML(payload.fetch('html'), nil, 'UTF-8')
    extracted = document.css('p').map { |node| node.text.strip }
    expect(extracted.first(3)).to eq(paragraphs)
    positions = paragraphs.map { |text| payload.fetch('markdown').index(text) }
    expect(positions).to all(be_a(Integer))
    expect(positions).to eq(positions.sort)
    expect(document.at_css('pre code').text).to eq('measurement = 42')
    expect(document.at_css('a[href="https://neutral.example/evidence"]').text).to eq('Supporting evidence')
  end

  it 'uses a declared record on an unknown host without replacing source metadata or DOM' do
    payload, requests, before, after = run_declared_extraction(
      html: article_html, responses: { posts_url => { body: rest_record } }
    )
    expect_content_type(payload, 'article')
    expect(requests.count(posts_url)).to eq(1)
    expect_declared_material(payload)
    expect(payload['title']).to eq(source_title)
    expect(payload['publishedTime']).to eq(published_at)
    expect(before).to eq(after)
  end

  it 'supports subdirectory page endpoints and explicit rest_route declarations' do
    ['https://neutral.example/cms/wp-json/wp/v2/pages/42',
     'https://neutral.example/?rest_route=%2Fwp%2Fv2%2Fposts%2F42'].each do |endpoint|
      declaration = "<link rel='alternate' type='application/json' href='#{endpoint}'>"
      payload, requests, = run_declared_extraction(
        html: article_html(declarations: declaration), responses: { endpoint => { body: rest_record } }
      )
      expect(requests.count(endpoint)).to eq(1)
      expect_declared_material(payload)
    end
  end

  it 'prefers all visible owned reporting without requesting the declared API' do
    visible = rendered_body.gsub('REST paragraph', 'Visible paragraph')
    payload, requests, before, after = run_declared_extraction(
      html: article_html(body: "<div class='entry-content'>#{visible}</div>"),
      responses: { posts_url => { body: rest_record } }
    )
    expect(requests).not_to include(posts_url)
    paragraphs.each { |text| expect(payload['markdown']).to include(text.sub('REST paragraph', 'Visible paragraph')) }
    expect(payload['html']).not_to include('REST paragraph alpha:')
    expect(before).to eq(after)
  end

  it 'does not treat hidden bodies or hidden descendants as visible reporting' do
    ["<div class='entry-content' hidden>#{rendered_body}</div>",
     "<div class='entry-content'><div hidden>#{rendered_body}</div></div>"].each do |hidden|
      payload, requests, before, after = run_declared_extraction(
        html: article_html(body: hidden), responses: { posts_url => { body: rest_record } }
      )
      expect(requests.count(posts_url)).to eq(1)
      expect_declared_material(payload)
      expect(before).to eq(after)
    end
  end

  it 'does not guess a REST endpoint from a news_42 URL without a declaration' do
    payload, requests, = run_declared_extraction(
      html: article_html(declarations: ''), responses: { posts_url => { body: rest_record } }
    )
    expect(requests).not_to include(posts_url)
    expect(payload.to_s).not_to include('REST paragraph alpha:')
  end

  it 'rejects foreign, credentialed and ambiguous WordPress declarations before requesting them' do
    endpoints = [
      ['https://foreign.example/wp-json/wp/v2/posts/42'],
      ['https://user:secret@neutral.example/wp-json/wp/v2/posts/42'],
      [posts_url, 'https://neutral.example/wp-json/wp/v2/posts/43']
    ]
    endpoints.each do |urls|
      declarations = urls.map { |url| "<link rel='alternate' type='application/json' href='#{url}'>" }.join
      payload, requests, = run_declared_extraction(
        html: article_html(declarations: declarations), responses: { posts_url => { body: rest_record } }
      )
      expect(requests.grep(%r{/wp-json/})).to be_empty
      expect(payload.to_s).not_to include('REST paragraph alpha:')
    end
  end

  it 'ignores an unrelated JSON alternate alongside the one WordPress declaration' do
    declarations = "<link rel='alternate' type='application/json' href='/feed.json'>" \
                   "<link rel='alternate' type='application/json' href='#{posts_url}'>"
    payload, requests, = run_declared_extraction(
      html: article_html(declarations: declarations), responses: { posts_url => { body: rest_record } }
    )
    expect(requests).to include(posts_url)
    expect(requests).not_to include('https://neutral.example/feed.json')
    expect_declared_material(payload)
  end

  it 'declines protected, failed, malformed and identity-conflicting responses' do
    responses = [
      { status: 503, body: 'HTTP FAILURE MARKER' }, { body: 'not JSON' }, { body: '[{"id":42}]' },
      { body: rest_record(protected: true) }, { body: rest_record(body: 42) },
      { body: rest_record(id: 43) }, { body: rest_record(link: '') },
      { body: rest_record(link: 'https://neutral.example/another-post') },
      { body: rest_record(title: 'Another response title') }
    ]
    responses.each do |response|
      payload, requests, = run_declared_extraction(html: article_html, responses: { posts_url => response })
      expect(requests).to include(posts_url)
      expect(payload.to_s).not_to include('REST paragraph alpha:', 'HTTP FAILURE MARKER')
    end
  end

  it 'does not use a declared API to pass an explicit source access boundary' do
    ['<div data-paywall>Subscribe to continue this article.</div>',
     '<form><input type="password"></form>'].each do |boundary|
      payload, requests, = run_declared_extraction(
        html: article_html(body: boundary), responses: { posts_url => { body: rest_record } }
      )
      expect(requests).not_to include(posts_url)
      expect(payload.to_s).not_to include('REST paragraph alpha:')
    end
  end

  it 'declines a redirect response without adopting its content' do
    redirected = 'https://neutral.example/api/moved-record'
    payload, requests, = run_declared_extraction(
      html: article_html, responses: {
        posts_url => { status: 302, body: '', headers: { 'location' => redirected } },
        redirected => { body: rest_record }
      }
    )
    expect(requests).to include(posts_url)
    expect(payload.to_s).not_to include('REST paragraph alpha:')
  end
end
