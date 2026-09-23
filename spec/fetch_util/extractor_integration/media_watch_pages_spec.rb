# frozen_string_literal: true

RSpec.describe 'FetchUtil media watch page extraction' do
  include_context 'extractor integration helpers'

  it 'extracts a single video profile from initial player data without list fallback' do
    html = <<~HTML
      <html>
        <head>
          <title>Night Signal - Lanterns at Dawn (Studio Video) - YouTube</title>
          <meta property="og:type" content="video.other">
          <meta property="og:site_name" content="YouTube">
          <meta property="og:title" content="Night Signal - Lanterns at Dawn (Studio Video)">
          <meta property="og:video:url" content="https://www.youtube.com/embed/dQw4w9WgXcQ">
          <script type="application/ld+json">
            {"@context":"https://schema.org","@type":"VideoObject","name":"Night Signal - Lanterns at Dawn (Studio Video)","description":"A studio video for Lanterns at Dawn by Night Signal.","uploadDate":"2009-10-25"}
          </script>
          <script>
            window.ytInitialPlayerResponse = {
              videoDetails: {
                 title: "Night Signal - Lanterns at Dawn (Studio Video)",
                 author: "Night Signal",
                viewCount: "1789090584",
                 shortDescription: "A studio video for Lanterns at Dawn by Night Signal. Follow the Night Signal channel for new sessions."
              },
             microformat: { playerMicroformatRenderer: { ownerChannelName: "Night Signal", publishDate: "2009-10-25" } }
            };
          </script>
        </head>
        <body>
          <main>
            <h1>Night Signal - Lanterns at Dawn (Studio Video)</h1>
            <a href="/hashtag/nevergonnagiveyouup">#LanternsAtDawn</a>
            <a href="/redirect?q=https://RickAstley.lnk.to/AmazonMusicID">Audio Store</a>
            <a href="/redirect?q=https://RickAstley.lnk.to/SpotifyID">Stream Service</a>
          </main>
        </body>
      </html>
    HTML

    with_url_page('https://www.youtube.com/watch?v=dQw4w9WgXcQ', html) do |page|
      payload = extract(page)

      expect(payload['contentType']).to eq('article')
      expect(payload['markdown']).to include('# Night Signal - Lanterns at Dawn (Studio Video)')
      expect(payload['markdown']).to include('- Author: Night Signal')
      expect(payload['markdown']).to include('- Views: 1789090584')
      expect(payload['markdown']).to include('A studio video for Lanterns at Dawn by Night Signal.')
      expect(payload['warnings']).not_to include('multi_topic_page')
    end
  end

  it 'prefers accessible video metadata over a processing-shell wrapper' do
    html = <<~HTML
      <html>
        <head>
          <title>The Quiet Vimeo Player (Sample Clip) | Videos & Movies on Vimeo</title>
          <meta property="og:type" content="video.other">
          <meta property="og:site_name" content="Vimeo">
          <meta property="og:title" content="The Quiet Vimeo Player (Sample Clip)">
          <meta property="og:description" content="This sample clip uses a calm layout while the player prepares the published stream.">
          <meta property="og:video:url" content="https://player.vimeo.com/video/76979871">
        </head>
        <body>
          <div>
            <span>Loading</span>
            <h1>This clip is processing...</h1>
            <p>You can view it after preparation finishes.</p>
          </div>
          <main data-testid="vd-wrapper" lang="en">
            <h1>The Quiet Vimeo Player (Sample Clip)</h1>
            <p><time datetime="2013-10-15T18:08:29+00:00">12 years ago</time></p>
            <p>This sample clip uses a calm layout while the player prepares the published stream.</p>
          </main>
        </body>
      </html>
    HTML

    with_url_page('https://vimeo.com/76979871', html) do |page|
      payload = extract(page)

      expect(payload['contentType']).to eq('article')
      expect(payload['markdown']).to include('# The Quiet Vimeo Player (Sample Clip)')
      expect(payload['markdown']).to include('- Published: 2013-10-15T18:08:29+00:00')
      expect(payload['markdown']).to include('player prepares the published stream')
      expect(payload['markdown']).not_to include('This clip is processing')
      expect(payload['warnings']).not_to include('multi_topic_page')
    end
  end

  it 'keeps a complete article around a video instead of a structured metadata teaser' do
    resources = (1..12).map do |index|
      %(<li><a href="/resources/#{index}">Source resource #{index}</a></li>)
    end.join
    html = <<~HTML
      <html>
        <head>
          <title>Visible film article | Screen Journal</title>
          <meta property="og:type" content="video.other">
          <meta property="og:video:url" content="https://screen.example/player/feature">
          <script type="application/ld+json">
            {"@context":"https://schema.org","@type":"VideoObject","name":"Posts navigation","description":"Short video teaser.","author":{"@type":"Person","name":"Archive Editor"},"uploadDate":"2026-09-22T10:15:00Z"}
          </script>
        </head>
        <body><main><article>
          <h1>Visible film article</h1>
          <h2>Film information</h2>
          <p>The film follows a team of explorers who repair a remote station and discover why the previous crew vanished during the winter storm.</p>
          <h2>Full synopsis</h2>
          <p>After the station loses contact, the team follows a trail across the valley and uncovers the final message left by the crew before the storm arrived.</p>
          <h2>Source resources</h2><ul>#{resources}</ul>
        </article></main></body>
      </html>
    HTML

    with_url_page('https://screen.example/films/visible-feature', html) do |page|
      payload = extract(page)

      expect(payload['contentType']).to eq('article')
      expect(payload).to include('byline' => 'Archive Editor', 'publishedTime' => '2026-09-22T10:15:00Z')
      expect(payload['markdown']).to include('# Visible film article', 'previous crew vanished', 'final message left by the crew')
      (1..12).each do |index|
        expect(payload['markdown']).to include("[Source resource #{index}](https://screen.example/resources/#{index})")
      end
      expect(payload['markdown']).not_to include('# Posts navigation')
    end
  end

  it 'keeps every visible transcript paragraph on a video route' do
    paragraphs = (1..12).map do |index|
      "<p>Transcript segment #{index} explains how the bridge improves evacuation routes and reduces travel time for island residents.</p>"
    end.join
    html = <<~HTML
      <html>
        <head>
          <title>Island bridge project | Public Development Bank</title>
          <meta property="og:type" content="video.other">
          <meta property="og:video:url" content="https://media.example/player/bridge">
          <meta property="og:description" content="A brief summary of the island bridge project.">
          <script type="application/ld+json">
            {"@context":"https://schema.org","@type":"VideoObject","name":"Island bridge project","uploadDate":"2026-09-22T18:00:00+08:00","description":"A brief summary of the island bridge project."}
          </script>
        </head>
        <body><main><h1>Island bridge project</h1><video src="https://media.example/bridge.mp4"></video>
          <h2>Transcript</h2>#{paragraphs}
        </main></body>
      </html>
    HTML

    with_url_page('https://media.example/news/videos/island-bridge', html) do |page|
      payload = extract(page)

      expect(payload['contentType']).to eq('article')
      expect(payload).to include('publishedTime' => '2026-09-22T18:00:00+08:00', 'contentFormat' => 'video')
      segments = (1..12).map { |index| "Transcript segment #{index} explains" }
      positions = segments.map { |segment| payload['markdown'].index(segment) }
      expect(positions).not_to include(nil)
      expect(positions).to eq(positions.sort)
      segments.each { |segment| expect(payload['markdown'].scan(segment).length).to eq(1) }
    end
  end

  it 'keeps all visible media headings and chapters in DOM order' do
    headings = (1..8).map { |index| "<h1>Heading #{index}</h1>" }.join
    chapters = (1..14).map { |index| "<ytd-macro-markers-list-item-renderer><h4>Chapter #{index}</h4></ytd-macro-markers-list-item-renderer>" }.join
    html = <<~HTML
      <html><head><title>Many Chapters - YouTube</title></head><body><main>#{headings}<p id="description">A sufficiently long video description for this fixture.</p>#{chapters}</main></body></html>
    HTML

    with_url_page('https://www.youtube.com/watch?v=example', html) do |page|
      markdown = extract(page)['markdown']
      expect(markdown).to include('Chapter 14')
      expect(markdown.index('Chapter 1')).to be < markdown.index('Chapter 14')
    end
  end
end
