# frozen_string_literal: true

require 'spec_helper'
require 'support/extractor_integration_helpers'

RSpec.describe 'Unowned physical references in generic collections' do
  include_context 'extractor integration helpers'

  def portal_reference_fixture(independent: false, controls: false)
    groups = (1..4).map do |group|
      links = (1..4).map do |number|
        "<li><a href=\"/resources/#{group}/#{number}\">Complete resource #{group} number #{number}</a></li>"
      end.join
      "<section><h3>Resource group #{group}</h3><ul>#{links}</ul></section>"
    end.join
    news = (1..5).map do |number|
      "<li><a href=\"/news/#{number}\">Independent news announcement number #{number}</a></li>"
    end.join
    notes = (1..6).map do |number|
      empty = number == 1 ? '<a href="/notes?topic=examples"></a>' : ''
      "<li>#{empty}<a href=\"/notes/#{number}\">Complete authored example number #{number}</a></li>"
    end.join
    outside = if independent
                '<p>Our separately authored bibliography includes <a href="/notes?topic=examples"></a> as another independent reference.</p>'
              else
                ''
              end
    own_permalink = controls ? '<a href="#portal-title"></a>' : ''
    excluded = if controls
                 <<~HTML
                   <div hidden><a href="/hidden-destination"></a></div>
                   <div style="display:none"><a href="/css-hidden-destination"></a></div>
                   <div aria-hidden="true"><a href="/aria-destination"></a></div>
                   <div inert><a href="/inert-destination"></a></div>
                   <nav><a href="/navigation-destination"></a></nav>
                   <details><summary>Additional references</summary><a href="/closed-destination"></a></details>
                   <a href="#portal-title"></a>
                 HTML
               else
                 ''
               end
    <<~HTML
      <html><head><title>Independent developer portal</title></head><body><article>
      <h1 id="portal-title">Independent developer portal#{own_permalink}</h1>
      <p>This portal retains its complete documentation, news, authored examples, and independent resource destinations.</p>
      <div class="blocks">#{groups}</div>
      <div class="blocks"><section class="tall"><h3>News</h3><ul>#{news}</ul></section>
      <section class="tall"><h3><a href="/notes?topic=examples">Examples</a></h3>
      <a href="/notes?topic=examples"></a><ul><a href="/notes?topic=examples"></a>
      #{notes}<li><a href="/notes?topic=examples">Example archive</a></li></ul></section></div>
      #{outside}#{excluded}</article></body></html>
    HTML
  end

  def expect_complete_portal_records(markdown)
    expect(markdown).to include('complete documentation, news, authored examples, and independent resource destinations.')
    (1..6).each { |number| expect(markdown).to include("Complete authored example number #{number}") }
    (1..5).each { |number| expect(markdown).to include("Independent news announcement number #{number}") }
    (1..4).each do |group|
      (1..4).each { |number| expect(markdown).to include("Complete resource #{group} number #{number}") }
    end
    expect(markdown).to include('Example archive')
  end

  [false, true].each do |independent|
    it "preserves each separate destination#{independent ? " alongside independent authored prose" : ""}" do
      with_url_page('https://resources.example.test/', portal_reference_fixture(independent: independent)) do |page|
        before = page.evaluate('document.body.innerHTML')
        physical = page.evaluate('Array.from(document.querySelectorAll("a[href]")).filter(node => node.href === "https://resources.example.test/notes?topic=examples").length')
        expect(physical).to eq(independent ? 6 : 5)
        markdown = extract(page).fetch('markdown')
        expect(page.evaluate('document.body.innerHTML')).to eq(before)
        expect_complete_portal_records(markdown)
        expect(markdown).to include('Our separately authored bibliography includes', 'as another independent reference.') if independent
        expect(markdown.scan('](https://resources.example.test/notes?topic=examples)').size).to eq(physical)
      end
    end
  end

  it 'keeps hidden bodies and own-heading controls out while retaining a separate fragment reference' do
    with_url_page('https://resources.example.test/', portal_reference_fixture(controls: true)) do |page|
      before = page.evaluate('document.body.innerHTML')
      markdown = extract(page).fetch('markdown')
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
      expect_complete_portal_records(markdown)
      expect(markdown).not_to include(
        '/hidden-destination', '/css-hidden-destination', '/aria-destination', '/inert-destination',
        '/navigation-destination', '/closed-destination'
      )
      expect(markdown.scan('](https://resources.example.test/#portal-title)').size).to eq(1)
    end
  end
end
