# frozen_string_literal: true

RSpec.describe 'FetchUtil article/list arbitration' do
  include_context 'extractor integration helpers'

  def body_present_fixture
    File.expand_path('../../fixtures/article_route_body_present.html', __dir__)
  end

  def related_only_fixture
    File.expand_path('../../fixtures/article_route_related_only.html', __dir__)
  end

  def homepage_article_with_directory_fixture(path_prefix:, paragraph_count:, item_count:, wrapped_card:, context_paragraph_count: 0)
    paragraphs = (1..paragraph_count).map do |index|
      <<~HTML
        <p>Operational section #{index} explains how the platform coordinates implementation planning, data governance,
        deployment architecture, training, and long-term support for teams with different technical requirements. It
        describes the decisions customers make before launch, the safeguards used during migration, and the specialists
        who keep each rollout reliable after production traffic arrives. This material is the primary explanation a
        reader needs in order to understand the service rather than a caption for any directory link.</p>
      HTML
    end.join
    article_body = <<~HTML
      <h1>Platform implementation and customer operations</h1>
      #{paragraphs}
      <a href="#{path_prefix}1">More</a>
    HTML
    context_paragraphs = (1..context_paragraph_count).map do |index|
      %(<p>Directory group #{index}</p>)
    end.join

    <<~HTML
      <div id="article-content"#{' class="card"' if wrapped_card}>
        #{wrapped_card ? article_body : %(<div class="card">#{article_body}</div>)}
      </div>
      <main>
        #{context_paragraphs}
        <ul class="itemlist">
          #{(1..item_count).map { |index| %(<li><a href="#{path_prefix}#{index}">Directory record #{index} with operational guidance</a></li>) }.join}
        </ul>
      </main>
    HTML
  end

  def weak_portal_article_fixture
    paragraphs = (1..6).map do |index|
      <<~HTML
        <p>Trust program section #{index} explains how credential teams coordinate governance, implementation planning,
        issuer verification, privacy reviews, and long-term support across a distributed workforce. It documents the
        decisions administrators make before launch, the evidence reviewers inspect during delivery, and the safeguards
        that keep each deployment reliable as organizations add new learners, partners, and regional requirements.</p>
      HTML
    end.join

    <<~HTML
      <html><head><title>TrustCloud workforce credential platform</title></head><body>
        <main>
          <h1>Build trusted workforce programs</h1>
          <p>Teams can search verified records when evaluating program outcomes without turning this explanation into a directory.</p>
          #{paragraphs}
          <div class="content-group"><h2>Technology for credential teams</h2>
            <div class="card"><a href="/credentials/issue"><h3>Issue portable credentials for every learner</h3></a></div>
            <div class="card"><a href="/credentials/connect"><h3>Connect verified skills with workforce opportunities</h3></a></div>
          </div>
          <div class="content-group"><h2>Evidence across the network</h2>
            <div class="card"><a href="/credentials/measure"><h3>Measure program outcomes across every region</h3></a></div>
          </div>
        </main>
        <aside class="product-grid">
          <div class="product-card"><a href="/product/workforce-response">Workforce credential response service</a></div>
          <div class="product-card"><a href="/product/security-analytics">Credential security analytics platform</a></div>
          <div class="product-card"><a href="/product/identity-governance">Workforce identity governance toolkit</a></div>
          <div class="product-card"><a href="/product/program-assurance">Credential program assurance suite</a></div>
        </aside>
      </body></html>
    HTML
  end

  def trailing_privacy_article_fixture
    core_paragraphs = (1..3).map do |index|
      <<~HTML
        <p>Delivery section #{index} explains how publisher teams coordinate auction quality, inventory governance,
        implementation planning, measurement, and long-term operational support. It documents the decisions specialists
        make before launch, the safeguards applied to every campaign, and the evidence reviewed after delivery.</p>
      HTML
    end.join
    context_paragraphs = (1..5).map do |index|
      <<~HTML
        <p>Platform context #{index} connects publishers with transparent advertising demand while preserving direct
        control over inventory, reporting, and campaign quality across every supported channel.</p>
      HTML
    end.join

    <<~HTML
      <html><head><title>Publisher delivery platform</title></head><body><main>
        <div id="platform-content">
          <h1>Publisher delivery platform</h1>
          <p>Our supply-side platform gives publishers one accountable place to manage advertising inventory and delivery.</p>
          #{context_paragraphs}
          <section id="core-delivery"><h2>Core delivery model</h2>#{core_paragraphs}</section>
          <section><h2>Benefits for publishers</h2><ul>
            <li>One platform coordinates every approved source of demand for publisher teams.</li>
            <li>Bundled demand reaches audiences across every supported channel and device.</li>
            <li>Transparent controls let publishers review quality, pricing, and delivery evidence.</li>
            <li>Additional demand can be enabled without replacing the publisher workflow.</li>
          </ul></section>
          <section class="resource-grid"><h2>Publisher resources</h2>
            #{(1..4).map { |index| %(<article class="card"><a href="/resources/#{index}">Publisher resource #{index} with implementation guidance</a></article>) }.join}
          </section>
          <section><h2>Privacy choices</h2><p>Privacy policy and cookie settings explain how visitors can manage consent preferences.</p><a href="/privacy">Manage privacy choices</a></section>
        </div>
      </main></body></html>
    HTML
  end

  def extract_with_readability_root(page, root_expression)
    extractor_for(true).__send__(:inject_assets, page)
    page.evaluate <<~JS
      (() => {
        const NarrowReadability = function() {};
        NarrowReadability.prototype.parse = function() {
          const root = #{root_expression};
          return {
            title: 'Core delivery model',
            content: root.outerHTML,
            textContent: root.textContent
          };
        };
        window.Readability = NarrowReadability;

        return window.FetchUtilExtract.extract({ reader_mode: true });
      })()
    JS
  end

  it 'keeps distinct source records that share the same destination' do
    shared_url = '/unodc/treaties/CTOC/CTOC-COP-session13.html'
    records = [
      ['Thirteenth session records in Arabic', 'Arabic', '22 September 2021', 'Arab-language proceedings and outcomes', shared_url],
      ['Thirteenth session records in Chinese', 'Chinese', '22 September 2021', 'Chinese-language proceedings and outcomes', shared_url],
      ['Thirteenth session records in Spanish', 'Spanish', '22 September 2021', 'Spanish-language proceedings and outcomes', shared_url],
      ['Convention implementation report', 'English', '10 October 2024', 'Implementation findings for national authorities', '/unodc/treaties/implementation-report.html']
    ]
    rows = records.map do |title, language, date, detail, url|
      %(<article class="search-result"><h2>#{title}</h2><p>#{language} · #{date} · #{detail}</p><a href="#{url}">#{url}</a></article>)
    end.join
    html = <<~HTML
      <html><head><title>Search results</title></head><body><main>
        <h1>Search results</h1><section class="results">#{rows}</section>
      </main></body></html>
    HTML

    with_url_page('https://search.example/unodc/search', html) do |page|
      before = page.evaluate('document.body.innerHTML')
      payload = FetchUtil::Extractor.new.extract(page)
      markdown = payload.fetch('markdown')

      expect(payload['contentType']).to eq('list')
      records.each do |title, language, date, detail, _url|
        expect(markdown).to include(title)
        expect(markdown).to include(language)
        expect(markdown).to include(date)
        expect(markdown).to include(detail)
      end
      expect(markdown.scan("](https://search.example#{shared_url})").length).to eq(3), markdown
      expect(markdown).to include('https://search.example/unodc/treaties/implementation-report.html')
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end

  it 'keeps service-page table material when product tabs form a smaller product list' do
    table_rows = (1..6).map do |index|
      <<~HTML
        <tr><th>Service feature #{index}</th><td>Feature #{index} supplies a distinct public news service
        with detailed source material for analysts and newsroom teams.</td></tr>
      HTML
    end.join
    product_tabs = (1..4).map do |index|
      %(<a href="/product/service-#{index}">Public news service option #{index}</a>)
    end.join
    html = <<~HTML
      <html><head><title>Global news services</title></head><body><main>
        <h1>Global news services</h1>
        <p>Organizations use the service to review accurate reporting, source data, and public information before making time-sensitive decisions. Dedicated editorial teams publish current material across local and international topics.</p>
        <h2>How the service supports customers</h2>
        <p>Customers receive verified reporting and clear contextual guidance for their work. The service includes reliable delivery, professional research tools, and a documented process for requesting additional information.</p>
        <table><tbody>#{table_rows}</tbody></table>
        <section class="service-options"><h2>Choose a service</h2>#{product_tabs}</section>
      </main></body></html>
    HTML

    extract_from_url('https://publisher.example/product/premium-services', html) do |payload|
      expect(payload['contentType']).to eq('article')
      expect(payload['markdown']).to include('Feature 1 supplies a distinct public news service')
      expect(payload['markdown']).to include('Feature 6 supplies a distinct public news service')
    end
  end

  it 'protects every owned table cell from a product-list replacement even in a small table' do
    table_rows = (1..2).map do |index|
      <<~HTML
        <tr><th>Service product tab #{index}</th>
          <td>Eligibility detail #{index} explains a distinct requirement for customers and applicants.</td></tr>
      HTML
    end.join
    product_tabs = (1..4).map do |index|
      %(<a href="/product/tab-#{index}">Service product tab #{index}</a>)
    end.join
    article_paragraphs = (1..3).map do |index|
      "The public program section #{index} documents the eligibility rules, review history, supporting evidence, " \
        'and access instructions that customers need before selecting a service option. These published details ' \
        'explain the scope and limitations of each service.'
    end
    html = <<~HTML
      <html><head><title>Public service options</title>
        <link rel="canonical" href="https://publisher.example/product/services">
        <script type="application/ld+json">{"@context":"https://schema.org","@type":"NewsArticle","url":"https://publisher.example/product/services","headline":"Public service options"}</script>
      </head><body><main><article><h1>Public service options</h1>
        #{article_paragraphs.map { |paragraph| "<p>#{paragraph}</p>" }.join}
        <table><tbody>#{table_rows}</tbody></table>
      </article>
        <section>#{product_tabs}</section>
      </main></body></html>
    HTML

    extract_from_url('https://publisher.example/product/services', html) do |payload|
      expect(payload['contentType']).to eq('article'), payload.slice('contentType', 'title', 'markdown').inspect
      (1..2).each do |index|
        expect(payload['markdown']).to include("Service product tab #{index}")
        expect(payload['markdown']).to include("Eligibility detail #{index} explains a distinct requirement for customers and applicants")
      end
    end
  end

  it 'restores a primary service owner displaced by an interactive article heading' do
    service_details = [
      'Instalments provide a reusable service account for customers who want to spread eligible purchase costs',
      'across predictable monthly payments. Applicants review the terms before checkout, and the provider explains',
      'eligibility, approval, repayment limits, and how the account can be reused. This public introduction describes',
      'the service itself and its customer-facing terms, including who can apply, where customers can find help,',
      'and how payment schedules relate to the separate credit limit.'
    ].join(' ')
    reader_details = [
      'The service guide explains how customers can review their payment plan, understand the credit limit, and see',
      'how repayments release available credit for future purchases. Customers should read the provider terms and',
      'confirm their own eligibility before using the service.'
    ].join(' ')
    html = <<~HTML
      <html><head><title>Amazon.co.uk: Instalments</title>
        <meta property="og:site_name" content="Amazon.co.uk"></head><body>
        <main><section class="service-owner"><h1>No hidden fees, no surprises</h1>
          <p>#{service_details}</p>
          <a href="/apply">Continue to checkout</a>
          <a href="/service-terms">Read service terms</a>
        </section><section class="unrelated-main-sibling"><h2>Regional travel report</h2>
          <p>This separate regional travel report describes rail routes, survey methods, visitor trends, and unrelated destinations for readers.</p>
          <a href="/travel/rail-report">Read the rail report</a>
        </section></main>
        <section class="calculator-panel"><article>
          <h1>See how much you might pay</h1>
          <p>Use this estimator to compare an example purchase amount and repayment schedule before applying.</p>
          <form><label>Purchase amount <input type="number" value="400"></label>
            <button type="button">Calculate estimate</button></form>
        </article></section>
        <section id="service-guide"><h2>How the instalment service works</h2>
          <p>#{reader_details}</p>
          <h2>Credit limit</h2>
          <p>The provider sets a total credit limit and a monthly payment limit for each customer.</p>
          <a href="/repayment-guide">Review repayment guidance</a>
        </section>
        <aside><h2>Separate travel coverage</h2>
          <p>This independently published travel feature does not describe the instalment service or its customers.</p>
          <a href="/travel/feature">Read the travel feature</a>
        </aside>
      </body></html>
    HTML

    extract_from_url('https://finance.example/instalments', html) do |payload|
      expect(payload['contentType']).to eq('article')
      expect(payload['title']).to eq('Amazon.co.uk: Instalments')
      expect(payload['markdown']).to include(service_details)
      expect(payload['markdown']).to include('Continue to checkout', '/service-terms')
      expect(payload['markdown']).to include(reader_details)
      expect(payload['markdown']).not_to include(
        'Separate travel coverage', 'independently published travel feature',
        'Regional travel report', 'regional travel report describes rail routes'
      )
    end
  end

  it 'does not promote a short primary header over a separate authored article' do
    article_details = (1..3).map do |index|
      [
        "Section #{index} explains the public program, its documented service workflow, and the practical guidance",
        'readers need to understand the independently authored report.'
      ].join(' ')
    end.join(' ')
    html = <<~HTML
      <html><head><title>Research report on public services</title></head><body>
        <header id="primary"><h1>Publisher introduction</h1><p>Welcome to our service.</p></header>
        <main><article><h1>Research report on public services</h1><p>#{article_details}</p>
          <a href="/research/source">Read the report source</a>
        </article></main>
      </body></html>
    HTML

    extract_from_url('https://research.example/reports/service-study', html) do |payload|
      expect(payload['contentType']).to eq('article')
      expect(payload['title']).to eq('Research report on public services')
      expect(payload['markdown']).to include(article_details)
      expect(payload['markdown']).not_to include('Publisher introduction')
    end
  end

  it 'does not recover a hidden primary page owner' do
    hidden_details = [
      'Hidden service guidance is not public source material and must not replace the visible authored article,',
      'even when it contains several links and a long description that resembles a complete page.'
    ].join(' ')
    article_details = [
      'This visible report explains the public service rules, the evidence available to readers, and how the independent',
      'team reached its conclusions. The complete authored text remains the selected article rather than hidden content',
      'from a neighboring page component.'
    ].join(' ')
    html = <<~HTML
      <html><head><title>Public service report</title></head><body>
        <div id="primary" style="display:none"><h1>Hidden service overview</h1>
          <p>#{hidden_details}</p><a href="/hidden/terms">Hidden terms</a>
          <a href="/hidden/start">Hidden application</a>
        </div>
        <main><article><h1>Public service report</h1><p>#{article_details}</p>
          <a href="/reports/evidence">Read the supporting evidence</a>
        </article></main>
      </body></html>
    HTML

    extract_from_url('https://reports.example/service', html) do |payload|
      expect(payload['contentType']).to eq('article')
      expect(payload['markdown']).to include(article_details)
      expect(payload['markdown']).not_to include('Hidden service overview')
      expect(payload['markdown']).not_to include(hidden_details)
    end
  end

  it 'does not borrow an unrelated primary service root for a mismatched page title' do
    article_details = (1..3).map do |index|
      "Section #{index} analyzes regional transport evidence, published routes, and recommendations for independent readers."
    end.join(' ')
    service_details = [
      'Customer services section one explains account-holder support, service requests, contact information, published forms,',
      'and account documentation. Section two describes a separate access workflow for account holders, service agents,',
      'and customers who need to review their documents. Section three explains contact methods, operating hours, account',
      'support boundaries, and where readers can locate the public service application materials.'
    ].join(' ')
    html = <<~HTML
      <html><head><title>Regional transport report</title>
        <link rel="canonical" href="https://research.example/reports/transport">
        <script type="application/ld+json">{"@context":"https://schema.org","@type":"NewsArticle","url":"https://research.example/reports/transport","headline":"Regional transport report"}</script>
      </head><body>
        <div id="primary"><h1>Customer services</h1><p>#{service_details}</p>
          <a href="/account">Open the account portal</a><a href="/support">Contact account support</a>
        </div>
        <article><h1>Regional transport report</h1><p>#{article_details}</p>
          <form><label>Choose a route <input type="text" value="A12"></label><button type="button">Check route</button></form>
        </article>
      </body></html>
    HTML

    extract_from_url('https://research.example/reports/transport', html) do |payload|
      expect(payload['contentType']).to eq('article')
      expect(payload['title']).to eq('Regional transport report')
      expect(payload['markdown']).to include(article_details)
      expect(payload['markdown']).not_to include('Customer services', service_details, '/account', '/support')
    end
  end

  it 'keeps a DW-style detail with twelve related links as an article' do
    url = 'https://www.dw.com/en/newsroom-report/a-77898335'

    extract_from_url(url, fixture_contents(body_present_fixture)) do |payload|
      expect(payload['contentType']).to eq('article')
      expect(payload['markdown']).to include('The report describes a developing story')
    end
  end

  it 'distinguishes focal BBC articles from related-only article routes' do
    routes = [
      ['https://www.bbc.com/somali/articles/c8r07734dp4o', true],
      ['https://www.bbc.com/somali/articles/c9r07734dp4o', true],
      ['https://www.bbc.com/somali/articles/c0r07734dp4o', false],
      ['https://www.bbc.com/somali/articles/c1r07734dp4o', false],
      ['https://www.bbc.com/yoruba/articles/c8r07734dp4o', true],
      ['https://www.bbc.com/yoruba/articles/c9r07734dp4o', true],
      ['https://www.bbc.com/yoruba/articles/c0r07734dp4o', false],
      ['https://www.bbc.com/yoruba/articles/c1r07734dp4o', false]
    ]

    routes.each do |url, body_present|
      html = fixture_contents(body_present ? body_present_fixture : related_only_fixture)
      extract_from_url(url, html) do |payload|
        expect(payload['contentType']).to eq(body_present ? 'article' : 'list'), url
        if body_present
          expect(payload['markdown']).to include('The report describes a developing story'), url
        else
          expect(payload['markdown']).to include('Related headline'), url
        end
      end
    end
  end

  it 'keeps an article with many inline links from generic list relabeling' do
    url = 'https://news.example/2026/07/11/inline-report'

    extract_from_url(url, fixture_contents(body_present_fixture)) do |payload|
      expect(payload['contentType']).to eq('article')
    end
  end

  it 'keeps material article prose when dominant index signals find a smaller directory' do
    html = homepage_article_with_directory_fixture(
      path_prefix: '/news/directory-record-',
      paragraph_count: 3,
      item_count: 6,
      context_paragraph_count: 6,
      wrapped_card: false
    )

    extract_from_url('https://portal.example/', html) do |payload|
      expect(payload['contentType']).to eq('article')
      expect(payload['markdown']).to include('Operational section 1 explains how the platform')
      expect(payload['markdown']).to include('Operational section 3 explains how the platform')
    end
  end

  it 'keeps material article prose when general list signals find a smaller directory' do
    html = homepage_article_with_directory_fixture(
      path_prefix: '/records/',
      paragraph_count: 5,
      item_count: 8,
      wrapped_card: true
    )

    extract_from_url('https://platform.example/', html) do |payload|
      expect(payload['contentType']).to eq('article')
      expect(payload['markdown']).to include('Operational section 1 explains how the platform')
      expect(payload['markdown']).to include('Operational section 5 explains how the platform')
    end
  end

  it 'keeps article material when body-only portal evidence precedes a product list' do
    extract_from_url('https://trustcloud.example/', weak_portal_article_fixture) do |payload|
      expect(payload['markdown']).to include('Trust program section 1 explains how credential teams')
      expect(payload['markdown']).to include('Trust program section 6 explains how credential teams')
      expect(payload['markdown']).not_to include('Credential security analytics platform')
    end
  end

  it 'keeps visible article sections when trailing privacy copy and a footer list overlap' do
    with_url_page('https://platform.example/publisher-delivery', trailing_privacy_article_fixture) do |page|
      payload = extract_with_readability_root(page, "document.querySelector('#core-delivery')")

      expect(payload['contentType']).to eq('article')
      expect(payload['markdown']).to include('Platform context 1 connects publishers')
      expect(payload['markdown']).to include('Platform context 5 connects publishers')
      expect(payload['markdown']).to include('One platform coordinates every approved source')
      expect(payload['markdown']).to include('Additional demand can be enabled')
      expect(payload['markdown']).not_to include('Privacy policy and cookie settings')
    end
  end

  it 'keeps a page-owned publication collection when reader mode proposes footer prose' do
    publications = (1..10).map do |index|
      <<~HTML
        <li><a href="/publications/volume-#{index}"><h3>Volume #{index} of the regional series</h3></a>
        <p>Volume #{index} documents distinct regional economic indicators, public data sources, and
        environmental trends for readers comparing the complete annual series.</p></li>
      HTML
    end.join
    html = <<~HTML
      <html><head><title>Regional economic indicators series</title>
      <meta property="article:published_time" content="2017-11-23T12:00:00Z"></head><body>
        <div class="page-content"><div class="column-content">
          <h1>Regional economic indicators series</h1>
          <p>The publication series presents economic, financial, and environmental data from across the region.</p>
          <div class="item-list"><ul>#{publications}</ul></div>
        </div></div>
        <footer><p>The regional institution supports public partnerships and sustainable development across the world.</p>
          <p>Its main office coordinates international programs, financing and operational guidance for members.</p>
          <p>Contact the institution for subscription questions, support requests and administrative details.</p></footer>
      </body></html>
    HTML

    with_url_page('https://publisher.example/publications/series/regional-economic-indicators', html) do |page|
      payload = extract_with_readability_root(page, 'document.querySelector("footer")')

      expect(payload['markdown']).to include('The publication series presents economic')
      (1..10).each do |index|
        destination = "https://publisher.example/publications/volume-#{index}"
        expect(payload['markdown'].scan("](#{destination})").length).to eq(1)
        expect(payload['markdown']).to include("Volume #{index} documents distinct regional economic indicators")
      end
      positions = (1..10).map do |index|
        payload['markdown'].index("](https://publisher.example/publications/volume-#{index})")
      end
      expect(positions).not_to include(nil)
      expect(positions).to eq(positions.sort)
    end
  end

  it 'keeps a reader-owned article even when it shares a page with a publication collection' do
    html = <<~HTML
      <html><head><title>Regional indicators field report</title></head><body>
        <main><article><h1>Regional indicators field report</h1>
          <p>The report explains how field researchers verify climate data and economic indicators across regions.</p>
          <p>Independent findings document collection methods, source reliability and interpretation of each trend.</p>
          <p>A third substantive paragraph compares observations across years and describes why they matter.</p>
        </article><div class="item-list"><ul>
          #{(1..10).map { |index| %(<li><a href="/publications/volume-#{index}"><h3>Regional volume #{index}</h3></a><p>Independent related volume #{index} documents regional data and comparison methods.</p></li>) }.join}
        </ul></div></main>
      </body></html>
    HTML

    with_url_page('https://publisher.example/publications/reports/regional-indicators', html) do |page|
      payload = extract_with_readability_root(page, 'document.querySelector("article")')

      expect(payload['contentType']).to eq('article')
      expect(payload['markdown']).to include('Independent findings document collection methods')
    end
  end

  it 'does not replace owned article prose with its related publication collection' do
    paragraphs = (1..3).map do |index|
      <<~HTML
        <p>Report section #{index} describes the data collection methods, verification process, and regional
        analysis behind this complete research article. Its observations explain the chronology, interpretation,
        and public impact of the evidence independently of the related publications listed below.</p>
      HTML
    end.join
    related = (1..10).map do |index|
      <<~HTML
        <li><a href="/publications/related-#{index}"><h3>Related volume #{index} on regional data</h3></a>
        <p>Supplementary volume #{index} discusses different research programs, statistical resources, institutional
        reviews, source archives, comparative findings, and additional study references.</p></li>
      HTML
    end.join
    html = <<~HTML
      <html><head><title>Regional research report</title></head><body>
        <div class="page-content"><h1>Regional research report</h1>
          <section id="report-body">#{paragraphs}</section>
          <div class="item-list"><ul>#{related}</ul></div>
        </div>
      </body></html>
    HTML

    with_url_page('https://publisher.example/publications/series/regional-research', html) do |page|
      payload = extract_with_readability_root(page, 'document.querySelector("#report-body")')

      expect(payload['contentType']).to eq('article')
      expect(payload['markdown']).to include('Report section 1 describes the data collection methods')
      expect(payload['markdown']).to include('Report section 3 describes the data collection methods')
    end
  end

  it 'does not prefer a similarly sized fallback that does not contain the reader content' do
    broad_paragraphs = (1..8).map do |index|
      <<~HTML
        <p>Broad source section #{index} explains implementation planning, operational governance, measurement practice,
        service ownership, and the evidence teams review before launch. It preserves local context for each decision and
        records how the program changes after delivery without repeating the independent reader report.</p>
      HTML
    end.join
    unrelated_paragraphs = (1..3).map do |index|
      <<~HTML
        <p>Independent reader section #{index} documents archival research, source verification, editorial review,
        publication history, and the evidence needed to interpret an unrelated report without relying on platform copy.
        It records why reviewers accepted each conclusion and preserves distinctions needed for later research.</p>
      HTML
    end.join
    html = <<~HTML
      <html><head><title>Broad source report</title></head><body><main><article>
        <h1>Broad source report</h1>
        #{broad_paragraphs}
      </article></main></body></html>
    HTML
    unrelated_reader = "<article><h1>Independent reader report</h1>#{unrelated_paragraphs}</article>"
    root_expression = <<~JS.strip
      (() => {
        const root = document.createElement('div');
        root.innerHTML = #{unrelated_reader.dump};
        return root.firstElementChild;
      })()
    JS

    with_url_page('https://journal.example/report/overview', html) do |page|
      payload = extract_with_readability_root(page, root_expression)

      expect(payload['markdown']).to include('Independent reader section 1 documents archival research')
      expect(payload['markdown']).not_to include('Broad source section 1 explains implementation planning')
    end
  end

  it 'keeps a three-item portal whose page metadata identifies a marketplace' do
    html = <<~HTML
      <html><head><title>Learning Marketplace | Verified resources</title></head><body><main>
        <h1>Learning Marketplace</h1>
        <div class="content-group"><h2>For credential teams</h2>
          <div class="card"><a href="/resources/issue"><h3>Issue trusted credentials to every learner</h3></a></div>
        </div>
        <div class="content-group"><h2>For workforce partners</h2>
          <div class="card"><a href="/resources/connect"><h3>Connect verified skills with open opportunities</h3></a></div>
          <div class="card"><a href="/resources/measure"><h3>Measure verified outcomes across every region</h3></a></div>
        </div>
      </main></body></html>
    HTML

    extract_from_url('https://learning-market.example/', html) do |payload|
      expect(payload['contentType']).to eq('list')
      expect(payload['markdown']).to include('Issue trusted credentials', 'Connect verified skills', 'Measure verified outcomes')
    end
  end

  it 'keeps a three-item portal whose metadata description identifies a marketplace' do
    html = weak_portal_article_fixture.sub(
      '</title>',
      '</title><meta name="description" content="Find and compare trusted credential programs">'
    )

    extract_from_url('https://trustcloud.example/', html) do |payload|
      expect(payload['contentType']).to eq('list')
      record_urls = %w[
        https://trustcloud.example/credentials/issue
        https://trustcloud.example/credentials/connect
        https://trustcloud.example/credentials/measure
      ]
      record_positions = record_urls.map { |url| payload['markdown'].index(url) }
      expect(record_positions).to all(be_a(Integer))
      expect(record_positions).to eq(record_positions.sort)
      expect(payload['markdown']).not_to include('Trust program section 1 explains how credential teams')
    end
  end

  it 'does not treat one portal word in a metadata description as portal identity' do
    html = weak_portal_article_fixture.sub(
      '</title>',
      '</title><meta name="description" content="Find out how trusted credential programs support workforce teams">'
    )

    extract_from_url('https://trustcloud.example/', html) do |payload|
      expect(payload['markdown']).to include('Trust program section 1 explains how credential teams')
      expect(payload['markdown']).to include('Trust program section 6 explains how credential teams')
    end
  end

  it 'keeps a true category index as a list' do
    html = <<~HTML
      <main><h1>Latest reports</h1><section>
        #{(1..8).map { |index| %(<article><h2><a href="/articles/#{index}">Report #{index} headline</a></h2></article>) }.join}
      </section></main>
    HTML

    extract_from_url('https://www.bbc.com/articles', html) do |payload|
      expect(payload['contentType']).to eq('list')
    end
  end

  it 'does not treat an arbitrary non-news a route as an article' do
    html = <<~HTML
      <main><h1>Application dashboard</h1><section>
        #{(1..8).map { |index| %(<article><h2><a href="/items/#{index}">Application item #{index}</a></h2></article>) }.join}
      </section></main>
    HTML

    extract_from_url('https://app.example/a-77898335', html) do |payload|
      expect(payload['contentType']).to eq('list')
    end
  end

  it 'keeps a canonically owned sparse video article and its separate schedule collection' do
    canonical = 'https://publisher.example/highlight/champions-league-recap'
    html = <<~HTML
      <html><head><title>Champions League Match Recap</title>
        <link rel="canonical" href="#{canonical}">
        <script type="application/ld+json">{"@context":"https://schema.org","@type":"NewsArticle","headline":"Champions League Match Recap","mainEntityOfPage":{"@id":"#{canonical}"}}</script>
      </head><body><main>
        <div class="video-story"><h1>Champions League Match Recap</h1>
          <iframe src="https://video.example/embed/match-recap" width="720" height="405"></iframe>
        </div>
        <section class="fixture-list"><p>These fixture records form a source-owned schedule with its own editorial introduction.</p>
          <h2>Related fixtures</h2><ul>
          #{(1..4).map { |index| %(<li><h3><a href="/fixtures/#{index}">Fixture #{index} schedule and match details</a></h3><a href="/fixtures/#{index}" aria-label="Fixture #{index} image"><img src="/fixtures/#{index}.jpg" alt="Fixture #{index} image"></a></li>) }.join}
        </ul></section>
      </main></body></html>
    HTML

    extract_from_url(canonical, html) do |payload|
      expect(payload['contentType']).to eq('article'), payload.slice('contentType', 'title', 'markdown').inspect
      expect(payload['markdown']).to include('https://video.example/embed/match-recap')
      expect(payload['markdown']).to include('[https://video.example/embed/match-recap](https://video.example/embed/match-recap)')
      expect(payload['markdown']).not_to include('Watch video')
      (1..4).each do |index|
        expect(payload['markdown']).to include("Fixture #{index} schedule and match details", "/fixtures/#{index}")
      end
      expect(payload['markdown']).to include('source-owned schedule with its own editorial introduction')
    end
  end

  it 'does not attach an unrelated media embed to a canonical article headline' do
    canonical = 'https://publisher.example/highlight/champions-league-recap'
    html = <<~HTML
      <html><head><title>Champions League Match Recap</title>
        <link rel="canonical" href="#{canonical}">
        <script type="application/ld+json">{"@context":"https://schema.org","@type":"NewsArticle","headline":"Champions League Match Recap","mainEntityOfPage":{"@id":"#{canonical}"}}</script>
      </head><body><main>
        <div class="story-heading"><h1>Champions League Match Recap</h1></div>
        <div class="related-video"><iframe src="https://video.example/embed/related-match" width="720" height="405"></iframe></div>
        <section class="fixture-list"><h2>Upcoming fixtures</h2><ul>
          #{(1..4).map { |index| %(<li><a href="/fixtures/#{index}">Fixture #{index} schedule and match details</a></li>) }.join}
        </ul></section>
      </main></body></html>
    HTML

    extract_from_url(canonical, html) do |payload|
      expect(payload['markdown']).not_to include('https://video.example/embed/related-match')
    end
  end

  it 'does not use a mismatched headline and video as the owner of typed article metadata' do
    canonical = 'https://publisher.example/reports/community-budget'
    article_details = (1..3).map do |index|
      "Section #{index} reports verified community-budget findings, public spending context, and source documents for readers."
    end.join(' ')
    html = <<~HTML
      <html><head><title>Inter Miami San Diego FC Highlight 21/09/2026</title>
        <link rel="canonical" href="#{canonical}">
        <meta property="og:title" content="Inter Miami San Diego FC Highlight 21/09/2026">
        <script type="application/ld+json">{"@context":"https://schema.org","@type":"NewsArticle","url":"#{canonical}","headline":"Inter Miami San Diego FC Highlight 21/09/2026","datePublished":"2026-09-21T09:41:06+07:00"}</script>
      </head><body><main>
        <article><p>#{article_details}</p></article>
        <section class="unrelated-video"><h1>City council budget review 21/09/2026</h1>
          <iframe src="https://video.example/embed/unrelated-budget" width="720" height="405"></iframe>
        </section>
      </main></body></html>
    HTML

    extract_from_url(canonical, html) do |payload|
      expect(payload['markdown']).to include('verified community-budget findings')
      expect(payload['markdown']).not_to include('https://video.example/embed/unrelated-budget')
      expect(payload['title']).not_to eq('City council budget review 21/09/2026')
    end
  end

  it 'does not promote a video from a sidebar beside a source-owned article' do
    canonical = 'https://publisher.example/reports/urban-water'
    details = (1..3).map do |index|
      "Section #{index} reports the public water-supply findings, the independent evidence, and the council response."
    end.join(' ')
    html = <<~HTML
      <html><head><title>Urban water supply report</title>
        <link rel="canonical" href="#{canonical}">
        <script type="application/ld+json">{"@context":"https://schema.org","@type":"NewsArticle","url":"#{canonical}","headline":"Urban water supply report"}</script>
      </head><body><main><article><h1>Urban water supply report</h1><p>#{details}</p>
        <a href="/reports/water-source">Read the supporting water report</a>
      </article><aside><h2>Related video</h2>
        <iframe src="https://video.example/embed/water-sidebar" width="720" height="405"></iframe>
      </aside></main></body></html>
    HTML

    extract_from_url(canonical, html) do |payload|
      expect(payload['contentType']).to eq('article')
      expect(payload['markdown']).to include(details, '/reports/water-source')
      expect(payload['markdown']).not_to include('https://video.example/embed/water-sidebar')
    end
  end

  it 'keeps a focal video from hiding records outside a nested main' do
    canonical = 'https://publisher.example/highlight/city-final'
    html = <<~HTML
      <html><head><title>City United Final Report 2026</title>
        <link rel="canonical" href="#{canonical}">
        <script type="application/ld+json">{"@context":"https://schema.org","@type":"NewsArticle","url":"#{canonical}","headline":"City United Final Report 2026"}</script>
      </head><body><main id="outer-main">
        <div class="primary-frame"><main id="inner-main"><article class="focal">
          <h1>City United Final Report 2026</h1>
          <iframe src="https://video.example/embed/city-final" width="720" height="405"></iframe>
        </article></main></div>
        <section><h2>Related fixtures</h2><ul>
          #{(1..4).map { |index| %(<li><article><h3><a href="/records/#{index}">Public match record #{index} source and result details</a></h3></article></li>) }.join}
        </ul></section>
      </main></body></html>
    HTML

    extract_from_url(canonical, html) do |payload|
      expect(payload['markdown']).to include('https://video.example/embed/city-final')
      (1..4).each do |index|
        expect(payload['markdown']).to include("Public match record #{index} source and result details", "/records/#{index}")
      end
    end
  end

  it 'does not claim a sparse video owner when the main has an unowned list and prose' do
    canonical = 'https://publisher.example/highlight/city-final'
    unrelated = 'An independent municipal report follows the video and must remain visible alongside the linked records.'
    html = <<~HTML
      <html><head><title>City United Final Report 2026</title>
        <link rel="canonical" href="#{canonical}">
        <script type="application/ld+json">{"@context":"https://schema.org","@type":"NewsArticle","url":"#{canonical}","headline":"City United Final Report 2026"}</script>
      </head><body><main>
        <article class="focal"><h1>City United Final Report 2026</h1>
          <iframe src="https://video.example/embed/city-final" width="720" height="405"></iframe>
        </article>
        <p>#{unrelated}</p>
        <section><h2>Public match records</h2><ul>
          #{(1..4).map { |index| %(<li><h3><a href="/records/#{index}">Public match record #{index} source and result details</a></h3></li>) }.join}
        </ul></section>
      </main></body></html>
    HTML

    extract_from_url(canonical, html) do |payload|
      expect(payload['markdown']).to include(unrelated)
      (1..4).each do |index|
        expect(payload['markdown']).to include("Public match record #{index} source and result details", "/records/#{index}")
      end
    end
  end

  it 'preserves authored video sources, poster, track, caption, and fallback links' do
    canonical = 'https://publisher.example/reports/civic-economy-video'
    details = (1..3).map do |index|
      "Section #{index} explains the civic economy findings, review method, and evidence available to the public."
    end.join(' ')
    html = <<~HTML
      <html><head><title>Civic Economy Review 2026</title>
        <link rel="canonical" href="#{canonical}">
        <script type="application/ld+json">{"@context":"https://schema.org","@type":"NewsArticle","url":"#{canonical}","headline":"Civic Economy Review 2026"}</script>
      </head><body><main><article><h1>Civic Economy Review 2026</h1>
        <p>#{details}</p>
        <figure><video controls poster="/media/civic-poster.jpg" title="Civic economy documentary">
          <source src="/media/civic-main.mp4" type="video/mp4">
          <source src="/media/civic-alternate.webm" type="video/webm">
          <track kind="captions" src="/media/civic-en.vtt" srclang="en" label="English captions">
          <a href="/media/civic-download.mp4">Download the original civic recording</a>
          <p>Fallback note: the original civic recording remains available to all readers.</p>
        </video><figcaption>Civic economy documentary, recorded during the public review.</figcaption></figure>
      </article></main></body></html>
    HTML

    extract_from_url(canonical, html) do |payload|
      expect(payload['contentType']).to eq('article')
      expect(payload['markdown']).to include('Civic economy documentary, recorded during the public review')
      expect(payload['markdown']).to include('Download the original civic recording')
      expect(payload['markdown']).to include('English captions')
      expect(payload['html']).to include('poster="https://publisher.example/media/civic-poster.jpg"')
      expect(payload['html']).to include('src="https://publisher.example/media/civic-main.mp4"')
      expect(payload['html']).to include('src="https://publisher.example/media/civic-alternate.webm"')
      expect(payload['html']).to include('src="https://publisher.example/media/civic-en.vtt"')
      expect(payload['html']).to include('Fallback note: the original civic recording remains available to all readers.')
    end
  end
end
