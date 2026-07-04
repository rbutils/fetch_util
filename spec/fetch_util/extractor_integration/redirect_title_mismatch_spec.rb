# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'FetchUtil extractor integration - redirect title mismatch warnings' do
  include_context 'extractor integration helpers'

  def fetch_result_from_fixture(requested_url, final_url, html, canonical_url: nil, content_type: nil, warnings: nil)
    with_url_page(final_url, html) do |page|
      payload = extract(page)
      payload = payload.merge('canonicalUrl' => canonical_url) if canonical_url
      payload = payload.merge('contentType' => content_type) if content_type
      payload = payload.merge('warnings' => warnings) if warnings
      fetcher_for_payload(requested_url, final_url, payload).fetch(requested_url)
    end
  end

  def fetcher_for_payload(requested_url, final_url, payload)
    page = instance_double('FerrumPage', current_url: final_url)
    browser = instance_double(FetchUtil::Browser)
    extractor = instance_double(FetchUtil::Extractor)
    raw_docs_fallback = instance_double(FetchUtil::RawDocsFallback, fetch: nil)

    allow(browser).to receive(:with_page).with(requested_url).and_yield(page)
    allow(extractor).to receive(:extract).with(page).and_return(payload)

    FetchUtil::Fetcher.new(browser: browser, extractor: extractor, raw_docs_fallback: raw_docs_fallback)
  end

  it 'flags a redirected OpenLibrary work whose requested title slug does not match the final work' do
    html = <<~HTML
      <html>
        <head>
          <title>El Superzorro by Roald Dahl | Open Library</title>
          <link rel="canonical" href="https://openlibrary.org/works/OL45804W/Fantastic_Mr_Fox">
        </head>
        <body>
          <main>
            <article>
              <h1>El Superzorro</h1>
              <h2>by Roald Dahl</h2>
              <p>Fantastic Mr Fox is a children's novel about Mr Fox and three farmers.</p>
              <p>This work page lists editions, subjects, ratings, and reading activity for the Roald Dahl book.</p>
            </article>
          </main>
        </body>
      </html>
    HTML

    result = fetch_result_from_fixture(
      'https://openlibrary.org/works/OL45804W/Charlotte_s_Web',
      'https://openlibrary.org/works/OL45804W/Fantastic_Mr_Fox',
      html
    )

    expect(result.warnings).to include('url_content_mismatch')
    expect(result.suspect).to eq(true)
  end

  it 'flags a Goodreads-style canonical book mismatch when the browser URL did not change' do
    html = <<~HTML
      <html>
        <head>
          <title>Into the Wild</title>
          <meta property="article:published_time" content="2025-05-23T00:00:00Z">
          <link rel="canonical" href="https://www.goodreads.com/book/show/60869516-into-the-wild">
        </head>
        <body>
          <main>
            <article>
              <h1>Into the Wild</h1>
              <p>Readers discuss Chris McCandless, Alaska, survival, and the choices described in this book.</p>
              <p>The page includes reviews, ratings, quotes, and community discussion for Into the Wild.</p>
            </article>
          </main>
        </body>
      </html>
    HTML

    result = fetch_result_from_fixture(
      'https://www.goodreads.com/book/show/1845.Good_Omens',
      'https://www.goodreads.com/book/show/1845.Good_Omens',
      html,
      canonical_url: 'https://www.goodreads.com/book/show/60869516-into-the-wild'
    )

    expect(result.warnings).to include('url_content_mismatch')
  end

  it 'flags an address slug redirected to an unrelated property title' do
    html = <<~HTML
      <html>
        <head>
          <title>1255 Sixth St, Lakeport, CA 95453 | Redfin</title>
          <link rel="canonical" href="https://www.redfin.com/CA/Lakeport/1255-Sixth-St-95453/home/12345678">
        </head>
        <body>
          <main>
            <article>
              <h1>1255 Sixth St, Lakeport, CA 95453</h1>
              <p>This property page describes a Lakeport home with sales history, tax records, and nearby schools.</p>
              <p>Local market information, mortgage estimates, and neighborhood data appear below the listing details.</p>
            </article>
          </main>
        </body>
      </html>
    HTML

    result = fetch_result_from_fixture(
      'https://www.redfin.com/VA/Arlington/3500-S-Washington-St-Arlington-22227/unit-B/home/12345678',
      'https://www.redfin.com/CA/Lakeport/1255-Sixth-St-95453/home/12345678',
      html
    )

    expect(result.warnings).to include('url_content_mismatch')
  end

  it 'does not flag a legitimate redirect that preserves the requested topic words' do
    html = <<~HTML
      <html>
        <head>
          <title>My Post</title>
          <link rel="canonical" href="https://example.com/blog/my-post-2">
        </head>
        <body>
          <main><article><h1>My Post</h1><p>This updated article keeps the same subject after a slug normalization redirect.</p></article></main>
        </body>
      </html>
    HTML

    result = fetch_result_from_fixture('https://example.com/blog/my-post', 'https://example.com/blog/my-post-2', html)

    expect(result.warnings).not_to include('url_content_mismatch')
  end

  it 'does not flag same-organization subdomain redirects when the article matches the requested code' do
    html = <<~HTML
      <html>
        <head><title>Convention C001 - Hours of Work (Industry) Convention, 1919</title></head>
        <body>
          <main>
            <article>
              <h1>Convention C001 - Hours of Work (Industry) Convention, 1919 (No. 1)</h1>
              <p>The General Conference of the International Labour Organisation adopts the following Convention.</p>
              <h2>Article 1</h2>
              <p>For the purpose of this Convention, the term industrial undertaking includes mines, quarries, and manufacturing.</p>
            </article>
          </main>
        </body>
      </html>
    HTML

    result = fetch_result_from_fixture(
      'https://www.example.org/dyn/normlex/en/f?p=NORMLEXPUB:12100:0::NO::P12100_ILO_CODE:C001',
      'https://normlex.example.org/dyn/nrmlx_en/f?p=NORMLEXPUB%3A12100%3A0%3A%3ANO%3A%3AP12100_ILO_CODE%3AC001',
      html
    )

    expect(result.warnings).not_to include('url_content_mismatch')
    expect(result.suspect).to eq(false)
  end

  it 'keeps same-organization redirect mismatches when the requested code is absent from the article' do
    html = <<~HTML
      <html>
        <head><title>Convention C999 - Maritime Labour Convention</title></head>
        <body>
          <main>
            <article>
              <h1>Convention C999 - Maritime Labour Convention</h1>
              <p>This page describes maritime labour standards, shipboard employment, and seafarer protections.</p>
              <p>The requested industrial-hours convention identifier does not appear in this unrelated convention text.</p>
            </article>
          </main>
        </body>
      </html>
    HTML

    result = fetch_result_from_fixture(
      'https://www.example.org/dyn/normlex/en/f?p=NORMLEXPUB:12100:0::NO::P12100_ILO_CODE:C001',
      'https://normlex.example.org/dyn/nrmlx_en/f?p=NORMLEXPUB%3A12100%3A0%3A%3ANO%3A%3AP12100_ILO_CODE%3AC999',
      html,
      warnings: ['url_content_mismatch']
    )

    expect(result.warnings).to include('url_content_mismatch')
    expect(result.suspect).to eq(true)
  end

  it 'does not flag same-organization APEX instrument redirects when the numeric instrument id is stable' do
    html = <<~HTML
      <html>
        <head><title>Convention C047 - Forty-Hour Week Convention, 1935 (No. 47)</title></head>
        <body>
          <main>
            <article>
              <h1>Convention C047 - Forty-Hour Week Convention, 1935 (No. 47)</h1>
              <p>The General Conference of the International Labour Organisation adopts this Convention.</p>
              <h2>Article 1</h2>
              <p>Each Member of the International Labour Organisation which ratifies this Convention declares its approval of the principle of a forty-hour week.</p>
            </article>
          </main>
        </body>
      </html>
    HTML

    result = fetch_result_from_fixture(
      'https://www.example.org/dyn/normlex/en/f?p=NORMLEXPUB:12100:0::NO::P12100_INSTRUMENT_ID:312192',
      'https://normlex.example.org/dyn/nrmlx_en/f?p=NORMLEXPUB%3A12100%3A0%3A%3ANO%3A%3AP12100_INSTRUMENT_ID%3A312192',
      html,
      warnings: ['url_content_mismatch']
    )

    expect(result.warnings).not_to include('url_content_mismatch')
    expect(result.suspect).to eq(false)
  end

  it 'keeps same-organization APEX redirect mismatches when the instrument id changes' do
    html = <<~HTML
      <html>
        <head><title>Convention C047 - Forty-Hour Week Convention, 1935 (No. 47)</title></head>
        <body>
          <main>
            <article>
              <h1>Convention C047 - Forty-Hour Week Convention, 1935 (No. 47)</h1>
              <p>The General Conference of the International Labour Organisation adopts this Convention.</p>
              <h2>Article 1</h2>
              <p>Each Member of the International Labour Organisation which ratifies this Convention declares its approval of the principle of a forty-hour week.</p>
            </article>
          </main>
        </body>
      </html>
    HTML

    result = fetch_result_from_fixture(
      'https://www.example.org/dyn/normlex/en/f?p=NORMLEXPUB:12100:0::NO::P12100_INSTRUMENT_ID:312192',
      'https://normlex.example.org/dyn/nrmlx_en/f?p=NORMLEXPUB%3A12100%3A0%3A%3ANO%3A%3AP12100_INSTRUMENT_ID%3A999999',
      html,
      warnings: ['url_content_mismatch']
    )

    expect(result.warnings).to include('url_content_mismatch')
    expect(result.suspect).to eq(true)
  end

  it 'does not flag single-word or id-only requested slugs' do
    html = <<~HTML
      <html>
        <head>
          <title>Different Book</title>
          <link rel="canonical" href="https://example.com/works/OL12345W/different-book">
        </head>
        <body>
          <main><article><h1>Different Book</h1><p>A single-word requested slug is too weak to diagnose safely.</p></article></main>
        </body>
      </html>
    HTML

    result = fetch_result_from_fixture('https://example.com/works/OL12345W/Charlotte', 'https://example.com/works/OL12345W/different-book', html)

    expect(result.warnings).not_to include('url_content_mismatch')
  end

  it 'does not flag search and list pages where title mismatches are expected' do
    html = <<~HTML
      <html>
        <head><title>Search results for books</title></head>
        <body>
          <main>
            <h1>Search results</h1>
            <ul>
              <li><a href="/works/1">Fantastic Mr Fox</a></li>
              <li><a href="/works/2">Into the Wild</a></li>
              <li><a href="/works/3">Charlotte's Web</a></li>
            </ul>
          </main>
        </body>
      </html>
    HTML

    result = fetch_result_from_fixture('https://example.com/search/charlotte-web', 'https://example.com/search/books', html, content_type: 'list')

    expect(result.warnings).not_to include('url_content_mismatch')
  end

  it 'does not flag a normal article whose title matches its requested slug' do
    html = <<~HTML
      <html>
        <head>
          <title>Charlotte Web Review</title>
          <link rel="canonical" href="https://example.com/articles/charlotte-web-review">
        </head>
        <body>
          <main><article><h1>Charlotte Web Review</h1><p>A normal article keeps the same title words as the URL slug.</p></article></main>
        </body>
      </html>
    HTML

    result = fetch_result_from_fixture('https://example.com/articles/charlotte-web-review', 'https://example.com/articles/charlotte-web-review', html)

    expect(result.warnings).not_to include('url_content_mismatch')
  end
end
