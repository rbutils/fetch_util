# frozen_string_literal: true

RSpec.describe 'FetchUtil extractor integration' do
  include_context 'extractor integration helpers'

  it 'extracts article pages from generic MediaWiki DOM signals' do
    fixture_path = File.expand_path('../../fixtures/mediawiki_article.html', __dir__)

    with_url_page('https://example.test/wiki/Ruby', File.read(fixture_path)) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect_content_type(payload, 'article')
      expect(payload['title']).to eq('Ruby')
      expect(payload['markdown']).to include('Ruby is a high-level, general-purpose programming language.')
      expect(payload['markdown']).not_to include('Jump to content')
      expect(payload['markdown']).not_to include('Reference tooltip text')
      expect(payload['warnings']).not_to include('empty_extraction')
      expect(payload['warnings']).not_to include('short_extraction')
      expect(payload['warnings']).not_to include('url_content_mismatch')
    end
  end

  it 'does not flag a link-heavy Wikipedia-style article as multi-topic' do
    sections = %w[History Geography Demographics Culture Economy].map do |heading|
      <<~HTML
        <h2>#{heading}</h2>
        <p>#{"This section keeps discussing one subject with <a href=\"/wiki/Example_A\">related context</a> and <a href=\"/wiki/Example_B\">background detail</a> in a single narrative. " * 4}</p>
      HTML
    end.join

    html = <<~HTML
      <html>
        <head>
          <title>Example City - Example Wiki</title>
          <meta name="generator" content="MediaWiki 1.41.0">
        </head>
        <body class="mediawiki mw-body">
          <h1 id="firstHeading" class="firstHeading">Example City</h1>
          <div id="mw-content-text">
            <div class="mw-parser-output">
              <p>#{"Example City is a long encyclopedic article about a single place with <a href=\"/wiki/Example_Country\">national</a> and <a href=\"/wiki/Example_Region\">regional</a> context. " * 4}</p>
              #{sections}
            </div>
          </div>
        </body>
      </html>
    HTML

    with_url_page('https://example.test/wiki/Example_City', html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect_content_type(payload, 'article')
      expect(payload['warnings']).not_to include('multi_topic_page')
    end
  end

  it 'prefers the parser output container over the larger MediaWiki wrapper' do
    fixture_path = File.expand_path('../../fixtures/mediawiki_wrapper_article.html', __dir__)

    with_url_page('https://example.test/wiki/Slovenija', File.read(fixture_path)) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect_content_type(payload, 'article')
      expect(payload['title']).to eq('Slovenija')
      expect(payload['markdown']).to include('Slovenija is a country in Central Europe')
      expect(payload['markdown']).to include('History')
      expect(payload['markdown']).to include('Geography')
      expect(payload['markdown']).not_to include('Redirected from')
      expect(payload['markdown']).not_to include('Retrieved from Example Wiki')
      expect(payload['warnings']).not_to include('empty_extraction')
      expect(payload['warnings']).not_to include('short_extraction')
    end
  end

  it 'classifies category and special pages as lists' do
    html = <<~HTML
      <html>
        <head>
          <title>Category:Programming languages - Example Wiki</title>
          <meta name="generator" content="MediaWiki 1.41.0">
        </head>
        <body class="mediawiki mw-body">
          <h1 id="firstHeading" class="firstHeading">Category:Programming languages</h1>
          <div id="mw-content-text">
            <div class="mw-parser-output">
              <div id="toc" class="toc">
                <div class="toctitle"><span>Contents</span></div>
                <ul>
                  <li><a href="#A">A</a></li>
                  <li><a href="#B">B</a></li>
                  <li><a href="#C">C</a></li>
                  <li><a href="#D">D</a></li>
                  <li><a href="#E">E</a></li>
                  <li><a href="#F">F</a></li>
                  <li><a href="#G">G</a></li>
                </ul>
              </div>
              <ul>
                <li><a href="/wiki/Category:Ruby">Ruby</a></li>
                <li><a href="/wiki/Category:Python">Python</a></li>
                <li><a href="/wiki/Category:JavaScript">JavaScript</a></li>
              </ul>
            </div>
          </div>
        </body>
      </html>
    HTML

    with_url_page('https://example.test/wiki/Category:Programming_languages', html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect_content_type(payload, 'list')
      expect(payload['markdown']).to include('Ruby')
      expect(payload['markdown']).not_to include('Contents')
      expect(payload['warnings']).not_to include('empty_extraction')
    end
  end
end
