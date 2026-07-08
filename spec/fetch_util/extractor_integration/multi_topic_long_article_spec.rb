# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'FetchUtil extractor integration - long single-topic articles' do
  include_context 'extractor integration helpers'

  it 'does not flag a heading-heavy long article with article-like DOM as multi-topic' do
    sections = 8.times.map do |i|
      <<~HTML
        <section>
          <h2>Section #{i + 1}</h2>
          <p>#{"This is sustained prose about one topic with contextual detail and examples. " * 2}</p>
          <p>#{"The section continues with more background, nuance, and follow-up explanation. " * 2}</p>
        </section>
      HTML
    end.join

    html = <<~HTML
      <html>
        <head>
          <title>Long Single-Topic Feature</title>
        </head>
        <body>
          <main>
            <article>
              <h1>Long Single-Topic Feature</h1>
              <p>#{"The introduction establishes a single subject and sets up a long, structured article. " * 3}</p>
              #{sections}
            </article>
          </main>
        </body>
      </html>
    HTML

    with_url_page('https://example.test/articles/long-single-topic-feature', html) do |page|
      payload = extract(page)

      expect_content_type(payload, 'article')
      expect(payload['warnings']).not_to include('multi_topic_page')
    end
  end

  it 'does not flag a long MediaWiki article as multi-topic' do
    sections = 8.times.map do |i|
      <<~HTML
        <h2>Section #{i + 1}</h2>
        <p>#{"This is sustained encyclopedic prose that expands one article topic in depth. " * 2}</p>
        <p>#{"The section continues with additional sourced detail, context, and narrative continuity. " * 2}</p>
      HTML
    end.join

    html = <<~HTML
      <html>
        <head>
          <title>Long Topic - Example Wiki</title>
          <meta name="generator" content="MediaWiki 1.41.0">
        </head>
        <body class="mediawiki mw-body">
          <h1 id="firstHeading" class="firstHeading">Long Topic</h1>
          <div id="mw-content-text">
            <div class="mw-parser-output">
              <p>#{"The lead paragraph introduces a single topic and then explores it in depth. " * 3}</p>
              #{sections}
            </div>
          </div>
        </body>
      </html>
    HTML

    with_url_page('https://example.test/wiki/Long_topic', html) do |page|
      payload = extract(page)

      expect_content_type(payload, 'article')
      expect(payload['warnings']).not_to include('multi_topic_page')
    end
  end
end
