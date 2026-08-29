# frozen_string_literal: true

RSpec.describe 'FetchUtil URL admission boundaries' do
  include_context 'extractor integration helpers'

  def page_payload(url:, html:)
    with_url_page(url, html) do |page|
      return extract_payload(page, reader_mode: false)
    end
  end

  def raw_profile_payload(markdown:, html: '<p>Visible body</p>', url: 'https://producer.example/result')
    page_html = '<html><head><title>Materialization probe</title></head><body><main>Visible body</main></body></html>'
    expression = <<~JS
      {
        contentType: "article",
        markdown: #{JSON.generate(markdown)},
        html: #{JSON.generate(html)},
        textContent: "Visible body",
        readerMode: false
      }
    JS

    with_url_page(url, page_html) do |page|
      extract_payload(page, reader_mode: false)
      return page.evaluate(<<~JS)
        (function () {
          window.registerHostAwareProfile(/producer\.example$/, function () {
            return #{expression};
          });
          return window.FetchUtilExtract.extract({ reader_mode: false });
        })()
      JS
    end
  end

  def action_cards(count, class_name: nil, date: false, job: false)
    count.times.map do |index|
      class_attribute = class_name ? %( class="#{class_name}") : ''
      time = date ? '<time datetime="2026-09-01T10:00:00Z">September 1, 2026 at 10:00 AM</time>' : ''
      job_attributes = job ? %( data-jobid="#{index}") : ''
      link_attributes = job ? ' data-test="job-title"' : ''
      <<~HTML
        <article#{class_attribute}#{job_attributes}>
          <h2><a#{link_attributes} class="homepage-link" href="javascript:action#{index}()">Action record #{index + 1}</a></h2>
          #{time}<p>Visible record detail #{index + 1} with enough descriptive text.</p>
        </article>
      HTML
    end.join
  end

  it 'does not let unsafe destinations establish specialized lists' do
    cases = [
      {
        name: 'generic portal',
        url: 'https://producer.example/',
        html: "<html><head><title>Latest headlines</title></head><body><main><h1>Latest headlines</h1>#{action_cards(6)}</main></body></html>"
      },
      {
        name: 'news homepage',
        url: 'https://www.ft.com/',
        html: "<html><head><title>News index</title></head><body><main>#{action_cards(4)}</main></body></html>"
      },
      {
        name: 'job results',
        url: 'https://producer.example/jobs',
        html: "<html><head><title>Remote jobs</title></head><body><main>#{action_cards(4, class_name: "job-card", job: true)}</main></body></html>"
      },
      {
        name: 'event cards',
        url: 'https://producer.example/directory',
        html: "<html><head><title>Community directory</title></head><body><main>#{action_cards(3, class_name: "event-card", date: true)}</main></body></html>"
      },
      {
        name: 'Antora landing cards',
        url: 'https://producer.example/docs',
        html: <<~HTML
          <html><head><title>Documentation</title><meta name="generator" content="Antora"></head>
          <body><main class="main"><article class="doc">#{action_cards(4)}</article></main></body></html>
        HTML
      },
      {
        name: 'component hub cards',
        url: 'https://producer.example/components',
        html: <<~HTML
          <html><head><title>Component hub</title></head><body><main><h1>Component hub</h1>
            <gui-tile-list>
              <gui-tile><gui-tile-heading heading-text="Action component 1"></gui-tile-heading><a href="javascript:action0()">Action component 1</a><gui-tile-content content-text="Visible component detail one"></gui-tile-content></gui-tile>
              <gui-tile><gui-tile-heading heading-text="Action component 2"></gui-tile-heading><a href="javascript:action1()">Action component 2</a><gui-tile-content content-text="Visible component detail two"></gui-tile-content></gui-tile>
              <gui-tile><gui-tile-heading heading-text="Action component 3"></gui-tile-heading><a href="javascript:action2()">Action component 3</a><gui-tile-content content-text="Visible component detail three"></gui-tile-content></gui-tile>
            </gui-tile-list>
          </main></body></html>
        HTML
      },
      {
        name: 'product cards',
        url: 'https://producer.example/shop',
        html: "<html><head><title>Products</title></head><body><main class=\"product-grid\">#{action_cards(4, class_name: "product-card")}</main></body></html>"
      }
    ]

    cases.each do |test_case|
      payload = page_payload(**test_case.except(:name))
      expect(payload['contentType']).not_to eq('list'), "#{test_case[:name]}: #{payload.inspect}"
      expect(payload['markdown']).not_to include('javascript:action'), test_case[:name]
    end
  end

  it 'retains unsafe records after safe records establish a specialized list' do
    safe_cards = 8.times.map do |index|
      <<~HTML
        <article>
          <h2><a href="/safe/#{index}">Safe established record #{index + 1}</a></h2>
          <p>Shared safe detail</p>
        </article>
      HTML
    end.join
    html = "<html><head><title>News index</title></head><body><main>#{safe_cards}#{action_cards(2)}</main></body></html>"

    payload = page_payload(url: 'https://www.ft.com/', html: html)

    expect(payload['contentType']).to eq('list')
    expect(payload['markdown']).to include('Safe established record 1', 'Action record 1', 'Action record 2')
    expect(payload['markdown']).not_to include('javascript:action')
  end

  it 'excludes hidden cards from specialized lists' do
    cases = [
      {
        url: 'https://producer.example/directory',
        html: <<~HTML,
          <html><head><title>Community directory</title></head><body><main>
            <article class="event-card"><h2><a href="/e/one">Visible event one</a></h2><time datetime="2026-09-01">Sep 1, 2026</time></article>
            <article class="event-card"><h2><a href="/e/two">Visible event two</a></h2><time datetime="2026-09-02">Sep 2, 2026</time></article>
            <article class="event-card"><h2><a href="/e/three">Visible event three</a></h2><time datetime="2026-09-03">Sep 3, 2026</time></article>
            <article class="event-card" style="display:none"><h2><a href="/e/hidden">Hidden event record</a></h2><time datetime="2026-09-04">Sep 4, 2026</time></article>
          </main></body></html>
        HTML
        visible: ['Visible event one', 'Visible event three'],
        hidden: 'Hidden event record'
      },
      {
        url: 'https://producer.example/jobs',
        html: <<~HTML,
          <html><head><title>Remote jobs</title></head><body><main>
            #{4.times.map { |index| %(<article class="job-card" data-jobid="#{index}"><h2><a data-test="job-title" href="/viewjob?jk=#{index}">Visible engineering role #{index + 1}</a></h2></article>) }.join}
            <article class="job-card" data-jobid="hidden" style="display:none"><h2><a data-test="job-title" href="/viewjob?jk=hidden">Hidden engineering role</a></h2></article>
          </main></body></html>
        HTML
        visible: ['Visible engineering role 1', 'Visible engineering role 4'],
        hidden: 'Hidden engineering role'
      },
      {
        url: 'https://producer.example/category/workbench',
        html: <<~HTML,
          <html><head><title>Workbench products</title></head><body><main class="product-grid">
            #{4.times.map { |index| %(<article class="product-card"><a href="/product/workbench-#{index}">Visible Workbench Tool #{index + 1}</a></article>) }.join}
            <article class="product-card" style="display:none"><a href="/product/workbench-hidden">Hidden Workbench Tool</a></article>
          </main></body></html>
        HTML
        visible: ['Visible Workbench Tool 1', 'Visible Workbench Tool 4'],
        hidden: 'Hidden Workbench Tool'
      }
    ]

    cases.each do |test_case|
      payload = page_payload(**test_case.slice(:url, :html))

      expect(payload['contentType']).to eq('list'), payload.inspect
      expect(payload['markdown']).to include(*test_case[:visible])
      expect(payload['markdown']).not_to include(test_case[:hidden])
    end
  end

  it 'closes quoted and listed fences with up to three content spaces' do
    markdown = <<~'MARKDOWN'
      >   ```
      > [Quoted literal](javascript:quotedLiteral())
      >   ```
      > [Quoted active](javascript:quotedActive())

      -   ```
          [Listed literal](javascript:listedLiteral())
          ```
      - [Listed active](javascript:listedActive())
    MARKDOWN

    output = raw_profile_payload(markdown: markdown)['markdown']

    expect(output).to include('[Quoted literal](javascript:quotedLiteral())', '[Listed literal](javascript:listedLiteral())')
    expect(output).to include('Quoted active', 'Listed active')
    expect(output).not_to include('javascript:quotedActive', 'javascript:listedActive')
  end

  it 'removes direct and nested SVG URL-bearing presentation attributes' do
    html = <<~'HTML'
      <section>
        <svg fill="url(javascript:paint())" filter="url(javascript:filter())" style="mask:url(javascript:mask())">
          <a href="/safe-vector" xlink:href="javascript:alias()"><text>Safe vector</text></a>
        </svg>
        <template>
          <svg clip-path="url(javascript:clip())"><image href="/safe-image.svg"></image></svg>
        </template>
      </section>
    HTML

    output = raw_profile_payload(markdown: 'Visible body', html: html)['html']

    expect(output).to include('href="https://producer.example/safe-vector"', 'href="https://producer.example/safe-image.svg"')
    expect(output).not_to include('javascript:', 'fill=', 'filter=', 'style=', 'xlink:href=', 'clip-path=')
  end

  it 'does not let unsafe generic evidence relabel articles as lists' do
    case_cards = 4.times.map do |index|
      <<~HTML
        <div class="case-card"><div class="card-header"><h3><a href="javascript:case#{index}()">Case record #{index + 1}</a></h3></div>
          <p>Court case charges, custody, trial, and docket detail for record #{index + 1}.</p></div>
      HTML
    end.join
    section_cards = 2.times.map do |section|
      cards = 2.times.map do |index|
        %(<article><h3><a href="javascript:section#{section}#{index}()">Section action #{section + 1}.#{index + 1}</a></h3><p>Visible section detail.</p></article>)
      end.join
      "<section><h2>Unsafe section #{section + 1}</h2>#{cards}</section>"
    end.join
    search_results = 3.times.map do |index|
      %(<div class="result"><h2><a href="javascript:/document/#{index}">Unsafe legal result #{index + 1}</a></h2></div>)
    end.join
    prose = 4.times.map { |index| "<p>#{"Substantive search explanation #{index + 1}. " * 12}</p>" }.join
    cases_html = <<~HTML
      <html><head><title>Cases</title></head><body><main><h1>Cases</h1>
        <form class="filter">Filter cases</form><h2>4 Cases</h2>#{case_cards}
      </main></body></html>
    HTML

    cases = [
      {
        name: 'institutional cases',
        url: 'https://producer.example/cases',
        html: cases_html
      },
      {
        name: 'sectioned index',
        url: 'https://producer.example/archive',
        html: "<html><head><title>Archive</title></head><body><main><h1>Archive</h1>#{section_cards}</main></body></html>"
      },
      {
        name: 'search-result DOM',
        url: 'https://producer.example/search?q=records',
        html: "<html><head><title>Search results</title></head><body><main><h1>Search results</h1><p>Results 1-3 of 3</p>#{search_results}#{prose}</main></body></html>"
      }
    ]

    cases.each do |test_case|
      payload = page_payload(**test_case.except(:name))
      expect(payload['contentType']).not_to eq('list'), "#{test_case[:name]}: #{payload.inspect}"
      expect(payload['markdown']).not_to include('javascript:'), test_case[:name]
    end

    markdown_payload = raw_profile_payload(
      url: 'https://producer.example/archive',
      markdown: 4.times.map { |index| "## [Unsafe Markdown record #{index + 1}](javascript:markdown#{index}())" }.join("\n\n")
    )
    expect(markdown_payload['contentType']).not_to eq('list')
    expect(markdown_payload['markdown']).not_to include('javascript:')
  end

  it 'uses a safe component destination after an unsafe leading control' do
    cards = 3.times.map do |index|
      <<~HTML
        <gui-tile>
          <a href="javascript:control#{index}()">Open control</a>
          <gui-tile-heading heading-text="Safe component #{index + 1}"></gui-tile-heading>
          <a href="/components/#{index + 1}">Safe component destination</a>
          <gui-tile-content content-text="Visible component detail #{index + 1}"></gui-tile-content>
        </gui-tile>
      HTML
    end.join
    html = "<html><head><title>Component hub</title></head><body><main><h1>Component hub</h1><gui-tile-list>#{cards}</gui-tile-list></main></body></html>"

    payload = page_payload(url: 'https://producer.example/components', html: html)

    expect(payload['contentType']).to eq('list')
    expect(payload['markdown']).to include('https://producer.example/components/1', 'https://producer.example/components/3')
    expect(payload['markdown']).not_to include('javascript:control')
  end

  it 'rejects same-host non-HTTP search targets' do
    html = <<~HTML
      <html><head><title>Google results</title></head><body>
        <div class="g"><a href="ftp://www.google.com/search/unsafe"><h3>Unsafe same-host result</h3></a><p>Result detail</p></div>
      </body></html>
    HTML

    payload = page_payload(url: 'https://www.google.com/search?q=unsafe', html: html)

    expect(payload['contentType']).to eq('search')
    expect(payload['markdown']).not_to include('Unsafe same-host result', 'ftp:')
  end
end
