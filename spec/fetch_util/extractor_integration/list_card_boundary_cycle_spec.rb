# frozen_string_literal: true

require 'spec_helper'
require 'support/extractor_integration_helpers'
require 'nokogiri'
require 'cgi'

RSpec.describe 'Finite source-owned reporting card boundaries' do
  include_context 'extractor integration helpers'

  def reporting_card(number, wrapped_heading: true, class_name: 'post')
    title = "Independent reporting observation #{number}"
    description = "The complete source description for observation #{number} preserves its measurements, evidence and practical implications."
    content = if wrapped_heading
                "<a href='/reports/#{number}'><h2>#{title}</h2><p>#{description}</p><h4>By Reporter #{number}</h4></a>"
              else
                "<h2><a href='/reports/#{number}'>#{title}</a></h2><p>#{description}</p><h4>By Reporter #{number}</h4>"
              end
    "<article class='#{class_name}'>#{content}</article>"
  end

  def reporting_page(cards, extra: '')
    <<~HTML
      <html><head><title>Independent reporting observations</title>
      <meta name='description' content='Complete independent reports and their supporting observations.'></head>
      <body><main><h1>Independent reporting observations</h1>
      <p>These independently published reports retain their own descriptions and supporting evidence.</p>
      <section><h2>Latest observations</h2>#{cards}</section>#{extra}</main></body></html>
    HTML
  end

  def expect_complete_reporting(payload)
    html = Nokogiri::HTML5(payload.fetch('html'))
    expected = (1..3).map { |number| ["Independent reporting observation #{number}", "https://journal.publication.example.test/reports/#{number}"] }
    actual = html.css('a[href]').filter_map do |link|
      [link.text.gsub(/\s+/, ' ').strip, link['href']] if link['href'].include?('/reports/')
    end
    expect(actual.map(&:last)).to eq(expected.map(&:last))
    expected.each_with_index do |(title, destination), index|
      number = index + 1
      description = "The complete source description for observation #{number} preserves its measurements, evidence and practical implications."
      expect(html.text).to include(title, description, "By Reporter #{number}")
      expect(payload.fetch('markdown')).to include(title, destination, description, "By Reporter #{number}")
    end
    expect(payload.fetch('markdown').scan(%r{https://journal\.publication\.example\.test/reports/\d+})).to eq(expected.map(&:last))
  end

  it 'finishes complete extraction when each post directly owns one rich anchor' do
    cards = (1..3).map { |number| reporting_card(number) }.join
    with_url_page('https://journal.publication.example.test/', reporting_page(cards)) do |page|
      before = page.evaluate('document.body.innerHTML')
      expect_complete_reporting(extract(page))
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end

  it 'preserves the same reports when each title instead owns its anchor' do
    cards = (1..3).map { |number| reporting_card(number, wrapped_heading: false) }.join
    with_url_page('https://journal.publication.example.test/', reporting_page(cards)) do |page|
      before = page.evaluate('document.body.innerHTML')
      expect_complete_reporting(extract(page))
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end

  it 'keeps independent nested entries, hidden peers and literal markup separately owned' do
    entries = (1..3).map { |number| reporting_card(number, wrapped_heading: false, class_name: 'entry') }.join
    hidden = "<article class='post' hidden><h2><a href='/hidden-report'>Hidden report</a></h2><p>Hidden description.</p></article>"
    program = "<article class=\"post\">\n  <a href=\"/literal-only\">Literal reporting markup</a>\n</article>"
    literal = "<pre><code>#{CGI.escapeHTML(program)}</code></pre>"
    with_url_page('https://journal.publication.example.test/', reporting_page("<div class='post'>#{entries}</div>#{hidden}", extra: literal)) do |page|
      before = page.evaluate('document.body.innerHTML')
      payload = extract(page)
      expect_complete_reporting(payload)
      expect(Nokogiri::HTML5(payload.fetch('html')).css('pre').map(&:text)).to eq([program])
      expect(payload.fetch('markdown')).to include(program)
      expect(payload.fetch('markdown')).not_to include('Hidden report', 'Hidden description.')
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end
end
