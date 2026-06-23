# frozen_string_literal: true

require 'spec_helper'

RSpec.describe FetchUtil::Fetcher do
  include_context 'fetcher spec helpers'

  it 'relabels homepage news indexes as list content' do
    homepage_page = page_at('https://www.nytimes.com/')
    homepage_payload = payload_with(
      title: 'The New York Times - Breaking News, US News, World News and Videos',
      markdown: "## New York Times - Top Stories\n\n1. Story one\n2. Story two\n3. Story three\n",
      contentType: 'article'
    )

    stub_browser_extraction('https://www.nytimes.com/', page: homepage_page, payload: homepage_payload)

    result = fetch_with_dependencies('https://www.nytimes.com/')

    expect(result.content_type).to eq('list')
    expect(result.warnings).to include('homepage_index_page')
  end

  it 'keeps search result pages as search content' do
    search_page = page_at('https://www.google.com/search?q=ruby+language')
    search_payload = payload_with(
      title: 'ruby language - Google Search',
      markdown: "- [Ruby Programming Language](https://www.ruby-lang.org/) - Official site\n- [Ruby - Wikipedia](https://en.wikipedia.org/wiki/Ruby_(programming_language))\n",
      contentType: 'search',
      warnings: []
    )

    stub_browser_extraction('https://www.google.com/search?q=ruby+language', page: search_page, payload: search_payload)

    result = fetch_with_dependencies('https://www.google.com/search?q=ruby+language')

    expect(result.content_type).to eq('search')
    expect(result.warnings).not_to include('homepage_index_page')
    expect(result.warnings).not_to include('url_content_mismatch')
  end

  it 'does not flag query-driven list pages as url mismatches' do
    search_list_page = page_at('https://www.pinterest.com/search/pins/?q=ruby+programming')
    list_payload = payload_with(
      title: 'Pinterest results for ruby programming',
      markdown: "- [ruby programming poster](https://www.pinterest.com/pin/1/)\n- [ruby reference sheet](https://www.pinterest.com/pin/2/)\n",
      contentType: 'list',
      warnings: []
    )

    stub_browser_extraction('https://www.pinterest.com/search/pins/?q=ruby+programming', page: search_list_page, payload: list_payload)

    result = fetch_with_dependencies('https://www.pinterest.com/search/pins/?q=ruby+programming')

    expect(result.content_type).to eq('list')
    expect(result.warnings).not_to include('url_content_mismatch')
  end

  [
    [
      'German',
      'https://www.bild.de/',
      'BILD.de: Aktuelle Nachrichten',
      "## Aktuelle Nachrichten\n\n1. Bundestag beschließt neues Gesetz\n2. Scholz trifft Macron\n3. Neue Studie zur Inflation\n"
    ],
    [
      'Hungarian',
      'https://www.444.hu/',
      '444 - Pair - legfrissebb hírek',
      "## Legfrissebb\n\n- Orbán felszólalt a parlamentben\n- Új intézkedések a járvány ellen\n- Sport: Fradi győzött\n"
    ],
    [
      'French',
      'https://www.lemonde.fr/',
      'Le Monde.fr - Actualités et Infos en France et dans le monde - À la une',
      "## À la une\n\n- Macron annonce un plan de relance\n- Réforme des retraites\n- Européennes 2026\n"
    ]
  ].each do |language, url, title, markdown|
    it "relabels #{language} homepage indexes as list content" do
      stub_browser_extraction(
        url,
        page: page_at(url),
        payload: payload_with(title: title, markdown: markdown, contentType: 'article')
      )

      result = fetch_with_dependencies(url)

      expect(result.content_type).to eq('list')
      expect(result.warnings).to include('homepage_index_page')
    end
  end

  it 'does not relabel non-homepage article pages with matching phrases' do
    article_page = page_at('https://www.bild.de/politik/inland/article-12345')
    article_payload = payload_with(
      title: 'Aktuelle Nachrichten zur Bundestagswahl',
      markdown: "# Aktuelle Nachrichten zur Bundestagswahl\n\nDie neuesten Ergebnisse der Wahl zeigen...",
      contentType: 'article'
    )

    stub_browser_extraction('https://www.bild.de/politik/inland/article-12345', page: article_page, payload: article_payload)

    result = fetch_with_dependencies('https://www.bild.de/politik/inland/article-12345')

    expect(result.content_type).to eq('article')
    expect(result.warnings).not_to include('homepage_index_page')
  end
end
