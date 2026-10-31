# frozen_string_literal: true

require 'spec_helper'
require 'support/extractor_integration_helpers'
require 'cgi'
require 'nokogiri'

RSpec.describe 'Authored resource-table context' do
  include_context 'extractor integration helpers'

  def service_destinations
    ['https://research.example.test/geographic/?edition=full&view=text#catalogue',
     'https://research.example.test/healthy-places/?edition=full&view=text#catalogue']
  end

  def transition_paragraphs
    [
      'The research centre was a collaboration between two distinct research grants and their university teams.',
      'Its original funding was time-limited, and the service has now moved to two independently operated catalogues.',
      'The majority of the data and research activities have transferred to the Geographic Service and Healthy Places Service.',
      'Users are encouraged to visit and register for the new catalogues to continue accessing the research data they need.',
      'Existing user accounts have been securely deleted and are not transferred; active projects remain supported until completion.'
    ]
  end

  def resource_table
    labels = ['Geographic Service', 'Healthy Places Service']
    headers = labels.zip(service_destinations).map do |label, destination|
      "<th><a href=\"#{CGI.escapeHTML(destination)}\">#{label}</a></th>"
    end.join
    images = service_destinations.each_with_index.map do |destination, index|
      "<td><a href=\"#{CGI.escapeHTML(destination)}\"><img src=\"/previews/catalogue-#{index + 1}.png\"></a></td>"
    end.join
    registrations = labels.zip(service_destinations).map do |label, destination|
      "<td>Register at <a href=\"#{CGI.escapeHTML(destination)}\">#{label} catalogue</a></td>"
    end.join
    "<table><tbody><tr>#{headers}</tr><tr>#{images}</tr><tr>#{registrations}</tr></tbody></table>"
  end

  def context_document(table: resource_table, masthead: false, logos: false, wrapped: false, peer: '')
    header = masthead ? '<header><h3>Research data: service and catalogue transition notice</h3></header>' : ''
    brands = logos ? <<~HTML : ''
      <div class="logos">
      <a href="https://geographic.example.test/"><img src="/geographic-logo.png" alt="Geographic service logo"></a>
      <a href="https://healthy.example.test/"><img src="/healthy-logo.png" alt="Healthy places service logo"></a>
      </div>
    HTML
    paragraphs = transition_paragraphs.map { |text| "<p>#{text}</p>" }
    region = "#{paragraphs.first(3).join}#{table}#{paragraphs.drop(3).join}"
    region = "<div>#{region}</div>" if wrapped
    <<~HTML
      <html><head><title>Research service transition</title>
      <link rel="canonical" href="https://research.example.test/"></head>
      <body>#{header}<main>#{region}#{brands}</main>#{peer}</body></html>
    HTML
  end

  def with_context(html)
    with_url_page('https://research.example.test/', html) do |page|
      before = page.evaluate('document.body.outerHTML')
      payload = extract(page)
      expect(page.evaluate('document.body.outerHTML')).to eq(before)
      yield payload, Nokogiri::HTML5.fragment(payload.fetch('html'))
    end
  end

  def expect_complete_context(payload, native, tables: 1)
    expect(native.css('p').map(&:text)).to eq(transition_paragraphs)
    expect(native.css('table').length).to eq(tables)
    expect(native.css('th').map(&:text)).to eq(['Geographic Service', 'Healthy Places Service'] * tables)
    transition_paragraphs.each { |paragraph| expect(payload.fetch('markdown')).to include(paragraph) }
    service_destinations.each do |href|
      expect(native.css('table a').count { |link| link['href'] == href }).to eq(3 * tables)
      expect(payload.fetch('markdown').scan(href).length).to eq(3 * tables)
    end
    expect(payload.fetch('markdown').scan('Register at').length).to eq(2 * tables)
    expect(payload.fetch('markdown')).to include(
      '![](https://research.example.test/previews/catalogue-1.png)',
      '![](https://research.example.test/previews/catalogue-2.png)'
    )
  end

  [
    ['direct', false, false, false],
    ['direct-masthead', true, false, false],
    ['direct-masthead-logos', true, true, false],
    ['wrapped-masthead-logos', true, true, true]
  ].each do |name, masthead, logos, wrapped|
    it "retains all authored paragraphs and full independent references for #{name}" do
      with_context(context_document(masthead: masthead, logos: logos, wrapped: wrapped)) do |payload, native|
        expect_complete_context(payload, native)
        next unless logos

        expect(payload.fetch('markdown')).to include(
          '[![Geographic service logo](https://research.example.test/geographic-logo.png)](https://geographic.example.test/)',
          '[![Healthy places service logo](https://research.example.test/healthy-logo.png)](https://healthy.example.test/)'
        )
      end
    end
  end

  it 'retains two independent identical complete physical resource tables' do
    with_context(context_document(table: resource_table * 2)) do |payload, native|
      expect_complete_context(payload, native, tables: 2)
    end
  end

  it 'excludes a positively hidden table without changing the complete source BODY' do
    table = resource_table.sub('<table>', '<table style="display:none">')
    with_context(context_document(table: table)) do |payload, _native|
      service_destinations.each { |href| expect(payload.fetch('markdown')).not_to include(href) }
      expect(payload.fetch('markdown')).not_to include('/previews/catalogue-')
    end
  end

  it 'excludes resource-shaped navigation instead of treating it as authored context' do
    with_context(context_document(table: "<nav>#{resource_table}</nav>")) do |payload, _native|
      service_destinations.each { |href| expect(payload.fetch('markdown')).not_to include(href) }
    end
  end

  it 'preserves complete native material under an independent MAIN role declaration' do
    html = context_document.sub('<main>', '<main role="navigation">')
    with_context(html) do |_payload, native|
      # The legacy fallback already publishes this role-only source. Paired
      # material verification requires its entire payload to remain unchanged.
      expect(native.css('p').map(&:text)).to eq(transition_paragraphs)
      expect(native.css('th').map(&:text)).to eq(['Geographic Service', 'Healthy Places Service'])
      service_destinations.each do |href|
        expect(native.css('table a').count { |link| link['href'] == href }).to eq(3)
      end
    end
  end

  it 'excludes a genuine login form and its resource-shaped credential table' do
    table = <<~HTML
      <form action="/login"><label>Password <input type="password" name="password"></label>
      <p>Credential interface marker</p>#{resource_table}<button>Log in</button></form>
    HTML
    with_context(context_document(table: table)) do |payload, _native|
      expect(payload.fetch('markdown')).not_to include('Credential interface marker', 'Password')
      service_destinations.each { |href| expect(payload.fetch('markdown')).not_to include(href) }
    end
  end

  it 'does not invent unsafe destinations from a broken resource-column declaration' do
    table = resource_table.sub(CGI.escapeHTML(service_destinations.first), 'javascript:alert(1)')
    with_context(context_document(table: table)) do |payload, native|
      expect(payload.fetch('markdown')).not_to include('javascript:')
      expect(native.css('a[href]').map { |link| link['href'] }).not_to include('javascript:alert(1)')
    end
  end

  it 'retains independent visible prose outside the unique MAIN rather than dropping it' do
    text = 'An independent physical region contains a separately authored account of the ongoing research project.'
    with_context(context_document(peer: "<section><p>#{text}</p></section>")) do |payload, _native|
      expect(payload.fetch('markdown')).to include(text)
    end
  end
end
