# frozen_string_literal: true

RSpec.describe 'Article-owned interface widgets' do
  include_context 'extractor integration helpers'

  it 'removes empty discussion and recommendation loaders without deleting loaded content' do
    html = <<~HTML
      <html><head><title>Independent local report</title></head><body><article>
      <h1>Independent local report</h1><p>The investigation describes the original records and the evidence supporting its conclusions. Readers can consult the complete public record and evaluate the qualifications explained throughout this detailed article.</p>
      <p>Contact information in the <a href="/evidence">original evidence</a> is part of the account and remains relevant to independent verification.</p>
      <div class="article-call-to-action"><div>Send your story to the newsroom.</div><a href="/submit">Send a story</a><a href="/careers">Work with us</a></div>
      <div class="article-read-more-container"><div class="main-loader"><div>Preparing recommended entries</div></div></div>
      <div class="comments-container"><div class="main-loader"><div>Preparing the discussion</div></div>
        <div class="comment-body"><p>A reader supplied an additional source that qualifies the report and explains the practical context.</p>
          <div class="reply-body"><p>The author replied with the original measurement and a useful clarification.</p></div></div>
      </div>
      <div class="article-read-more-container"><div class="main-loader"><p>A fully loaded explanation with a <a href="/source">supporting source</a> is substantive content despite its presentation class.</p></div></div>
      <div class="comments-container"><div class="main-loader"><div class="author">Independent observer</div><span>A first-hand observation is material even when this wrapper retains its loader class.</span></div></div>
      <div class="loader"><div>An independently described operational state remains part of this account.</div></div>
      </article></body></html>
    HTML
    with_url_page('https://journal.example/report', html) do |page|
      original = page.evaluate('document.body.innerHTML')
      result = FetchUtil::Extractor.new(reader_mode: false).extract(page)
      markdown = result.fetch('markdown')
      expect(markdown).not_to include('Preparing recommended entries', 'Preparing the discussion', 'Send a story', 'Work with us')
      expect(markdown).to include('A reader supplied', 'The author replied', 'A fully loaded explanation')
      expect(markdown).to include('[original evidence](https://journal.example/evidence)', '[supporting source](https://journal.example/source)')
      expect(markdown).to include('An independently described operational state')
      expect(markdown).to include('Independent observer', 'A first-hand observation')
      expect(page.evaluate('document.body.innerHTML')).to eq(original)
    end
  end

  it 'preserves substantive explanations within call-to-action presentation wrappers' do
    html = <<~HTML
      <html><head><title>Public evidence and support</title></head><body><article>
      <h1>Public evidence and support</h1><p>This detailed account explains the evidence and the methods used to collect it. The independently published observations provide important context for readers who want to understand the conclusions and reproduce the original investigation.</p>
      <div class="article-call-to-action"><h2>How the evidence was funded</h2><p>The public support programme funded independent measurements, and the authors disclose the exact relationship here. This explanation is material to the account rather than a short request for donations.</p><a href="/funding">Funding record</a></div>
      </article></body></html>
    HTML
    extract_from_url('https://journal.example/evidence', html) do |result|
      expect(result.fetch('markdown')).to include('How the evidence was funded', 'independent measurements', 'Funding record')
    end
  end

  it 'removes compact multilingual share controls without deleting article prose or linked sources' do
    html = <<~HTML
      <html><head><title>Public tournament report</title></head><body><main><article>
      <h1>Public tournament report</h1>
      <p>The appeal commission reviewed the match record and explained why the original decision remains in force for the upcoming round of the tournament.</p>
      <div class="story-more-options">Compartilhe Ícone Facebook Facebook Ícone Whatsapp Whatsapp Copiar link</div>
      <p>Readers can examine the <a href="/decision">written decision</a> and the detailed account of the hearing without using the sharing controls.</p>
      <div class="story-options"><p>The report describes how Facebook and Whatsapp responded to the coverage and explains what the authors learned from their statements.</p><a href="/statements">Public statements</a></div>
      <p>The final section supplies further source context about the appeal and how it affects the teams participating in the tournament.</p>
      </article></main></body></html>
    HTML

    with_url_page('https://journal.example/tournament', html) do |page|
      before = page.evaluate('document.body.innerHTML')
      payload = FetchUtil::Extractor.new(reader_mode: false).extract(page)
      expect(payload.fetch('markdown')).not_to include('Compartilhe Ícone', 'Copiar link')
      expect(payload.fetch('markdown')).to include('written decision', 'Facebook and Whatsapp responded', 'Public statements')
      expect(payload.fetch('markdown')).to include('The final section supplies further source context')
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end

  it 'removes only compact refresh controls beside a visible article timeline' do
    html = <<~HTML
      <html><head><title>Public wildfire updates</title></head><body><article>
        <h1>Public wildfire updates</h1>
        <p>Emergency crews contained the first fire after a full afternoon of work, and local residents received a complete account of the response.</p>
        <section><h2>First source-owned update</h2><p>Officials described the conditions around the first fire and the resources used to protect nearby homes.</p></section>
        <section><h2>Second source-owned update</h2><p>The regional team reported the second fire under control and explained what work remains.</p></section>
        <div class="c-detail--mam__refresh-button">Último minuto</div>
        <section><h2>Third source-owned update</h2><p>A third briefing explained the aftermath and the next steps for the affected area.</p></section>
        <div class="story-refresh-control"><h2>Latest updates</h2><p>This is substantive editorial context, not a compact refresh control.</p></div>
        <h2>Último minuto</h2><p>This editorial heading is separate from the refresh control and remains visible.</p>
      </article></body></html>
    HTML

    with_url_page('https://journal.example/updates', html) do |page|
      before = page.evaluate('document.body.innerHTML')
      markdown = FetchUtil::Extractor.new(reader_mode: false).extract(page).fetch('markdown')
      %w[First Second Third].each { |ordinal| expect(markdown).to include("#{ordinal} source-owned update") }
      expect(markdown.scan('Último minuto').length).to eq(1)
      expect(markdown).to include('This is substantive editorial context', 'separate from the refresh control')
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end

  it 'drops a synthetic summary prompt while retaining an article about artificial intelligence' do
    html = <<~HTML
      <html><head><title>Public investigation of automated summaries</title></head><body><article>
        <h1>Public investigation of automated summaries</h1>
        <div class="summary-player">Ver resumenTiempo de lectura: 16s Inteligencia Artificial Experimental: Resumen y análisis automáticos realizados con Inteligencia Artificial</div>
        <p>The investigation describes what the public dataset actually shows about automatic summaries and explains the methods used to inspect the original reports.</p>
        <p>Researchers tested artificial intelligence in the public sector and published a detailed analysis of its effects on access to government records.</p>
        <p>The final section gives readers enough context to evaluate the sources, including limitations and independent responses to the proposed process.</p>
      </article></body></html>
    HTML

    with_url_page('https://journal.example/reports/automated-summaries', html) do |page|
      before = page.evaluate('document.body.innerHTML')
      markdown = extract_payload(page).fetch('markdown')
      expect(markdown).not_to include('Ver resumenTiempo de lectura', 'Experimental: Resumen')
      expect(markdown).to include('Researchers tested artificial intelligence', 'evaluate the sources')
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end

  it 'removes only structurally empty article ad placeholders' do
    html = <<~HTML
      <html><head><title>Regional transport investigation</title>
      <style>
      .generated-visual::before { content: "Sponsored feature"; }
      .background-visual { background-image: linear-gradient(#fff, #eee); }
      .shadow-visual { box-shadow: 0 0 8px #333; }
      .filter-visual { filter: drop-shadow(0 0 4px #333); }
      .outline-visual { outline: 2px solid #333; }
      .empty-pseudo-visual::before { content: ""; display: block; width: 12px; height: 12px; background: #333; }
      .visible-box { display: block; width: 12px; height: 12px; }
      </style></head><body><article>
      <h1>Regional transport investigation</h1>
      <p>The investigation reviews the first set of public records and explains why the measurements matter to people using the regional transport network.</p>
      <div id="empty-ad" class="banner banner--article" data-placeholder-caption="Advertisement"><div class="wrapperAd"></div></div>
      <span id="empty-span-ad" class="ad" data-placeholder-caption="Advertisement"><span class="wrapperAd"></span></span>
      <div id="substantive-ad" data-placeholder-caption="Advertisement"><div class="wrapperAd"><p>The sponsorship disclosure explains who funded the measurements and remains material context for this report.</p></div></div>
      <div id="linked-ad" data-placeholder-caption="Advertisement"><div class="wrapperAd"><a href="/funding">Funding record</a></div></div>
      <div id="media-ad" data-placeholder-caption="Advertisement"><div class="wrapperAd"><img src="/evidence.jpg" alt="Evidence chart"></div></div>
      <div id="form-ad" data-placeholder-caption="Advertisement"><div class="wrapperAd"><form><label>Research query <input name="query"></label></form></div></div>
      <div id="custom-ad" data-placeholder-caption="Advertisement"><div class="wrapperAd"><evidence-slot></evidence-slot></div></div>
      <div id="named-anchor-ad" data-placeholder-caption="Advertisement"><div class="wrapperAd"><a id="funding-record"></a></div></div>
      <div id="aria-ad" data-placeholder-caption="Advertisement"><div class="wrapperAd" role="button" aria-label="Open sponsor settings"></div></div>
      <div id="resource-ad" data-placeholder-caption="Advertisement"><div class="wrapperAd" data-url="/sponsor-record"></div></div>
      <div id="styled-ad" data-placeholder-caption="Advertisement"><div class="wrapperAd" style="background-image: url('/sponsor.png')"></div></div>
      <div id="structured-ad" data-placeholder-caption="Advertisement"><div class="wrapperAd"><table><tbody><tr><td></td></tr></tbody></table></div></div>
      <div id="relationship-ad" data-placeholder-caption="Advertisement"><div class="wrapperAd" aria-controls="sponsor-panel"></div></div>
      <div id="data-image-ad" data-placeholder-caption="Advertisement"><div class="wrapperAd" data-image="/sponsor-image.png"></div></div>
      <div id="root-data-ad" class="ad" data-placeholder-caption="Advertisement" data-image="/root-sponsor.png"></div>
      <div id="semantic-ad" data-placeholder-caption="Advertisement"><div class="wrapperAd"><nav aria-label="Sponsor resources"></nav></div></div>
      <div id="template-ad" data-placeholder-caption="Advertisement"><div class="wrapperAd"><template><p>Deferred sponsor disclosure</p></template></div></div>
      <div id="inline-semantic-ad" data-placeholder-caption="Advertisement"><div class="wrapperAd"><strong></strong></div></div>
      <a href="#referenced-ad">Open referenced sponsor details</a>
      <div id="referenced-ad" class="ad" data-placeholder-caption="Advertisement"><div class="wrapperAd"></div></div>
      <button aria-controls="controlled-ad">Open controlled sponsor details</button>
      <div id="controlled-ad" class="ad" data-placeholder-caption="Advertisement"><div class="wrapperAd"></div></div>
      <button contextmenu="context-menu-ad">Open sponsor context menu</button>
      <div id="context-menu-ad" class="ad" data-placeholder-caption="Advertisement"><div class="wrapperAd"></div></div>
      <div itemscope itemref="microdata-ad">Sponsor metadata owner</div>
      <div id="microdata-ad" class="ad" data-placeholder-caption="Advertisement"><div class="wrapperAd"></div></div>
      <svg><use xlink:href="#svg-referenced-ad"></use></svg>
      <div id="svg-referenced-ad" class="ad" data-placeholder-caption="Advertisement"><div class="wrapperAd"></div></div>
      <div id="generated-ad" class="ad generated-visual" data-placeholder-caption="Advertisement"><div class="wrapperAd"></div></div>
      <div id="background-ad" class="ad background-visual" data-placeholder-caption="Advertisement"><div class="wrapperAd"></div></div>
      <div id="shadow-style-ad" class="ad shadow-visual" data-placeholder-caption="Advertisement"><div class="wrapperAd"></div></div>
      <div id="filter-ad" class="ad filter-visual" data-placeholder-caption="Advertisement"><div class="wrapperAd"></div></div>
      <div id="outline-ad" class="ad outline-visual" data-placeholder-caption="Advertisement"><div class="wrapperAd"></div></div>
      <div id="empty-pseudo-ad" class="ad empty-pseudo-visual" data-placeholder-caption="Advertisement"><div class="wrapperAd"></div></div>
      <div id="visible-box-ad" class="ad visible-box" data-placeholder-caption="Advertisement"><div class="wrapperAd"></div></div>
      <div id="empty-widget" class="placeholder" data-placeholder-caption="Advertisement"><div class="wrapperSlot"></div></div>
      <div id="nested-ad" class="ad" data-placeholder-caption="Advertisement"><div id="nested-slot" class="ad" data-placeholder-caption="Sponsored"><div class="wrapperAd"></div></div></div>
      <label for="label-referenced-ad">Sponsor label</label>
      <div id="label-referenced-ad" class="ad" data-placeholder-caption="Advertisement"><div class="wrapperAd"></div></div>
      <svg><animate begin="timed-reference-ad.begin"></animate></svg>
      <div id="timed-reference-ad" class="ad" data-placeholder-caption="Advertisement"><div class="wrapperAd"></div></div>
      <svg><use href="/sprite.svg#symbol" xlink:href="#mixed-referenced-ad"></use></svg>
      <div id="mixed-referenced-ad" class="ad" data-placeholder-caption="Advertisement"><div class="wrapperAd"></div></div>
      <div id="duplicate-ad" class="ad" data-placeholder-caption="Advertisement"><div class="wrapperAd"></div></div>
      <div id="duplicate-ad" class="ad" data-placeholder-caption="Advertisement"><div class="wrapperAd"></div></div>
      <div class="ad no-id-placeholder" data-placeholder-caption="Advertisement"><div class="wrapperAd"></div></div>
      <a href="https://[::1#malformed-external-ad">Malformed external destination</a>
      <div id="malformed-external-ad" class="ad" data-placeholder-caption="Advertisement"><div class="wrapperAd"></div></div>
      <a href="https://user@journal.example/transport#credential-external-ad">Credential external destination</a>
      <div id="credential-external-ad" class="ad" data-placeholder-caption="Advertisement"><div class="wrapperAd"></div></div>
      <a href="https://archive.example/report#valid-external-ad">Valid external destination</a>
      <div id="valid-external-ad" class="ad" data-placeholder-caption="Advertisement"><div class="wrapperAd"></div></div>
      <div id="closed-shadow-ad" class="ad" data-placeholder-caption="Advertisement"></div>
      <script>
      window.closedShadowHost = document.querySelector('#closed-shadow-ad');
      window.closedShadowRoot = window.closedShadowHost.attachShadow({ mode: 'closed' });
      window.closedShadowRoot.innerHTML = '<span>Visible sponsor disclosure</span>';
      </script>
      <p>The final section records the independent checks, links the source documents, and gives readers enough detail to reproduce the analysis.</p>
      </article></body></html>
    HTML

    with_url_page('https://journal.example/transport', html) do |page|
      original = page.evaluate('document.body.innerHTML')
      result = FetchUtil::Extractor.new(reader_mode: false).extract(page)
      returned_html = result.fetch('html')
      markdown = result.fetch('markdown')

      expect(returned_html).not_to include('id="empty-ad"')
      expect(returned_html).not_to include('id="empty-span-ad"', 'id="valid-external-ad"')
      expect(returned_html).to include('id="substantive-ad"', 'id="linked-ad"', 'id="media-ad"')
      expect(returned_html).to include('id="form-ad"', 'id="custom-ad"')
      expect(returned_html).to include('id="named-anchor-ad"', 'id="aria-ad"', 'id="resource-ad"')
      expect(returned_html).to include('id="styled-ad"', 'id="structured-ad"')
      expect(returned_html).to include('id="relationship-ad"', 'id="data-image-ad"', 'id="root-data-ad"', 'id="semantic-ad"')
      expect(returned_html).to include('id="referenced-ad"', 'id="controlled-ad"')
      expect(returned_html).to include('id="context-menu-ad"')
      expect(returned_html).to include('id="microdata-ad"', 'id="svg-referenced-ad"')
      expect(returned_html).to include('id="generated-ad"', 'id="background-ad"')
      expect(returned_html).to include('id="shadow-style-ad"', 'id="filter-ad"', 'id="outline-ad"')
      expect(returned_html).to include('id="empty-pseudo-ad"', 'id="visible-box-ad"', 'id="empty-widget"')
      expect(returned_html).to include('id="nested-ad"', 'id="nested-slot"')
      expect(returned_html).to include('id="label-referenced-ad"', 'id="timed-reference-ad"')
      expect(returned_html).to include('id="mixed-referenced-ad"', 'no-id-placeholder', 'id="closed-shadow-ad"')
      expect(returned_html.scan('id="duplicate-ad"').length).to eq(2)
      expect(returned_html).to include('id="malformed-external-ad"', 'id="credential-external-ad"')
      expect(returned_html).to include('sponsorship disclosure', 'Funding record', 'evidence.jpg', 'Evidence chart')
      expect(markdown).to include('Regional transport investigation')
      expect(page.evaluate('document.querySelector("#closed-shadow-ad") === window.closedShadowHost')).to be(true)
      expect(page.evaluate('window.closedShadowRoot.textContent')).to eq('Visible sponsor disclosure')
      expect(page.evaluate('document.body.innerHTML')).to eq(original)
    end
  end

  it 'removes an empty ad placeholder owned by an articleBody root' do
    html = <<~HTML
      <html><head><title>Transit records explained</title></head><body>
      <div itemprop="articleBody">
      <h1>Transit records explained</h1>
      <p>The opening paragraph explains the public transit records in enough detail to establish a substantive article body for readers.</p>
      <div id="article-body-ad" data-placeholder-caption="Advertisement"><div class="advert-slot"></div></div>
      <p>The concluding paragraph documents the independent checks and describes how readers can reproduce the published measurements.</p>
      </div>
      </body></html>
    HTML

    with_url_page('https://journal.example/transit-records', html) do |page|
      original = page.evaluate('document.body.innerHTML')
      result = FetchUtil::Extractor.new(reader_mode: false).extract(page)

      expect(result.fetch('html')).not_to include('id="article-body-ad"')
      expect(result.fetch('markdown')).to include('Transit records explained')
      expect(page.evaluate('document.body.innerHTML')).to eq(original)
    end
  end

  it 'preserves empty ad placeholders without article ownership' do
    html = <<~HTML
      <html><head><title>Transit records index</title></head><body><main>
      <h1>Transit records index</h1>
      <p>The index explains how residents can locate public transit records and review the complete published measurements.</p>
      <div id="outside-article-ad" data-placeholder-caption="Advertisement"><div class="wrapperAd"></div></div>
      <p>The concluding guidance describes each available record and the independent checks applied before publication.</p>
      </main></body></html>
    HTML

    with_url_page('https://journal.example/transport-index', html) do |page|
      original = page.evaluate('document.body.innerHTML')
      result = FetchUtil::Extractor.new(reader_mode: false).extract(page)

      expect(result.fetch('html')).to include('id="outside-article-ad"')
      expect(page.evaluate('document.body.innerHTML')).to eq(original)
    end
  end

  it 'preserves deeply nested placeholders without repeated subtree admission' do
    nested = '<div class="wrapperAd"></div>'
    180.times do |index|
      nested = %(<div id="nested-placeholder-#{index}" class="ad" data-placeholder-caption="Advertisement">#{nested}</div>)
    end
    html = <<~HTML
      <html><head><title>Nested placeholder controls</title></head><body><article>
      <h1>Nested placeholder controls</h1>
      <p>The opening paragraph provides enough substantive reporting to establish one focal article for this nested-boundary regression.</p>
      #{nested}
      <p>The final paragraph documents the verification steps and preserves the complete source context around every nested placeholder.</p>
      </article></body></html>
    HTML

    with_url_page('https://journal.example/nested-placeholders', html) do |page|
      original = page.evaluate('document.body.innerHTML')
      result = FetchUtil::Extractor.new(reader_mode: false).extract(page)

      expect(result.fetch('html').scan('data-placeholder-caption="Advertisement"').length).to eq(180)
      expect(page.evaluate('document.body.innerHTML')).to eq(original)
    end
  end
end
