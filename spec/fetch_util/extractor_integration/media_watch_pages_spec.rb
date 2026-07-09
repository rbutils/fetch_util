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
