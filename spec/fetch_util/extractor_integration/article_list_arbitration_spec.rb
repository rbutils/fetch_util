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
    extract_payload(page)
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
end
