# frozen_string_literal: true

require 'spec_helper'

RSpec.describe FetchUtil::Fetcher do
  include_context 'fetcher spec helpers'

  it 'relabels homepage news indexes as list content' do
    homepage_page = page_at('https://www.nytimes.com/')
    homepage_payload = payload_with(
      title: 'Daily Ledger - Current Reports and Video Briefings',
      markdown: "## New York Times - Top Stories\n\n1. Story one\n2. Story two\n3. Story three\n",
      contentType: 'article'
    )

    stub_browser_extraction('https://www.nytimes.com/', page: homepage_page, payload: homepage_payload)

    result = fetch_with_dependencies('https://www.nytimes.com/')

    expect(result.content_type).to eq('list')
    expect(result.warnings).to include('homepage_index_page')
  end

  it 'drops url_content_mismatch from homepage index pages' do
    homepage_page = page_at('https://www.hurriyet.com.tr/')
    homepage_payload = payload_with(
      title: 'Mavi Gündem - Güncel Haberler ve Günün Notları',
      canonicalUrl: 'https://www.hurriyet.com.tr/',
      markdown: <<~MARKDOWN.chomp,
        ## Hürriyet

        1. Son dakika
        2. Gündem
        3. Spor
      MARKDOWN
      contentType: 'list',
      warnings: ['url_content_mismatch']
    )

    stub_browser_extraction('https://www.hurriyet.com.tr/', page: homepage_page, payload: homepage_payload)

    result = fetch_with_dependencies('https://www.hurriyet.com.tr/')

    expect(result.content_type).to eq('list')
    expect(result.warnings).to eq(['homepage_index_page'])
  end

  [
    ['WP', 'https://wp.pl/', 'WP portal', 'Informacje', 'Sport'],
    ['Onet', 'https://onet.pl/', 'Onet portal', 'Wiadomości', 'Najlepsze w premium']
  ].each do |name, url, title, first_section, second_section|
    it "does not warn credible #{name} root list payloads as homepage indexes" do
      markdown = <<~MARKDOWN
        # #{title}

        ## #{first_section}

        - [Story one](#{url}story-one)
        - [Story two](#{url}story-two)
        - [Story three](#{url}story-three)

        ## #{second_section}

        - [Story four](#{url}story-four)
        - [Story five](#{url}story-five)
        - [Story six](#{url}story-six)
      MARKDOWN
      stub_browser_extraction(
        url,
        page: page_at(url),
        payload: payload_with(
          title: title,
          siteName: title,
          markdown: markdown,
          contentType: 'list',
          portalRootEvidence: { 'namedSectionCount' => 2, 'canonicalCardCount' => 6 },
          byline: nil,
          publishedTime: nil,
          warnings: []
        )
      )

      result = fetch_with_dependencies(url)

      expect(result.content_type).to eq('list')
      expect(result.suspect).to eq(false)
      expect(result.warnings).not_to include('homepage_index_page')
    end
  end

  it 'keeps non-root index mismatch warnings eligible' do
    url = 'https://portal.example/section/world'
    markdown = <<~MARKDOWN
      # World
      ## Latest
      - [Story one](https://portal.example/one)
      - [Story two](https://portal.example/two)
      - [Story three](https://portal.example/three)
      ## Analysis
      - [Story four](https://portal.example/four)
      - [Story five](https://portal.example/five)
      - [Story six](https://portal.example/six)
    MARKDOWN
    stub_browser_extraction(
      url,
      page: page_at(url),
      payload: payload_with(title: 'World', markdown: markdown, contentType: 'list', hostAware: true,
                            byline: nil, publishedTime: nil, warnings: ['url_content_mismatch'])
    )

    result = fetch_with_dependencies(url)

    expect(result.warnings).to include('url_content_mismatch')
  end

  it 'does not treat weak, blocked, or status roots as credible portal evidence' do
    [
      ['https://weak.example/', { warnings: ['homepage_index_page'] }, ['homepage_index_page']],
      ['https://blocked.example/', { warnings: %w[cloudflare_challenge_page] }, %w[cloudflare_challenge_page homepage_index_page]],
      ['https://status.example/', { statusPage: true, warnings: ['status_page'] }, ['status_page']]
    ].each do |url, overrides, expected_warnings|
      payload = payload_with(
        title: 'Portal root',
        markdown: "## News\n\n- [One](#{url}one)\n\n## More\n\n- [Two](#{url}two)\n",
        contentType: 'list',
        portalRootEvidence: { 'namedSectionCount' => 2, 'canonicalCardCount' => 6 },
        **overrides
      )
      stub_browser_extraction(url, page: page_at(url), payload: payload)

      result = fetch_with_dependencies(url)

      expect(result.warnings).to include(*expected_warnings)
    end
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

  it 'classifies government service portal homepages as lists without homepage-index warnings' do
    gov_url = 'https://www.gov.example/'
    gov_markdown = <<~MARKDOWN
      # Government Services

      ## Services for you

      ## Browse by category

      [Agriculture services](https://www.gov.example/categories/agriculture)
      Support, permits, and assistance for farms, food producers, and exporters.

      [Social assistance services](https://www.gov.example/categories/social-assistance)
      Benefits, applications, and support services for citizens and communities.

      [Business services](https://www.gov.example/categories/business)
      Register a company, request licenses, and manage public-service filings.

      [Education services](https://www.gov.example/categories/education)
      Student, school, and research services from government departments.

      [Transport permits](https://www.gov.example/categories/transport)
      Driver, vehicle, infrastructure, and public transport services.

      [Health services](https://www.gov.example/categories/health)
      Public health programs, benefits, and medical-service information.
    MARKDOWN

    stub_browser_extraction(
      gov_url,
      page: page_at(gov_url),
      payload: payload_with(
        title: 'Government Services',
        siteName: 'National public services portal',
        markdown: gov_markdown,
        contentType: 'article',
        byline: nil,
        publishedTime: nil
      )
    )

    result = fetch_with_dependencies(gov_url)

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

  it 'keeps opaque id detail pages with prose leads as articles' do
    detail_url = 'https://www.example-movies.test/title/tt0111161/'
    detail_markdown = <<~MARKDOWN
      After a banker is sentenced to life in Shawshank Prison, he forms an unlikely friendship with a seasoned inmate and clings to hope amid cruelty and corruption.

      - [User reviews](https://www.example-movies.test/title/tt0111161/reviews/)
      - [Cast and crew](https://www.example-movies.test/title/tt0111161/fullcredits/)
      - [Similar title](https://www.example-movies.test/title/tt0068646/)
      - [Another similar title](https://www.example-movies.test/title/tt0108052/)
    MARKDOWN

    stub_browser_extraction(
      detail_url,
      page: page_at(detail_url),
      payload: payload_with(title: 'The Shawshank Redemption', markdown: detail_markdown, contentType: 'article')
    )

    result = fetch_with_dependencies(detail_url)

    expect(result.content_type).to eq('article')
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

  it 'keeps news article slugs as articles instead of section indexes' do
    article_url = 'https://www.freecodecamp.org/news/switchback-experiments-for-ai-platform-features-in-python/'
    article_markdown = <<~MARKDOWN
      # Product Experimentation for LLM Platforms

      Your team ships an intelligent query-routing feature for an LLM SaaS platform. The feature reads each incoming request in real time and decides whether to send it to the fast standard model or the more capable premium model.

      Switchback experiments are the standard fix for shared-resource product experiments where user-level randomization would break the comparison.

      - [Why User-Level A/B Testing Fails](#heading-why-user-level-ab-testing-fails)
      - [How Switchback Design Restores a Clean Comparison](#heading-how-switchback-design-restores-a-clean-comparison)
      - [Step 1: Build the Switchback Time Series](#heading-step-1-build-the-switchback-time-series)
      - [Step 2: Naive Estimate](#heading-step-2-naive-estimate)
    MARKDOWN

    stub_browser_extraction(
      article_url,
      page: page_at(article_url),
      payload: payload_with(
        title: 'Product Experimentation for LLM Platforms',
        markdown: article_markdown,
        contentType: 'article'
      )
    )

    result = fetch_with_dependencies(article_url)

    expect(result.content_type).to eq('article')
    expect(result.warnings).not_to include('multi_topic_page')
  end

  it 'falls back to raw article prose when browser extraction returns a short related-link list' do
    article_url = 'https://blog.example.com/introducing-self-improving-software/'
    list_payload = payload_with(
      title: 'Introducing self-improving software',
      byline: 'Matt Arbesfeld',
      publishedTime: '2026-06-23T13:53:32+00:00',
      markdown: <<~MARKDOWN.chomp,
        - [Product Management](https://blog.example.com/product-management)
        - [Related story one](https://blog.example.com/product-management/one)
        - [Related story two](https://blog.example.com/product-management/two)
        - [Related story three](https://blog.example.com/product-management/three)
      MARKDOWN
      contentType: 'list'
    )
    article_payload = payload_with(
      title: 'Introducing self-improving software',
      byline: 'Matt Arbesfeld',
      markdown: 'Today, I am excited to announce self-improving capabilities in LogRocket Galileo.',
      contentType: 'article'
    )

    stub_browser_extraction(article_url, page: page_at(article_url), payload: list_payload)
    stub_raw_docs_fallback(article_url, payload: article_payload)

    result = fetch_with_dependencies(article_url)

    expect(result.content_type).to eq('article')
    expect(result.markdown).to include('self-improving capabilities')
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

  it 'keeps a BBC article route as a list when only related sections are materialized' do
    article_url = 'https://www.bbc.com/somali/articles/c20yd8jwln1o'
    related_markdown = <<~MARKDOWN
      ## Related coverage
      - [Related story one](https://www.bbc.com/somali/articles/one)
      - [Related story two](https://www.bbc.com/somali/articles/two)
      - [Related story three](https://www.bbc.com/somali/articles/three)
      - [Related story four](https://www.bbc.com/somali/articles/four)
    MARKDOWN

    stub_browser_extraction(
      article_url,
      page: page_at(article_url),
      payload: payload_with(title: 'BBC related coverage', publishedTime: '2026-07-08', markdown: related_markdown, contentType: 'list')
    )

    result = fetch_with_dependencies(article_url)

    expect(result.content_type).to eq('list')
  end

  it 'promotes a BBC article route only when focal prose is present' do
    article_url = 'https://www.bbc.com/yoruba/articles/c8r07734dp4o'
    article_markdown = <<~MARKDOWN
      # Focal BBC report

      The report describes a developing story with verified details from people familiar with the events, while officials review the evidence and explain the consequences for communities following the situation closely.

      Officials explained what happened and said that further information would be published after the review, with witnesses and public records providing additional context for the continuing report and its documented timeline.
    MARKDOWN

    stub_browser_extraction(
      article_url,
      page: page_at(article_url),
      payload: payload_with(title: 'Focal BBC report', publishedTime: '2026-07-08', markdown: article_markdown, contentType: 'list')
    )

    result = fetch_with_dependencies(article_url)

    expect(result.content_type).to eq('article')
  end

  it 'suppresses root index warnings only with browser structural portal evidence' do
    markdown = <<~MARKDOWN
      # International portal

      ## Top stories
      - [First story](https://portal.example/first)
      - [Second story](https://portal.example/second)
      - [Third story](https://portal.example/third)

      ## More news
      - [Fourth story](https://portal.example/fourth)
      - [Fifth story](https://portal.example/fifth)
      - [Sixth story](https://portal.example/sixth)
    MARKDOWN
    url = 'https://portal.example/'
    stub_browser_extraction(
      url,
      page: page_at(url),
      payload: payload_with(title: 'International portal', markdown: markdown, contentType: 'list',
                            portalRootEvidence: { 'namedSectionCount' => 2, 'canonicalCardCount' => 6 }, warnings: [])
    )

    result = fetch_with_dependencies(url)

    expect(result.warnings).to be_empty
  end

  it 'keeps ownerless heading and link counts eligible for root index warnings' do
    url = 'https://portal.example/'
    markdown = <<~MARKDOWN
      # International portal

      ## Top stories
      - [First story](https://portal.example/first)
      - [Second story](https://portal.example/second)
      - [Third story](https://portal.example/third)

      ## More news
      - [Fourth story](https://portal.example/fourth)
      - [Fifth story](https://portal.example/fifth)
      - [Sixth story](https://portal.example/sixth)
    MARKDOWN
    stub_browser_extraction(url, page: page_at(url),
                                 payload: payload_with(title: 'International portal', markdown: markdown,
                                                       contentType: 'list', warnings: []))

    expect(fetch_with_dependencies(url).warnings).to include('homepage_index_page')
  end

  it 'keeps sparse root warnings eligible' do
    url = 'https://sparse.example/'
    stub_browser_extraction(
      url,
      page: page_at(url),
      payload: payload_with(title: 'Sparse news', markdown: "## Latest\n- [Only story](https://sparse.example/story)\n", contentType: 'list')
    )

    result = fetch_with_dependencies(url)

    expect(result.warnings).to include('homepage_index_page')
  end
end
