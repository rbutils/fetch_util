# frozen_string_literal: true

RSpec.describe 'FetchUtil homepage landing ownership' do
  include_context 'extractor integration helpers'

  it 'keeps an externally headed landing and resolves its prose owner after hidden content is pruned' do
    html = <<~HTML
      <html><head><title>Helpful money choices | Example Finance</title></head>
      <body><main>
        <article hidden>
          <p>Hidden copy must never become the selected visible landing owner.</p>
          <p>Its article index also differs from the index in the visibility-pruned tree.</p>
        </article>
        <div class="page-introduction"><h1>Make a confident money choice</h1>
          <a href="/loans/">Compare personal loans</a></div>
        <article class="page-copy">
          <p>Our team brings together practical financial information and useful services to help people make confident decisions.</p>
          <p>We explain the choices clearly, compare trusted providers, and make the next step easy for every reader.</p>
          <p>Our specialists review the information regularly and keep this guidance useful and transparent.</p>
          <div class="partner-logos"><img src="/partner-one.svg" alt="Partner one">
            <img src="/partner-two.svg" alt="Partner two"></div>
        </article>
        <a href="/cards/">Compare credit cards</a>
      </main></body></html>
    HTML

    with_url_page('https://finance.example/', html) do |page|
      payload = extract_payload(page)

      expect_content_type(payload, 'article')
      expect(payload['markdown']).to include(
        'Make a confident money choice', 'trusted providers', '/partner-one.svg', '/partner-two.svg'
      )
      expect(payload['html']).to include('/loans/', '/cards/')
      expect(payload['markdown']).not_to include('Hidden copy')
    end
  end

  it 'keeps multiple independently headed article bodies as a homepage list' do
    records = (1..4).map do |index|
      <<~HTML
        <article><h2><a href="/story/report-#{index}00001">Independent report #{index}</a></h2>
          <p>Report #{index} describes its own verified facts and its own publication context for readers.</p>
          <p>This summary is owned by one linked record, separate from every other homepage item.</p>
        </article>
      HTML
    end.join
    html = <<~HTML
      <html><head><title>Latest reports | Example Finance</title></head>
      <body><main><h1>Latest reports</h1>#{records}</main></body></html>
    HTML

    with_url_page('https://finance.example/', html) do |page|
      payload = extract_payload(page)

      expect_content_type(payload, 'list')
      expect(payload['markdown']).to include('Independent report 1', 'Independent report 4')
    end
  end

  it 'does not bind long page-level paragraphs to foreign headed records' do
    records = (1..2).map do |index|
      <<~HTML
        <article><h2><a href="/story/foreign-#{index}00001">Foreign headline #{index}</a></h2>
          <p>A short summary of a different linked record with separate ownership.</p>
        </article>
      HTML
    end.join
    html = <<~HTML
      <html><head><title>Finance information | Example Finance</title></head>
      <body><main><h1>Finance information</h1>
        <p>Our editors explain the financial information readers need to compare services and make clear decisions.</p>
        <p>Explore practical resources, review the available options, and choose a service that suits your needs.</p>
        <a href="/loans/">Loan services</a><a href="/cards/">Card services</a>
        <img src="/logo-one.svg"><img src="/logo-two.svg">#{records}
      </main></body></html>
    HTML

    with_url_page('https://finance.example/', html) do |page|
      payload = extract_payload(page)

      expect_content_type(payload, 'list')
      expect(payload['markdown']).to include('Foreign headline 1', 'Foreign headline 2')
    end
  end

  it 'does not use hidden or navigation-only links and logos as landing evidence' do
    html = <<~HTML
      <html><head><title>Helpful money choices | Example Finance</title></head>
      <body><main><div class="page-introduction"><h1>Make a confident money choice</h1></div>
        <article class="page-copy">
          <p>Our team provides practical financial information to help every reader make confident decisions.</p>
          <p>We explain the available choices clearly and keep the guidance useful and transparent.</p>
          <img hidden src="/hidden-logo.svg">
        </article>
        <nav><a href="/loans/">Compare personal loans</a><a href="/cards/">Compare credit cards</a>
          <img src="/navigation-logo-one.svg"><img src="/navigation-logo-two.svg"></nav>
        <div hidden><a href="/hidden-service/">Hidden service</a></div>
      </main></body></html>
    HTML

    with_url_page('https://finance.example/', html) do |page|
      payload = extract_payload(page)

      expect(payload['markdown']).to include('Our team provides practical financial information')
      expect(payload['html']).not_to include('/hidden-logo.svg', '/navigation-logo-one.svg',
                                             '/navigation-logo-two.svg', 'Compare personal loans',
                                             'Hidden service')
    end
  end

  it 'preserves a canonical homepage article and does not replace its strict focal preview with the main container' do
    html = <<~HTML
      <html><head><title>Credit review update | Example Finance</title>
        <meta property="og:type" content="NewsArticle">
        <link rel="canonical" href="https://finance.example/">
        <script type="application/ld+json">
          {"@type":"NewsArticle","headline":"Credit review update","mainEntityOfPage":"https://finance.example/"}
        </script>
      </head><body><main>
        <article class="article-content"><h1>Credit review update</h1>
          <p>Credit specialists reviewed the application criteria and published a detailed update for customers.</p>
          <p>The report explains how the review changed the available terms and what readers should consider next.</p>
        </article>
        <aside><a href="/support/">Support center</a><img src="/sidebar-logo.svg">
          <p>Sidebar material is not part of the article preview and must not widen its extraction.</p></aside>
      </main></body></html>
    HTML

    with_url_page('https://finance.example/', html) do |page|
      payload = extract_payload(page)

      expect_content_type(payload, 'article')
      expect(payload['title']).to eq('Credit review update')
      expect(payload['markdown']).to include('Credit specialists reviewed the application criteria')
      expect(payload['markdown']).not_to include('Sidebar material', '/sidebar-logo.svg', '/support/')
    end
  end
end
