# frozen_string_literal: true

RSpec.describe 'FetchUtil generic focal news ownership' do
  include_context 'extractor integration helpers'

  it 'uses a title-owned article ahead of related records and keeps visible article material' do
    html = <<~HTML
      <html lang="en">
        <head>
          <title>Heat response plan | Example News</title>
          <meta property="og:site_name" content="Example News">
        <meta name="description" content="A public update on the heat response plan.">
        <meta property="og:type" content="NewsArticle">
        <link rel="canonical" href="https://publisher.example/story/heat-response-123456">
        <script type="application/ld+json">
          {"@type":"NewsArticle","headline":"Heat response plan","mainEntityOfPage":"https://publisher.example/story/heat-response-123456"}
        </script>
      </head>
      <body>
        <header><h1>Example News</h1><h1 hidden>Hidden sponsored headline</h1></header>
        <main>
            <aside class="related-stories">
              <a href="/story/other-100001">A separate article about transit</a>
              <p>Related records must not become this article's body.</p>
            </aside>
            <article>
              <h1>Heat response plan</h1>
              <ul itemprop="alternativeHeadline"><li>Officials publish the full public response</li></ul>
              <figure><img src="/heat-map.jpg" alt="Map of cooling centers"><figcaption>Cooling centers open across the region.</figcaption></figure>
              <p>The city opened additional cooling centers after temperatures remained high across the region overnight.</p>
              <p>Officials said transit service would be extended so residents could reach the centers without driving.</p>
              <p>Libraries and community facilities will remain open later while the heat advisory continues.</p>
              <p hidden>Private text that was not visible in the captured page.</p>
            </article>
            <section class="comments"><p>A visible reader reply with a useful source link.</p><a href="/comment/1">Original report</a></section>
          </main>
        </body>
      </html>
    HTML

    with_url_page('https://publisher.example/story/heat-response-123456', html) do |page|
      payload = extract_payload(page)
      expect_content_type(payload, 'article')
      expect(payload['title']).to include('Heat response plan')
      expect(payload['excerpt']).to start_with('The city opened additional cooling centers')
      expect(payload['markdown']).to include('Officials publish the full public response', '/heat-map.jpg',
                                             'Cooling centers open across the region.',
                                             'A visible reader reply with a useful source link.')
      expect(payload['markdown']).not_to include('Related records must not become', 'Private text that was not visible')
      expect(payload['markdown'].scan('The city opened additional cooling centers').length).to eq(1)
    end
  end

  it 'preserves every ordered section in a large source-owned article' do
    sections = (1..96).map do |index|
      <<~HTML
        <section>
          <h2>Editorial section #{index}</h2>
          <p>Source section #{index} contains complete reporting context, verified facts, and the public explanation readers need.</p>
        </section>
      HTML
    end.join
    html = <<~HTML
      <html><head><title>Editorial report</title></head><body><main><article>
        <h1>Editorial report</h1>
        <p>The report records the source-owned introduction and explains its complete public context for readers.</p>
        <p>Its opening account preserves the chronology and the underlying public record in full.</p>
        #{sections}
      </article></main></body></html>
    HTML

    with_url_page('https://publisher.example/reports/editorial', html) do |page|
      payload = extract_payload(page)
      markdown = payload.fetch('markdown')
      expected_headings = (1..96).map { |index| "Editorial section #{index}" }

      expect_content_type(payload, 'article')
      expected_headings.each do |heading|
        expect(markdown).to include(heading, "Source section #{heading.delete_prefix("Editorial section ")} contains complete reporting context")
      end
      positions = expected_headings.map { |heading| markdown.index(heading) }
      expect(positions).to eq(positions.sort)
    end
  end

  it 'keeps a multi-record section a list when no record owns the page headline' do
    cards = (1..4).map do |index|
      <<~HTML
        <article>
          <h2><a href="/story/record-#{index}00001">Independent report #{index}</a></h2>
          <p>Each record has a distinct headline and its own complete summary for readers.</p>
          <p>These summaries belong to separate records and do not share the collection heading.</p>
        </article>
      HTML
    end.join
    html = <<~HTML
      <html><head><title>Latest reports | Example News</title></head>
      <body><main><h1>Latest reports</h1><section>#{cards}</section></main></body></html>
    HTML

    with_url_page('https://publisher.example/section/latest', html) do |page|
      payload = extract_payload(page)

      expect_content_type(payload, 'list')
      expect(payload['markdown']).to include('Independent report 1', 'Independent report 4')
      expect(payload['hostAware']).to be(false)
    end
  end

  it 'uses canonical article metadata and a same-owner repeated lead without borrowing header headings' do
    html = <<~HTML
      <html><head><title>Appeal update | Example News</title>
        <link rel="canonical" href="https://publisher.example/a/appeal-123456">
        <meta property="og:type" content="article">
        <meta property="og:title" content="Appeal update | publisher.example">
        <script type="application/ld+json">
          {"@type":"Article","url":"https://publisher.example/a/appeal-123456","headline":"Appeal update"}
        </script>
      </head><body>
        <header><h1>Example News</h1></header>
        <main><h1 style="visibility:hidden">Appeal update</h1>
            <h1 hidden>Hidden unrelated heading</h1>
            <article class="article-content">
              <p>Appeal update</p>
              <p>The author describes how a service provider reviewed an account suspension and restored access. The published report explains the decision timeline and includes the specific changes made after the review.</p>
              <p>The same article continues with a detailed account of the subsequent support conversation, including the named review channel and a clear update about the restored service.</p>
          </article>
        </main>
      </body></html>
    HTML

    with_url_page('https://publisher.example/a/appeal-123456', html) do |page|
      inject_standalone_extractor(page, reader_mode: false)
      payload = extract_payload(page, reader_mode: false)
      expect_content_type(payload, 'article')
      expect(payload['title']).to eq('Appeal update')
      expect(payload['markdown']).to include('reviewed an account suspension', 'support conversation')
      expect(payload['markdown']).not_to include('Example News', 'Hidden unrelated heading')
      expect(payload['html']).not_to include('<h1')
    end
  end

  it 'rejects a collection of independently owned articleBody records despite its page heading' do
    records = (1..4).map do |index|
      <<~HTML
        <article>
          <h2><a href="/story/record-#{index}00001">Independent record #{index}</a></h2>
          <div itemprop="articleBody">
            <p>Record #{index} contains its own first substantive summary, not the collection page article.</p>
            <p>Record #{index} has a second paragraph that belongs only to its own article record.</p>
          </div>
        </article>
      HTML
    end.join
    html = <<~HTML
      <html><head><title>Latest reports | Example News</title>
        <meta property="og:type" content="website">
        <link rel="canonical" href="https://publisher.example/section/latest">
      </head><body><main><h1>Latest reports</h1>#{records}</main></body></html>
    HTML

    with_url_page('https://publisher.example/section/latest', html) do |page|
      payload = extract_payload(page)

      expect_content_type(payload, 'list')
      expect(payload['markdown']).to include('Independent record 1', 'Independent record 4')
      expect(payload['title']).to include('Latest reports')
    end
  end

  it 'uses canonical article metadata for an unheaded focal body, not a longer foreign title' do
    html = <<~HTML
      <html><head><title>Local transit update | Example News</title>
        <meta property="og:type" content="NewsArticle">
        <meta property="og:title" content="Local transit update">
        <link rel="canonical" href="https://publisher.example/story/transit-123456">
        <script type="application/ld+json">
          {"@type":"NewsArticle","headline":"Local transit update","mainEntityOfPage":"https://publisher.example/story/transit-123456"}
        </script>
      </head><body><main><article class="focal-summary">
        <figure><img src="/transit-map.jpg" alt="Transit service map"><figcaption>Updated city transit map.</figcaption></figure>
        <p>Local transit officials extended service across the central district after reviewing public requests. The full update describes the revised evening schedule, connects neighborhood stops, and explains how riders can use the new routes through the end of the month.</p>
      </article><article class="related-report">
        <h2>Local transit update explained</h2>
        <p>This longer foreign headline must not claim the exact focal ownership of the page title.</p>
        <p>The article record remains a foreign record and must not replace the page title.</p>
      </article></main></body></html>
    HTML

    with_url_page('https://publisher.example/story/transit-123456', html) do |page|
      payload = extract_payload(page)

      expect_content_type(payload, 'article')
      expect(payload['title']).to eq('Local transit update')
      expect(payload['markdown']).to include('Local transit officials extended service', '/transit-map.jpg')
      expect(payload['markdown']).not_to include('This longer foreign headline')
    end
  end

  it 'recomputes focal ownership after the same document changes' do
    html = <<~HTML
      <html><head><title>Heat response plan</title>
        <meta property="og:type" content="NewsArticle">
        <link rel="canonical" href="https://publisher.example/story/heat-response-123456">
        <script type="application/ld+json">
          {"@type":"NewsArticle","headline":"Heat response plan","mainEntityOfPage":"https://publisher.example/story/heat-response-123456"}
        </script>
      </head><body><main><article><h1>Heat response plan</h1>
        <p>The city opened additional cooling centers after temperatures remained high across the region overnight.</p>
        <p>Officials extended public transit service to reach the cooling centers.</p>
      </article></main></body></html>
    HTML

    with_url_page('https://publisher.example/story/heat-response-123456', html) do |page|
      first = extract_payload(page)
      expect(first['title']).to eq('Heat response plan')

      page.evaluate(<<~JS)
        (() => {
          document.title = 'Train service update';
          document.querySelector('meta[property="og:type"]').setAttribute('content', 'website');
          document.querySelector('script[type="application/ld+json"]').textContent = '{}';
          document.querySelector('main h1').textContent = 'Train service update';
          document.querySelector('article p').textContent = 'Rail service now runs every ten minutes across the central station.';
          return true;
        })()
      JS
      expect(page.evaluate("document.querySelector('article p').textContent")).to include('Rail service now runs every ten minutes')
      second = extract_payload(page)

      expect(second['title']).to include('Train service update')
      expect(second['markdown']).to include('Rail service now runs every ten minutes')
      expect(second['markdown']).not_to include('The city opened additional cooling centers after temperatures remained high across the region overnight.')
    end
  end

  it 'keeps a strongly signaled social post even when it has a headline and body' do
    html = <<~HTML
      <html><head><title>Garden update</title>
        <meta property="og:type" content="NewsArticle">
        <link rel="canonical" href="https://social.example/story/post-123456">
        <script type="application/ld+json">
          {"@type":"NewsArticle","headline":"Garden update","mainEntityOfPage":"https://social.example/story/post-123456"}
        </script>
      </head><body><main><article><h1>Garden update</h1>
        <p>We planted native flowers beside the east entrance this morning, after several neighborhood volunteers gathered for the work.</p>
        <p>The new garden will support native pollinators and provide a welcoming place for residents near the public library.</p>
        <img src="/garden.jpg" alt="Native flowers by the entrance">
        <button>Like</button><button>Reply</button><button>Share</button>
      </article></main></body></html>
    HTML

    with_url_page('https://social.example/story/post-123456', html) do |page|
      payload = extract_payload(page)

      expect_content_type(payload, 'social')
      expect(payload['markdown']).to include('We planted native flowers', '/garden.jpg')
    end
  end

  it 'keeps the focal live timeline in document order without admitting an unrelated ticker' do
    updates = (1..4).map do |index|
      <<~HTML
        <article><time>10:0#{index}</time><h2>Verified update #{index}</h2>
          <p>Emergency crews reported a verified change to the response perimeter in update #{index}.</p>
        </article>
      HTML
    end.join
    hidden_update = <<~HTML
      <article style="display:none"><time>09:59</time><h2>Private update not rendered</h2>
        <p>This hidden source text is outside the visible capture and must remain excluded.</p></article>
    HTML
    html = <<~HTML
      <html><head><title>Storm response live updates | Example News</title></head>
      <body><main><div class="ticker"><a href="/story/unrelated-123456">A different developing story</a></div>
        <article><h1>Storm response live updates</h1><div class="live-updates">#{updates}#{hidden_update}</div></article>
      </main></body></html>
    HTML

    with_url_page('https://publisher.example/story/storm-live-123456', html) do |page|
      payload = extract_payload(page)
      markdown = payload.fetch('markdown')

      expect_content_type(payload, 'article')
      positions = (1..4).map do |index|
        expect(markdown).to include("Verified update #{index}")
        markdown.index("Verified update #{index}")
      end
      expect(positions).to eq(positions.sort)
      expect(markdown).not_to include('A different developing story', 'Private update not rendered',
                                      'hidden source text')
    end
  end
end
