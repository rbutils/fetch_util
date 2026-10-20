# frozen_string_literal: true

require 'spec_helper'
require 'support/extractor_integration_helpers'

RSpec.describe 'Localized author-route ownership' do
  include_context 'extractor integration helpers'

  def author_route_article(link)
    <<~HTML
      <!doctype html><html lang="en"><head><title>Independent publication reference</title></head><body>
      <main><article><h1>Independent publication reference</h1>
      #{link}
      <p>This publication contains a complete authored introduction with substantive explanation and an independent reference.</p>
      <p>The second paragraph preserves its complete argument and keeps ordinary resource links distinct from author attribution.</p>
      </article></main></body></html>
    HTML
  end

  def verify_author_route(page, expected_byline, label, destination)
    before = page.evaluate('document.body.innerHTML')
    payload = extract_payload(page, reader_mode: false)
    expect(payload['byline']).to eq(expected_byline)
    expect(payload['markdown']).to include("[#{label}](https://publication.example.test#{destination})")
    expect(payload['markdown']).to include('This publication contains a complete authored introduction')
    expect(payload['markdown']).to include('The second paragraph preserves its complete argument')
    expect(page.evaluate('document.body.innerHTML')).to eq(before)
  end

  it 'does not promote a direct single-segment resource link to author metadata' do
    with_url_page('https://publication.example.test/reference', author_route_article('<a href="/guide">Publication guide</a>')) do |page|
      verify_author_route(page, nil, 'Publication guide', '/guide')
    end
  end

  it 'requires an author route even inside credit-like markup' do
    link = '<div class="article-credit"><span><a href="/action">Complete resource</a></span></div>'
    with_url_page('https://publication.example.test/reference', author_route_article(link)) do |page|
      verify_author_route(page, nil, 'Complete resource', '/action')
    end
  end

  it 'retains genuine localized author routes and explicit author declarations' do
    ['/autoren/anna-meier', '/auteur/marie-dupont', '/es/autores/maria-garcia'].each do |destination|
      link = "<a href=\"#{destination}\">Independent Author</a>"
      with_url_page('https://publication.example.test/reference', author_route_article(link)) do |page|
        verify_author_route(page, 'Independent Author', 'Independent Author', destination)
      end
    end
    link = '<a rel="author" href="/profile">Declared Author</a>'
    with_url_page('https://publication.example.test/reference', author_route_article(link)) do |page|
      verify_author_route(page, 'Declared Author', 'Declared Author', '/profile')
    end
  end
end
