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

  it 'does not warn on substantial docs product homepages with real intro content' do
    docs_page = page_at('https://nextra.site/')
    docs_payload = payload_with(
      title: 'Make beautiful websites with Next.js & MDX',
      siteName: 'Nextra',
      markdown: <<~MARKDOWN.chomp,
        # Make beautiful websites with Next.js & MDX

        Build fast, customizable, and content-rich websites with Nextra. Powered by Next.js, it offers seamless Markdown support, customizable themes, file conventions, and easy integration with MDX, making it perfect for documentation, blogs, and static websites.

        Nextra is designed for teams that want a polished documentation or product site without giving up control over the content model. Authors can keep pages in Markdown and MDX, compose reusable components, publish guides, and connect framework features while still presenting a coherent landing page for readers.

        The homepage explains the product and points visitors toward documentation, examples, theming, search, internationalization, and deployment workflows. It is more than a thin index shell because the landing copy describes what the framework does and why a team would choose it.

        Use it for API references, project handbooks, launch pages, changelogs, and long-form guides that benefit from file-based routing and modern React components.

        - Full-power documentation in minutes
        - Links and images are always optimized
        - Advanced syntax highlighting solution
        - I18n as easy as creating new files
        - [Get started ->](https://nextra.site/docs)
      MARKDOWN
      contentType: 'list',
      warnings: []
    )

    stub_browser_extraction('https://nextra.site/', page: docs_page, payload: docs_payload)

    result = fetch_with_dependencies('https://nextra.site/')

    expect(result.content_type).to eq('list')
    expect(result.suspect).to eq(false)
    expect(result.warnings).not_to include('homepage_index_page')
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

  it 'relabels section pages with linked headline markdown as list content' do
    section_markdown = <<~MARKDOWN
      # World News

      ## Highlights

      1. ### [First dispatch from overseas](https://www.example.com/2026/07/03/world/first.html)
      2. ### [Second dispatch from overseas](https://www.example.com/2026/07/03/world/second.html)
      3. ### [Third dispatch from overseas](https://www.example.com/2026/07/03/world/third.html)
      4. ### [Fourth dispatch from overseas](https://www.example.com/2026/07/03/world/fourth.html)
    MARKDOWN
    section_url = 'https://www.example.com/section/world'

    stub_browser_extraction(
      section_url,
      page: page_at(section_url),
      payload: payload_with(title: 'World News', markdown: section_markdown, contentType: 'article')
    )

    result = fetch_with_dependencies(section_url)

    expect(result.content_type).to eq('list')
    expect(result.warnings).not_to include('homepage_index_page')
  end

  it 'relabels thin commerce search pages as list content' do
    search_url = 'https://www.example.com/keyword.php?keyword=desk'
    search_payload = payload_with(
      title: 'Search results for desk',
      markdown: 'Shop desk ideas for home offices. Use filters to narrow the marketplace category.',
      byline: nil,
      publishedTime: nil,
      contentType: 'article'
    )

    stub_browser_extraction(search_url, page: page_at(search_url), payload: search_payload)

    result = fetch_with_dependencies(search_url)

    expect(result.content_type).to eq('list')
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

  it 'does not relabel article pages with related links as list content' do
    article_url = 'https://www.example.com/2026/07/03/world/investigation-details.html'
    article_markdown = <<~MARKDOWN
      # Investigation reveals planning gaps

      The investigation found a consistent pattern across public records and interviews with officials.

      Another long paragraph provides continuous standalone article prose with enough context and evidence to outweigh the related links that follow the story.

      - [Related background story one](https://www.example.com/world/related-1)
      - [Related background story two](https://www.example.com/world/related-2)
      - [Related background story three](https://www.example.com/world/related-3)
      - [Related background story four](https://www.example.com/world/related-4)
    MARKDOWN

    stub_browser_extraction(
      article_url,
      page: page_at(article_url),
      payload: payload_with(title: 'Investigation reveals planning gaps', markdown: article_markdown, contentType: 'article')
    )

    result = fetch_with_dependencies(article_url)

    expect(result.content_type).to eq('article')
  end
end
