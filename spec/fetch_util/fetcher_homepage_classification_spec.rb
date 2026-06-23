# frozen_string_literal: true

require 'spec_helper'

RSpec.describe FetchUtil::Fetcher do
  include_context 'fetcher spec helpers'

  it 'relabels homepage news indexes as list content' do
    homepage_page = instance_double('FerrumPage', current_url: 'https://www.nytimes.com/')
    homepage_payload = payload.merge(
      'title' => 'The New York Times - Breaking News, US News, World News and Videos',
      'markdown' => "## New York Times - Top Stories\n\n1. Story one\n2. Story two\n3. Story three\n",
      'contentType' => 'article'
    )

    stub_browser_extraction('https://www.nytimes.com/', page: homepage_page, payload: homepage_payload)

    result = fetch_with_dependencies('https://www.nytimes.com/')

    expect(result.content_type).to eq('list')
    expect(result.warnings).to include('homepage_index_page')
  end

  it 'keeps search result pages as search content' do
    search_page = instance_double('FerrumPage', current_url: 'https://www.google.com/search?q=ruby+language')
    search_payload = payload.merge(
      'title' => 'ruby language - Google Search',
      'markdown' => "- [Ruby Programming Language](https://www.ruby-lang.org/) - Official site\n- [Ruby - Wikipedia](https://en.wikipedia.org/wiki/Ruby_(programming_language))\n",
      'contentType' => 'search',
      'warnings' => []
    )

    stub_browser_extraction('https://www.google.com/search?q=ruby+language', page: search_page, payload: search_payload)

    result = fetch_with_dependencies('https://www.google.com/search?q=ruby+language')

    expect(result.content_type).to eq('search')
    expect(result.warnings).not_to include('homepage_index_page')
    expect(result.warnings).not_to include('url_content_mismatch')
  end

  it 'does not flag query-driven list pages as url mismatches' do
    search_list_page = instance_double('FerrumPage', current_url: 'https://www.pinterest.com/search/pins/?q=ruby+programming')
    list_payload = payload.merge(
      'title' => 'Pinterest results for ruby programming',
      'markdown' => "- [ruby programming poster](https://www.pinterest.com/pin/1/)\n- [ruby reference sheet](https://www.pinterest.com/pin/2/)\n",
      'contentType' => 'list',
      'warnings' => []
    )

    stub_browser_extraction('https://www.pinterest.com/search/pins/?q=ruby+programming', page: search_list_page, payload: list_payload)

    result = fetch_with_dependencies('https://www.pinterest.com/search/pins/?q=ruby+programming')

    expect(result.content_type).to eq('list')
    expect(result.warnings).not_to include('url_content_mismatch')
  end

  it 'relabels German homepage indexes as list content' do
    de_page = instance_double('FerrumPage', current_url: 'https://www.bild.de/')
    de_payload = payload.merge(
      'title' => 'BILD.de: Aktuelle Nachrichten',
      'markdown' => "## Aktuelle Nachrichten\n\n1. Bundestag beschließt neues Gesetz\n2. Scholz trifft Macron\n3. Neue Studie zur Inflation\n",
      'contentType' => 'article'
    )

    stub_browser_extraction('https://www.bild.de/', page: de_page, payload: de_payload)

    result = fetch_with_dependencies('https://www.bild.de/')

    expect(result.content_type).to eq('list')
    expect(result.warnings).to include('homepage_index_page')
  end

  it 'relabels Hungarian homepage indexes as list content' do
    hu_page = instance_double('FerrumPage', current_url: 'https://www.444.hu/')
    hu_payload = payload.merge(
      'title' => '444 - Pair - legfrissebb hírek',
      'markdown' => "## Legfrissebb\n\n- Orbán felszólalt a parlamentben\n- Új intézkedések a járvány ellen\n- Sport: Fradi győzött\n",
      'contentType' => 'article'
    )

    stub_browser_extraction('https://www.444.hu/', page: hu_page, payload: hu_payload)

    result = fetch_with_dependencies('https://www.444.hu/')

    expect(result.content_type).to eq('list')
    expect(result.warnings).to include('homepage_index_page')
  end

  it 'relabels French homepage indexes as list content' do
    fr_page = instance_double('FerrumPage', current_url: 'https://www.lemonde.fr/')
    fr_payload = payload.merge(
      'title' => 'Le Monde.fr - Actualités et Infos en France et dans le monde - À la une',
      'markdown' => "## À la une\n\n- Macron annonce un plan de relance\n- Réforme des retraites\n- Européennes 2026\n",
      'contentType' => 'article'
    )

    stub_browser_extraction('https://www.lemonde.fr/', page: fr_page, payload: fr_payload)

    result = fetch_with_dependencies('https://www.lemonde.fr/')

    expect(result.content_type).to eq('list')
    expect(result.warnings).to include('homepage_index_page')
  end

  it 'does not relabel non-homepage article pages with matching phrases' do
    article_page = instance_double('FerrumPage', current_url: 'https://www.bild.de/politik/inland/article-12345')
    article_payload = payload.merge(
      'title' => 'Aktuelle Nachrichten zur Bundestagswahl',
      'markdown' => "# Aktuelle Nachrichten zur Bundestagswahl\n\nDie neuesten Ergebnisse der Wahl zeigen...",
      'contentType' => 'article'
    )

    stub_browser_extraction('https://www.bild.de/politik/inland/article-12345', page: article_page, payload: article_payload)

    result = fetch_with_dependencies('https://www.bild.de/politik/inland/article-12345')

    expect(result.content_type).to eq('article')
    expect(result.warnings).not_to include('homepage_index_page')
  end
end
