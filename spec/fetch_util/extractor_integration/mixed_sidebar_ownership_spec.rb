# frozen_string_literal: true

RSpec.describe 'generic mixed-sidebar article ownership' do
  include_context 'extractor integration helpers'

  it 'preserves the article and supplemental material while removing the separate sidebar' do
    url = 'https://publisher.example/news/river-monitoring-123456'
    html = fixture_contents(File.expand_path('../../fixtures/focal_mixed_sidebar_article.html', __dir__))
    paragraphs = [
      'The monitoring team measured river levels at twelve stations after three days of heavy rainfall.',
      'Researchers compared the new readings with the long-term record and found that water receded more slowly near the eastern bridge.',
      'Crews will publish another update after the next scheduled survey.'
    ]

    with_url_page(url, html) do |page|
      source = page.evaluate('document.body.innerHTML')
      payload = extract_payload(page)
      markdown = payload.fetch('markdown')

      expect(payload).to include('contentType' => 'article', 'title' => 'River monitoring report')
      expect(payload.fetch('excerpt')).to start_with(paragraphs.first)
      paragraphs.each do |paragraph|
        expect(markdown.scan(paragraph).length).to eq(1)
      end
      positions = paragraphs.map { |paragraph| markdown.index(paragraph) }
      expect(positions).to eq(positions.sort)
      expect(markdown).to include('/assets/river-levels.png', '/data/river-levels.csv',
                                  'The complete station measurements are available',
                                  'Contributing author profile', 'Download the field guide')
      expect(markdown).not_to include('Partner courses', 'Unrelated course recommendations',
                                      'Browse partner courses')
      expect(page.evaluate('document.body.innerHTML')).to eq(source)
    end
  end

  it 'supports a distinct semantic body container and preserves its supplemental prose' do
    url = 'https://publisher.example/news/coastal-survey-654321'
    html = fixture_contents(File.expand_path('../../fixtures/focal_semantic_sidebar_article.html', __dir__))

    with_url_page(url, html) do |page|
      payload = extract_payload(page)
      markdown = payload.fetch('markdown')

      expect(payload).to include('contentType' => 'article', 'title' => 'Coastal survey report')
      expect(payload.fetch('excerpt')).to include('Survey crews mapped the coast')
      expect(markdown).to include('Survey crews mapped the coast', 'The team explains how tide timing',
                                  'Field editor profile', 'View the complete coastal survey record')
      expect(markdown).not_to include('Recently published', 'neighboring research item')
    end
  end

  it 'does not promote recommended-sidebar article content' do
    url = 'https://publisher.example/news/city-water-report-345678'
    html = <<~HTML
      <!doctype html><html><head>
      <title>City water report | Example Journal</title>
      <meta property="og:type" content="NewsArticle">
      <meta property="og:title" content="City water report">
      <link rel="canonical" href="#{url}">
      </head><body><main><header><h1>City water report</h1></header>
      <section itemprop="articleBody"><p>City inspectors tested water samples at eight public fountains during the scheduled spring survey.</p></section>
      <div class="recommended-sidebar"><article><h2>Recommended feature</h2>
      <section class="post-content"><p>Recommended feature text belongs to another article and must never replace the city water report.</p></section>
      </article></div></main></body></html>
    HTML

    with_url_page(url, html) do |page|
      payload = extract_payload(page)
      expect(payload.fetch('markdown')).to include('City inspectors tested water samples')
      expect(payload.fetch('markdown')).not_to include('Recommended feature text', 'Recommended feature')
    end
  end

  it 'does not treat a hidden body as a mixed-sidebar article body' do
    url = 'https://publisher.example/news/hidden-report-456789'
    html = <<~HTML
      <!doctype html><html><head>
      <title>Hidden report | Example Journal</title>
      <meta property="og:type" content="NewsArticle">
      <meta property="og:title" content="Hidden report">
      <link rel="canonical" href="#{url}">
      </head><body><article><header><h1>Hidden report</h1></header>
      <div class="article-sidebar-layout"><section class="post-content" hidden>
      <p>Hidden body text must not be promoted into a visible article result because its source region is concealed.</p>
      </section><div class="sidebar"><p>Visible unrelated sidebar material remains separate.</p></div></div>
      </article></body></html>
    HTML

    with_url_page(url, html) do |page|
      payload = extract_payload(page)
      expect(payload.fetch('markdown')).not_to include('Hidden body text must not be promoted')
    end
  end

  it 'does not promote a sidebar when the semantic body is empty' do
    url = 'https://publisher.example/news/empty-report-456790'
    html = <<~HTML
      <!doctype html><html><head>
      <title>Empty report | Example Journal</title>
      <meta property="og:type" content="NewsArticle">
      <meta property="og:title" content="Empty report">
      <link rel="canonical" href="#{url}">
      </head><body><article><header><h1>Empty report</h1></header>
      <div class="article-sidebar-layout"><section itemprop="articleBody"></section>
      <div class="sidebar"><p>Visible recommendations do not become an empty report's article body.</p></div></div>
      </article></body></html>
    HTML

    with_url_page(url, html) do |page|
      payload = extract_payload(page)
      expect(payload.fetch('markdown')).not_to include('Visible recommendations do not become an empty report')
    end
  end

  it 'keeps the body but excludes a sidebar nested within that same body branch' do
    url = 'https://publisher.example/news/estuary-report-567890'
    html = <<~HTML
      <!doctype html><html><head>
      <title>Estuary report | Example Journal</title>
      <meta property="og:type" content="NewsArticle">
      <meta property="og:title" content="Estuary report">
      <link rel="canonical" href="#{url}">
      </head><body><article><header><h1>Estuary report</h1></header>
      <section itemprop="articleBody"><p>Researchers measured salinity across the estuary and found that the spring runoff reached the lower stations two days later than in earlier surveys.</p>
      <div class="sidebar"><p>Nested sidebar story content must remain excluded from the estuary report.</p></div></section>
      </article></body></html>
    HTML

    with_url_page(url, html) do |page|
      payload = extract_payload(page)
      expect(payload.fetch('markdown')).to include('Researchers measured salinity across the estuary')
      expect(payload.fetch('markdown')).not_to include('Nested sidebar story content')
    end
  end
end
