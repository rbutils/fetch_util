# frozen_string_literal: true

require 'spec_helper'
require 'support/extractor_integration_helpers'
require 'cgi'
require 'nokogiri'

RSpec.describe 'Table image resources' do
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

  def transition_document(hidden: false)
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
    paragraphs = transition_paragraphs.map { |text| "<p>#{text}</p>" }
    <<~HTML
      <html><head><title>Research service transition</title>
      <link rel="canonical" href="https://research.example.test/transition/"></head>
      <body><main><div>#{paragraphs.first(3).join}
      <table#{hidden ? " style=\"display:none\"" : ""}><tbody>
      <tr>#{headers}</tr><tr>#{images}</tr><tr>#{registrations}</tr>
      </tbody></table>#{paragraphs.drop(3).join}</div></main></body></html>
    HTML
  end

  def image_table_payload(cells)
    paragraphs = transition_paragraphs.first(3)
    html = <<~HTML
      <html><head><title>An image material catalogue</title></head>
      <body><main><article><h1>An image material catalogue</h1>
      #{paragraphs.map { |text| "<p>#{text}</p>" }.join}
      <table><thead><tr><th>First resource</th><th>Second resource</th></tr></thead>
      <tbody><tr>#{cells.map { |cell| "<td>#{cell}</td>" }.join}</tr></tbody></table>
      </article></main></body></html>
    HTML
    with_url_page('https://research.example.test/images/', html) do |page|
      before = page.evaluate('document.body.outerHTML')
      payload = extract(page)
      expect(page.evaluate('document.body.outerHTML')).to eq(before)
      expect(Nokogiri::HTML5.fragment(payload.fetch('html')).css('p').map(&:text)).to eq(paragraphs)
      payload
    end
  end

  it 'retains every authored paragraph and every complete destination occurrence beside the physical table' do
    with_url_page('https://research.example.test/transition/', transition_document) do |page|
      before = page.evaluate('document.body.outerHTML')
      payload = extract(page)
      native = Nokogiri::HTML5.fragment(payload.fetch('html'))
      expect(page.evaluate('document.body.outerHTML')).to eq(before)
      expect(native.css('p').map(&:text)).to eq(transition_paragraphs)
      expect(native.css('table')).not_to be_empty
      expect(native.css('th').map(&:text)).to eq(['Geographic Service', 'Healthy Places Service'])
      expect(native.css('td').map(&:text)).to eq(
        ['', '', 'Register at Geographic Service catalogue',
         'Register at Healthy Places Service catalogue']
      )
      transition_paragraphs.each { |text| expect(payload.fetch('markdown')).to include(text) }
      service_destinations.each do |destination|
        expect(native.css('table a').count { |link| link['href'] == destination }).to eq(3)
        expect(payload.fetch('markdown').scan(destination).length).to eq(3)
      end
      expect(payload.fetch('markdown')).to include(
        'Register at',
        'Geographic Service catalogue',
        'Healthy Places Service catalogue'
      )
    end
  end

  it 'excludes a positively hidden table while retaining all independently visible authored paragraphs' do
    with_url_page('https://research.example.test/transition/', transition_document(hidden: true)) do |page|
      before = page.evaluate('document.body.outerHTML')
      payload = extract(page)
      native = Nokogiri::HTML5.fragment(payload.fetch('html'))
      expect(page.evaluate('document.body.outerHTML')).to eq(before)
      transition_paragraphs.each { |text| expect(payload.fetch('markdown')).to include(text) }
      expect(native.css('table')).to be_empty
      service_destinations.each { |destination| expect(payload.fetch('markdown')).not_to include(destination) }
    end
  end

  it 'retains independent bare images with empty ALT and escaped complete sources' do
    sources = ['https://research.example.test/previews/one.png?size=full|wide#scan',
               'https://research.example.test/previews/two.png?edition=full&view=text#scan']
    payload = image_table_payload(sources.map { |src| "<img src=\"#{CGI.escapeHTML(src)}\" alt=\"\">" })
    sources.each { |src| expect(payload.fetch('markdown')).to include("![](#{src.gsub("|", "%7C")})") }
  end

  it 'preserves two independent identical image-only links' do
    href = 'https://research.example.test/resource/?edition=full&view=text#report'
    src = 'https://research.example.test/previews/identical.png?size=full#cover'
    cell = "<a href=\"#{CGI.escapeHTML(href)}\"><img src=\"#{CGI.escapeHTML(src)}\"></a>"
    payload = image_table_payload([cell, cell])
    expect(payload.fetch('markdown').scan(href).length).to eq(2)
    expect(payload.fetch('markdown').scan("![](#{src})").length).to eq(2)
  end

  it 'preserves existing nonempty image labels and all owning reference occurrences' do
    html = transition_document.gsub(/<img src="([^"]+)">/, '<img src="\1" alt="Catalogue preview">')
    with_url_page('https://research.example.test/transition/', html) do |page|
      payload = extract(page)
      expect(payload.fetch('markdown').scan('![Catalogue preview]').length).to eq(2)
      service_destinations.each { |href| expect(payload.fetch('markdown').scan(href).length).to eq(3) }
    end
  end

  it 'rejects unsafe table image sources' do
    payload = image_table_payload(['<img src="javascript:unsafe_image()" alt="Untrusted preview">',
                                   '<img src="data:image/png;base64,AA==" alt="Embedded preview">'])
    expect(payload.fetch('markdown')).not_to include('javascript:', 'data:image/', '![')
  end

  it 'does not invent a source for images without SRC' do
    payload = image_table_payload(['<img alt="Missing preview">', '<img src="" alt="Empty source preview">'])
    expect(payload.fetch('markdown')).to include('Empty source preview')
    expect(payload.fetch('markdown')).not_to include('![')
  end

  it 'excludes a positively hidden image while retaining its visible empty-ALT peer' do
    payload = image_table_payload(['<img src="/previews/hidden.png" style="display:none">',
                                   '<img src="/previews/visible.png" alt="">'])
    expect(payload.fetch('markdown')).not_to include('hidden.png')
    expect(payload.fetch('markdown')).to include('![](https://research.example.test/previews/visible.png)')
  end
end
