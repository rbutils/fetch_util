# frozen_string_literal: true

RSpec.describe 'FetchUtil media watch page extraction' do
  include_context 'extractor integration helpers'

  it 'extracts a single video profile from initial player data without list fallback' do
    html = <<~HTML
      <html>
        <head>
          <title>Rick Astley - Never Gonna Give You Up (Official Video) (4K Remaster) - YouTube</title>
          <meta property="og:type" content="video.other">
          <meta property="og:site_name" content="YouTube">
          <meta property="og:title" content="Rick Astley - Never Gonna Give You Up (Official Video) (4K Remaster)">
          <meta property="og:video:url" content="https://www.youtube.com/embed/dQw4w9WgXcQ">
          <script type="application/ld+json">
            {"@context":"https://schema.org","@type":"VideoObject","name":"Rick Astley - Never Gonna Give You Up (Official Video) (4K Remaster)","description":"The official video for Never Gonna Give You Up by Rick Astley.","uploadDate":"2009-10-25"}
          </script>
          <script>
            window.ytInitialPlayerResponse = {
              videoDetails: {
                title: "Rick Astley - Never Gonna Give You Up (Official Video) (4K Remaster)",
                author: "Rick Astley",
                viewCount: "1789090584",
                shortDescription: "The official video for Never Gonna Give You Up by Rick Astley. Subscribe to the official Rick Astley YouTube channel."
              },
              microformat: { playerMicroformatRenderer: { ownerChannelName: "Rick Astley", publishDate: "2009-10-25" } }
            };
          </script>
        </head>
        <body>
          <main>
            <h1>Rick Astley - Never Gonna Give You Up (Official Video) (4K Remaster)</h1>
            <a href="/hashtag/nevergonnagiveyouup">#NeverGonnaGiveYouUp</a>
            <a href="/redirect?q=https://RickAstley.lnk.to/AmazonMusicID">Amazon Music</a>
            <a href="/redirect?q=https://RickAstley.lnk.to/SpotifyID">Spotify</a>
          </main>
        </body>
      </html>
    HTML

    with_url_page('https://www.youtube.com/watch?v=dQw4w9WgXcQ', html) do |page|
      payload = extract(page)

      expect(payload['contentType']).to eq('article')
      expect(payload['markdown']).to include('# Rick Astley - Never Gonna Give You Up (Official Video) (4K Remaster)')
      expect(payload['markdown']).to include('- Author: Rick Astley')
      expect(payload['markdown']).to include('- Views: 1789090584')
      expect(payload['markdown']).to include('The official video for Never Gonna Give You Up by Rick Astley.')
      expect(payload['warnings']).not_to include('multi_topic_page')
    end
  end

  it 'prefers accessible video metadata over a processing-shell wrapper' do
    html = <<~HTML
      <html>
        <head>
          <title>The New Vimeo Player (You Know, For Videos) | Videos & Movies on Vimeo</title>
          <meta property="og:type" content="video.other">
          <meta property="og:site_name" content="Vimeo">
          <meta property="og:title" content="The New Vimeo Player (You Know, For Videos)">
          <meta property="og:description" content="It may look mostly the same on the surface, but under the hood we totally rebuilt our player.">
          <meta property="og:video:url" content="https://player.vimeo.com/video/76979871">
        </head>
        <body>
          <div>
            <span>Loading</span>
            <h1>This video is processing...</h1>
            <p>You'll be able to view it as soon as it's done.</p>
          </div>
          <main data-testid="vd-wrapper" lang="en">
            <h1>The New Vimeo Player (You Know, For Videos)</h1>
            <p><time datetime="2013-10-15T18:08:29+00:00">12 years ago</time></p>
            <p>It may look mostly the same on the surface, but under the hood we totally rebuilt our player.</p>
          </main>
        </body>
      </html>
    HTML

    with_url_page('https://vimeo.com/76979871', html) do |page|
      payload = extract(page)

      expect(payload['contentType']).to eq('article')
      expect(payload['markdown']).to include('# The New Vimeo Player (You Know, For Videos)')
      expect(payload['markdown']).to include('- Published: 2013-10-15T18:08:29+00:00')
      expect(payload['markdown']).to include('under the hood we totally rebuilt our player')
      expect(payload['markdown']).not_to include('This video is processing')
      expect(payload['warnings']).not_to include('multi_topic_page')
    end
  end
end
