# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'source-owned article photo-credit excerpts' do
  include_context 'extractor integration helpers'

  def article_with_credit(credit)
    paragraphs = (1..4).map do |index|
      "<p>Reporting paragraph #{index} explains the independent evidence, the public decision, and the affected community with enough detail for a complete account.</p>"
    end.join
    <<~HTML
      <html><head><title>Regional policy briefing</title></head><body>
        <main><article><h1>Regional policy briefing</h1>
          <p>Community event in the capital, 19 January 2026. #{credit}</p>
          #{paragraphs}
        </article></main>
      </body></html>
    HTML
  end

  it 'uses the complete owned report lead when an initial credit line is only a photo caption' do
    with_url_page('https://journal.example.test/articles/regional-policy', article_with_credit('Newsdesk/R Rivera')) do |page|
      before = page.evaluate('document.body.innerHTML')
      payload = extract_payload(page)

      expect(payload['excerpt']).to start_with('Reporting paragraph 1 explains')
      expect(payload['excerpt']).not_to include('Newsdesk/R Rivera')
      expect(payload['markdown']).to include('Newsdesk/R Rivera', 'Reporting paragraph 1', 'Reporting paragraph 4')
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end

  it 'keeps an ordinary dated introduction without a photo credit as the excerpt' do
    html = article_with_credit('The municipal review describes a second phase of policy.')
    with_url_page('https://journal.example.test/articles/municipal-review', html) do |page|
      payload = extract_payload(page)
      expect(payload['excerpt']).to start_with('Community event in the capital')
      expect(payload['markdown']).to include('Reporting paragraph 4')
    end
  end

  it 'does not promote an unrelated lead when the credited article has no complete body series' do
    html = article_with_credit('Newsdesk/R Rivera').gsub(%r{<p>Reporting paragraph [2-4].*?</p>}, '')
    with_url_page('https://journal.example.test/articles/short-notice', html) do |page|
      payload = extract_payload(page)
      expect(payload['excerpt']).to start_with('Community event in the capital')
      expect(payload['markdown']).to include('Reporting paragraph 1')
    end
  end

  it 'replaces a source-owned named photo credit with the complete first owned prose paragraph without a year' do
    credit = 'Jabulani Mabuza, raadsvoorsitter van Eskom (Foto: Nhlanhla Phillips/African News Agency/ANA)'
    html = article_with_credit(credit).sub('Community event in the capital, 19 January 2026. ', '')
    with_url_page('https://journal.example.test/articles/eskom', html) do |page|
      payload = extract_payload(page)

      expect(payload['excerpt']).to start_with('Reporting paragraph 1 explains')
      expect(payload['excerpt']).to eq(
        'Reporting paragraph 1 explains the independent evidence, the public decision, and the affected community ' \
        'with enough detail for a complete account.'
      )
      expect(payload['markdown']).to include(credit, 'Reporting paragraph 4')
    end
  end

  it 'retains legacy dated photo captions without slash credits and preserves article metadata and media' do
    caption = 'An extended description of the public event in the capital, 19 January 2026 (Photo: Jane Doe)'
    declared = 'DECLARED-METADATA: the public event report remains a separate source description.'
    html = article_with_credit(caption)
           .sub('Community event in the capital, 19 January 2026. ', '')
           .sub(
             '<head><title>Regional policy briefing</title></head>',
             "<head><title>Regional policy briefing</title><meta name=\"description\" content=\"#{declared}\"></head>"
           )
           .sub(
             "<p>#{caption}</p>",
             "<p>#{caption}</p><figure><img src=\"/dated-caption.jpg\"><figcaption>Owned report image.</figcaption></figure>"
           )

    with_url_page('https://journal.example.test/articles/dated-photo', html) do |page|
      payload = extract_payload(page)

      expect(payload['excerpt']).to start_with('Reporting paragraph 1 explains')
      expect(payload['title']).to eq('Regional policy briefing')
      expect(payload['description']).to eq(declared)
      expect(payload['excerpt']).not_to include(declared)
      expect(payload['html']).to include(caption, 'dated-caption.jpg', 'Owned report image.')
      expect(payload['markdown']).to include(caption, 'Reporting paragraph 4')
    end
  end

  it 'returns the complete Maroela source lead while retaining its caption credit and complete body' do
    html = fixture_contents(File.expand_path('../fixtures/maroelamedia_article.html', __dir__))
    lead = 'Eskom het ŉ hofbeslissing verwelkom wat die konsultantefirma Trillian Capital beveel om die R600 miljoen ' \
           'wat hy onwettig van die sukkelende kragvoorsiener verhaal het, terug te betaal.'
    credit = 'Jabulani Mabuza, raadsvoorsitter van Eskom (Foto: Nhlanhla Phillips/African News Agency/ANA)'

    with_url_page('https://www.maroelamedia.co.za/nuus/sa-nuus/eskom-verwelkom-hofbevel-wat-trillian-dwing-om-miljoene-terug-te-betaal', html) do |page|
      payload = extract_payload(page)

      expect(payload['excerpt']).to eq(lead)
      expect(payload['markdown']).to include(credit, lead, 'die koste van drie advokate betaal')
      expect(payload['html']).to include(credit)
    end
  end

  it 'returns a long owned prose paragraph whole rather than applying an excerpt presentation limit' do
    credit = 'Jabulani Mabuza, raadsvoorsitter van Eskom (Foto: Nhlanhla Phillips/African News Agency/ANA)'
    long_lead = [
      'The independent review began with records collected during the first stage of the inquiry.',
      'Investigators compared those documents with statements from residents and public officials.',
      'The published decision explains which claims were supported and which remained disputed.',
      'Local organizations will monitor the required changes and report whether deadlines are met.',
      'The complete source paragraph retains this final detail about the continuing public response.'
    ].join(' ')
    html = article_with_credit(credit)
           .sub('Community event in the capital, 19 January 2026. ', '')
           .sub(%r{<p>Reporting paragraph 1.*?</p>}, "<p>#{long_lead}</p>")

    with_url_page('https://journal.example.test/articles/long-lead', html) do |page|
      payload = extract_payload(page)
      expect(payload['excerpt']).to eq(long_lead)
      expect(payload['html']).to include("<p>#{long_lead}</p>")
      expect(payload['markdown']).to include(long_lead)
    end
  end

  it 'preserves a similarly labeled sentence as prose rather than treating it as a photo-credit owner' do
    narrative = 'The report explains how the newsroom verified its photograph. (Foto: Newsdesk/Regional Agency)'
    html = article_with_credit(narrative).sub('Community event in the capital, 19 January 2026. ', '')
    with_url_page('https://journal.example.test/articles/attribution', html) do |page|
      payload = extract_payload(page)

      expect(payload['excerpt']).to eq(narrative)
      expect(payload['markdown']).to include(narrative)
    end
  end

  it 'selects the first short visible owned prose paragraph after a credit, not hidden or nested foreign text' do
    credit = 'Jabulani Mabuza, raadsvoorsitter van Eskom (Foto: Nhlanhla Phillips/African News Agency/ANA)'
    short_lead = 'A short but owned lead.'
    foreign = '<article><figure><img src="/unrelated.jpg"><figcaption>Unrelated media caption.</figcaption></figure>' \
              '<p>Foreign article prose must not become the selected lead.</p></article>'
    html = article_with_credit(credit)
           .sub('Community event in the capital, 19 January 2026. ', '')
           .sub(
             '<p>Reporting paragraph 1 explains',
             "<p hidden>Hidden source prose must not become the selected lead.</p><p>#{short_lead}</p>#{foreign}<p>Reporting paragraph 1 explains"
           )

    with_url_page('https://journal.example.test/articles/short-lead', html) do |page|
      payload = extract_payload(page)

      expect(payload['excerpt']).to eq(short_lead)
      expect(payload['markdown']).to include(credit, 'Unrelated media caption.', 'Reporting paragraph 4')
      expect(payload['excerpt']).not_to include('Hidden source prose', 'Foreign article prose')
    end
  end

  it 'leaves a lone credit excerpt alone when no alternative owned prose exists' do
    credit = 'Jabulani Mabuza, raadsvoorsitter van Eskom (Foto: Nhlanhla Phillips/African News Agency/ANA)'
    declared = 'Declared summary metadata must not be promoted to article prose.'
    html = article_with_credit(credit)
           .sub('Community event in the capital, 19 January 2026. ', '')
           .sub(
             '<head><title>Regional policy briefing</title></head>',
             "<head><title>Regional policy briefing</title><meta name=\"description\" content=\"#{declared}\"></head>"
           )
           .gsub(%r{<p>Reporting paragraph [1-4].*?</p>}, '')

    with_url_page('https://journal.example.test/articles/credit-only', html) do |page|
      payload = extract_payload(page)
      expect(payload['excerpt']).to eq(credit)
      expect(payload['description']).to eq(declared)
      expect(payload['excerpt']).not_to include(declared)
      expect(payload['markdown']).to include(credit)
    end
  end

  it 'does not infer a photo credit from an editorial fragment when no owned source media exists' do
    fragment = 'Editorial update discusses the newsroom photograph (Foto: Newsdesk/Regional Agency)'
    html = article_with_credit('unused').sub(
      '<p>Community event in the capital, 19 January 2026. unused</p>', "<p>#{fragment}</p>"
    ).sub(
      '<p>Reporting paragraph 1 explains',
      '<article><figure><img src="/foreign-only.jpg"><figcaption>Foreign media.</figcaption></figure></article><p>Reporting paragraph 1 explains'
    )

    with_url_page('https://journal.example.test/articles/editorial-fragment', html) do |page|
      before = page.evaluate('document.body.innerHTML')
      payload = extract_payload(page)

      expect(payload['excerpt']).to eq(fragment)
      expect(payload['markdown']).to include(fragment, 'Reporting paragraph 4')
      expect(page.evaluate('document.querySelector("article article img") !== null')).to be(true)
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end
end
