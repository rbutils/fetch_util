# frozen_string_literal: true

RSpec.describe 'Canonical article scope preservation' do
  include_context 'extractor integration helpers'

  it 'retains already-proved labeled header attribution and declared timestamp precision' do
    url = 'https://records.example/reports/harbor-plan'
    html = <<~HTML
      <html><head><title>Harbor service record</title>
        <link rel="canonical" href="#{url}">
        <meta property="og:type" content="article">
        <meta property="og:title" content="Harbor service record">
        <meta property="article:published_time" content="2026-09-28T08:00:00Z">
      </head><body><main>
        <header><h1>Harbor service record</h1>
          <p>The harbor office explains the complete service plan for the coming inspection period.</p>
          <dl><dt>From</dt><dd>Harbor Desk</dd>
            <dt>Published</dt><dd>28 September 2026</dd></dl>
        </header>
        <div class="article-body">
          <p>Engineers will inspect every pier before the harbor reopens for passenger services. The published schedule includes the accessible routes and all temporary boarding arrangements.</p>
          <p>Operators will maintain the existing ferry timetable throughout the inspection period. Residents can consult the complete service record before planning their journey.</p>
        </div>
      </main></body></html>
    HTML

    with_url_page(url, html) do |page|
      payload = extract_payload(page)
      expect_content_type(payload, 'article')
      expect(payload['readerMode']).to be(false)
      expect(payload['byline']).to eq('Harbor Desk')
      expect(payload['publishedTime']).to eq('2026-09-28T08:00:00Z')
      expect(payload['markdown']).to include('Harbor Desk', 'Engineers will inspect every pier', 'Operators will maintain')
    end

    declared = html.sub('</head>', '<meta name="author" content="Declared Reporter"></head>')
    with_url_page(url, declared) do |page|
      payload = extract_payload(page)
      expect(payload['byline']).to eq('Declared Reporter')
      expect(payload['markdown']).to include('Harbor Desk', 'Engineers will inspect every pier')
    end
  end

  it 'keeps an owned formal notice ahead of canonical article metadata' do
    url = 'https://www.federalregister.gov/documents/2026/07/09/2026-13907/funding-opportunity'
    fixture_path = File.expand_path('../../../fixtures/federal_register_notice.html', __dir__)
    head_metadata = %(<meta property="og:type" content="article"><link rel="canonical" href="#{url}">)
    html = File.read(fixture_path).sub('</head>', "#{head_metadata}</head>")
    html = html.sub('<main id="main">', '<main id="main" class="article-body">')

    with_url_page(url, html) do |page|
      payload = extract_payload(page)
      expect_content_type(payload, 'notice')
      expect(payload['byline']).to eq('Department of Transportation; Federal Transit Administration')
      expect(payload['markdown']).to include('AGENCY:', 'SUPPLEMENTARY INFORMATION:')
    end
  end

  it 'keeps proved Contents navigation ahead of canonical article metadata' do
    url = 'https://www.gov.uk/guidance/rates-and-thresholds-for-employers-2026-to-2027'
    fixture_path = File.expand_path('../../../fixtures/govuk_guidance.html', __dir__)
    head_metadata = <<~HTML
      <meta property="og:type" content="article">
      <meta property="og:title" content="Rates and thresholds for employers 2026 to 2027">
      <link rel="canonical" href="#{url}">
    HTML
    html = File.read(fixture_path).sub('</head>', "#{head_metadata}</head>")
    html = html.sub('class="govuk-main-wrapper"', 'class="govuk-main-wrapper article-body"')

    with_url_page(url, html) do |page|
      payload = extract_payload(page)
      expect_content_type(payload, 'article')
      expect(payload['byline']).to eq('HM Revenue & Customs')
      expect(payload['publishedTime']).to eq('2026-01-30T10:09:00+00:00')
      expect(payload['markdown']).to include('Contents', '[PAYE tax and Class 1 National Insurance contributions](')
    end
  end

  it 'does not treat the focal record or its ancestor as a disposable latest-news rail' do
    url = 'https://counter.example/articles/comment-boundary'
    fixture_path = File.expand_path('../../../fixtures/article_ownership_coverage/plain-div-closing.html', __dir__)
    original = File.read(fixture_path)
    variants = [
      original.sub("class='article-record'", "class='article-record latest-news'"),
      original.sub('<main>', '<div class="latest-posts"><main>').sub('</main>', '</main></div>')
    ]

    variants.each do |html|
      with_url_page(url, html) do |page|
        payload = extract_payload(page)
        expect(payload['markdown']).to include(
          'the north walkway reopens before the next inspection',
          '/reports/harbor-closing.pdf'
        )
        expect(payload['html']).to include('the north walkway reopens before the next inspection')
      end
    end
  end
end
