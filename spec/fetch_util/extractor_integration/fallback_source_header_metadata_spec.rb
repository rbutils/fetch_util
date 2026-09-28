RSpec.describe 'Source-owned fallback header metadata' do
  include_context 'extractor integration helpers'

  let(:guidance_html) do
    fixture_contents(File.expand_path('../../fixtures/govuk_guidance.html', __dir__))
      .sub('<div id="contents" data-module="contents-list-with-body"', '<div id="contents"')
      .sub(%r{<nav aria-label="Contents".*?</nav>}m, '')
  end
  let(:guidance_url) { 'https://unknown.example/guidance/plain-source-owned-guidance' }

  def extract_guidance(html)
    result = nil
    extract_from_url(guidance_url, html) { |payload| result = payload }
    result
  end

  it 'retains visible labeled metadata owned by the selected article header' do
    payload = nil
    with_url_page(guidance_url, guidance_html) do |page|
      payload = extract_payload(page)
    end
    expect_content_type(payload, 'article')
    expect(payload['markdown']).to include('# Rates and thresholds for employers 2026 to 2027')
    expect(payload['byline']).to eq('HM Revenue & Customs')
    expect(payload['publishedTime']).to eq('30 January 2026')
    expect(payload['markdown']).to include('Unless otherwise stated')
  end

  it 'rejects duplicate and internally conflicting owned header groups' do
    variants = [
      guidance_html.sub('<div data-module="govspeak"',
                        '<div class="gem-c-metadata"><dl><dt>From</dt><dd>Other author</dd>' \
                          '<dt>Published</dt><dd>31 January 2026</dd></dl></div>' \
                          '<div data-module="govspeak"'),
      guidance_html.sub(%r{<dt[^>]*>From:</dt>\s*<dd[^>]*>.*?</dd>}m,
                        '<dt>From:</dt><dd>HM Revenue &amp; Customs</dd><dd>Conflicting author</dd>')
    ]

    variants.each_with_index do |html, index|
      payload = extract_guidance(html)
      expect(payload['byline']).to be_nil, "variant #{index}"
      expect(payload['publishedTime']).to be_nil
    end
  end

  it 'rejects conflicting groups even when declared metadata matches one group' do
    html = guidance_html
           .sub('</head>', '<meta property="article:published_time" content="2026-01-30T10:09:00+00:00"></head>')
           .sub('<div data-module="govspeak"',
                '<div class="gem-c-metadata"><dl><dt>From</dt><dd>Other author</dd>' \
                  '<dt>Published</dt><dd>31 January 2026</dd></dl></div>' \
                  '<div data-module="govspeak"')

    payload = extract_guidance(html)

    expect(payload['byline']).to be_nil
  end

  it 'ignores unrelated foreign sidebar and footer metadata' do
    foreign_metadata = '<aside><dl><dt>From</dt><dd>Sidebar author</dd>' \
      '<dt>Published</dt><dd>1 February 2026</dd></dl></aside>' \
      '<footer><dl><dt>From</dt><dd>Footer author</dd>' \
      '<dt>Published</dt><dd>2 February 2026</dd></dl></footer>'
    html = guidance_html.sub('</main>', "#{foreign_metadata}</main>")
    payload = extract_guidance(html)

    expect(payload['byline']).to eq('HM Revenue & Customs')
    expect(payload['publishedTime']).to eq('30 January 2026')
  end

  it 'ignores a labeled group in an unrelated subsection between the headline and body' do
    foreign_section = '<section class="related-guidance"><h2>Related guidance</h2>' \
      '<dl><dt>From</dt><dd>Unrelated author</dd><dt>Published</dt>' \
      '<dd>3 February 2026</dd></dl></section>'
    html = guidance_html.sub('<div data-module="govspeak"', "#{foreign_section}<div data-module=\"govspeak\"")

    payload = extract_guidance(html)

    expect(payload['byline']).to eq('HM Revenue & Customs')
    expect(payload['publishedTime']).to eq('30 January 2026')
  end

  it 'keeps authoritative declared metadata when it disagrees with visible labels' do
    author = extract_guidance(guidance_html.sub('</head>', '<meta name="author" content="Declared author"></head>'))
    date = extract_guidance(guidance_html.sub('</head>', '<meta property="article:published_time" content="2025-12-01"></head>'))

    expect(author['byline']).to eq('Declared author')
    expect(date['publishedTime']).to eq('2025-12-01')
  end

  it 'does not infer metadata from hidden labels or a mismatched article title' do
    hidden_group = guidance_html.sub(
      '<dl class="gem-c-metadata__list">',
      '<dl class="gem-c-metadata__list" hidden>'
    )
    hidden_author = guidance_html.sub(
      '<dd class="gem-c-metadata__definition"><a href="/government/organisations/hm-revenue-customs">',
      '<dd class="gem-c-metadata__definition" hidden><a href="/government/organisations/hm-revenue-customs">'
    )
    mismatched_title = guidance_html.sub(
      %r{(<h1[^>]*>).*?(</h1>)}m,
      '\\1Different heading\\2'
    )

    [hidden_group, hidden_author, mismatched_title].each do |html|
      payload = extract_guidance(html)
      expect(payload['byline']).to be_nil
      expect(payload['publishedTime']).to be_nil
    end
  end

  it 'does not inherit metadata from a separate article or metadata-only page' do
    sibling_article = '<article><h1>Another article</h1><p>Separate article body.</p>' \
      '<dl><dt>From</dt><dd>Other author</dd><dt>Published</dt>' \
      '<dd>1 February 2026</dd></dl></article>'
    sibling = guidance_html.sub('</main>', "#{sibling_article}</main>")
    no_owned_body = guidance_html.sub(%r{<div data-module="govspeak".*?</div>}m, '')

    [sibling, no_owned_body].each do |html|
      payload = extract_guidance(html)
      expect(payload['byline']).to be_nil
      expect(payload['publishedTime']).to be_nil
    end
  end

  it 'does not apply an article header to an independent article collection' do
    collection = '<section><h2>Related guidance</h2><article>' \
      '<h1>Another article</h1><p>Separate article body.</p>' \
      '<dl><dt>From</dt><dd>Other author</dd><dt>Published</dt>' \
      '<dd>1 February 2026</dd></dl></article></section>'
    html = guidance_html.sub('</main>', "#{collection}</main>")

    payload = extract_guidance(html)
    expect(payload['byline']).to be_nil
    expect(payload['publishedTime']).to be_nil
  end

  it 'rejects metadata when the selected Reader content includes foreign source paragraphs' do
    foreign_paragraphs = [
      '<p>FOREIGN_SOURCE_SELECTION_SENTINEL Alpha guidance belongs to a separate source record. ' \
        'Its visible paragraphs are not part of the selected article body and must not inherit its author or date. ' \
        'This independent source has enough prose to remain visible in the selected Reader content.</p>',
      '<p>Beta guidance continues the independent source record with substantive explanatory prose. ' \
        'It remains visible as a separate paragraph and is not owned by the guidance article header.</p>',
      '<p>Gamma guidance concludes the foreign source record with additional visible text and a separate subject.</p>'
    ].join
    foreign_section = '<section id="secondary-guidance-record"><h2>Separate guidance record</h2>' \
      "#{foreign_paragraphs}</section>"
    html = guidance_html.sub('</main>', "#{foreign_section}</main>")

    payload = extract_guidance(html)

    expect_content_type(payload, 'article')
    expect(payload['readerMode']).to be(true)
    expect(payload['textContent']).to include('FOREIGN_SOURCE_SELECTION_SENTINEL')
    expect(payload['byline']).to be_nil
    expect(payload['publishedTime']).to be_nil
  end

  it 'does not attach article metadata to a same-title list result' do
    payload = nil
    with_url_page(guidance_url, guidance_html) do |page|
      page.evaluate(<<~JAVASCRIPT)
        window.hostAwareProfiles = [{
          condition: true,
          fn: function() {
            var title = document.querySelector('h1').textContent.trim();
            return {
              title: title,
              byline: null,
              publishedTime: null,
              markdown: '# ' + title + '\\n\\n- Independent collection item',
              html: '<ul><li>Independent collection item</li></ul>',
              textContent: 'Independent collection item',
              readerMode: false,
              contentType: 'list'
            };
          }
        }];
      JAVASCRIPT
      payload = extract_payload(page)
    end

    expect_content_type(payload, 'list')
    expect(payload['title']).to eq('Rates and thresholds for employers 2026 to 2027')
    expect(payload['markdown']).to include('- Independent collection item')
    expect(payload['byline']).to be_nil
    expect(payload['publishedTime']).to be_nil
  end
end
