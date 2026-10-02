# frozen_string_literal: true

RSpec.describe 'Source-owned article excerpt boundaries' do
  include_context 'extractor integration helpers'

  it 'retains the entire prose paragraph after an owned publication action' do
    lead = ("Verified reporting describes the complete public record, the evidence, and the response. " * 5).strip
    html = <<~HTML
      <html><head><title>Public record</title></head><body><main><article>
        <h1>Public record</h1><p class="published-date">Jan. 2, 2026, visit link for details.</p>
        <p>#{lead}</p><p>Additional source-owned context confirms the sequence of events.</p>
      </article></main></body></html>
    HTML

    with_url_page('https://example.test/record', html) do |page|
      payload = extract_payload(page, reader_mode: true)
      expect(payload.fetch('excerpt')).to eq(lead)
      expect(payload.fetch('markdown')).to include('Verified reporting describes the complete public record',
                                                   'Additional source-owned context confirms the sequence of events.')
    end
  end

  it 'keeps a short authored introduction after publication furniture' do
    opening = 'The first witness spoke briefly.'
    later = 'The later reporting documents the public hearings, verified records, and independent responses in extensive detail.'
    html = <<~HTML
      <html><head><title>Hearing report</title></head><body><main><article>
        <h1>Hearing report</h1><p class="published-date">Published on 2 January 2026.</p>
        <p>#{opening}</p><p>#{later}</p><h2>Further evidence</h2>
        <p>Residents submitted their accounts and copies of the official record.</p>
      </article></main></body></html>
    HTML

    with_url_page('https://example.test/hearing', html) do |page|
      [false, true].each do |reader_mode|
        payload = extract_payload(page, reader_mode: reader_mode)
        expect(payload.fetch('excerpt')).to start_with(opening)
        expect(payload.fetch('markdown')).to include(opening, later)
      end
    end
  end

  it 'prunes a hidden child of a proved standfirst without promoting a nested foreign paragraph' do
    visible = 'The visible standfirst explains the public decision and its effect on residents.'
    html = <<~HTML
      <html><head><title>Local decision</title></head><body><main><article>
        <header><h1>Local decision</h1><p class="article-standfirst">#{visible}<span hidden> Private draft sentence.</span></p>
          <aside><p class="article-standfirst">A separate card summary belongs to another story.</p></aside></header>
        <div class="article-body"><p>The body reports the full decision and evidence from the public hearing.</p></div>
      </article></main></body></html>
    HTML

    with_url_page('https://example.test/decision', html) do |page|
      before = page.evaluate('document.body.innerHTML')
      payload = extract_payload(page, reader_mode: false)
      expect(payload.fetch('excerpt')).to eq(visible)
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end

  it 'does not join an unrelated adjacent paragraph after an empty source paragraph' do
    opening = 'The initial account records the public decision and the witnesses who provided the evidence.'
    later = 'The next section reports a separately sourced response with different participants.'
    html = <<~HTML
      <html><head><title>Public decision</title><meta property="og:site_name" content="Public Records"></head>
      <body><main><h1>Public decision</h1><article class="article-content">
        <p>Public decision</p><p>#{opening}</p><p> </p>
        <p class="related">A card points to a different account of the decision.</p>
        <p>#{later}</p>
      </article></main></body></html>
    HTML

    with_url_page('https://example.test/decision-record', html) do |page|
      payload = extract_payload(page, reader_mode: false)
      expect(payload.fetch('excerpt')).to eq(opening)
      expect(payload.fetch('markdown')).to include(opening, later)
    end
  end

  it 'does not join a credit paragraph to a short complete opening' do
    opening = 'The witness described the ruling.'
    credit = 'Reporting by the public records team and the independent archives.'
    html = <<~HTML
      <html><head><title>Hearing account</title></head><body><main><article>
        <h1>Hearing account</h1><p>Hearing account</p>
        <p>#{opening}</p><p class="byline">#{credit}</p>
        <p>The hearing continued with sworn statements and a review of the public record.</p>
      </article></main></body></html>
    HTML

    with_url_page('https://example.test/hearing-account', html) do |page|
      payload = extract_payload(page, reader_mode: false)
      expect(payload.fetch('excerpt')).to eq(opening)
      expect(payload.fetch('markdown')).to include(opening)
    end
  end

  it 'keeps whole article prose under date-like container names' do
    opening = 'The updated account describes the witnesses, the public record, and the independent response in full.'
    continuation = 'The subsequent evidence explains what the court heard and how the community responded to its decision.'
    html = <<~HTML
      <html><head><title>Updated hearing</title></head><body><main>
        <article class="updated-story"><h1>Updated hearing</h1><div class="candidate-body publication-content">
          <p>#{opening}</p><p>#{continuation}</p>
        </div></article>
      </main></body></html>
    HTML

    with_url_page('https://example.test/updated-hearing', html) do |page|
      payload = extract_payload(page, reader_mode: false)
      expect(payload.fetch('excerpt')).to start_with(opening)
      expect(payload.fetch('markdown')).to include(opening, continuation)
    end
  end

  it 'keeps a locally date-named prose paragraph and still excludes a real publication field' do
    opening = 'The updated analysis documents the evidence and the full public response to the hearing.'
    continuation = 'The report records the witnesses and the independent review of every decision.'
    html = <<~HTML
      <html><head><title>Public review</title></head><body><main><article>
        <h1>Public review</h1><p class="published-date">Jan. 2, 2026, visit link for details.</p>
        <p class="updated-analysis date-report">#{opening}</p><p>#{continuation}</p>
      </article></main></body></html>
    HTML

    with_url_page('https://example.test/public-review', html) do |page|
      [false, true].each do |reader_mode|
        payload = extract_payload(page, reader_mode: reader_mode)
        expect(payload.fetch('excerpt')).to start_with(opening)
        expect(payload.fetch('excerpt')).not_to include('visit link for details')
        expect(payload.fetch('markdown')).to include(opening, continuation)
      end
    end
  end
end
