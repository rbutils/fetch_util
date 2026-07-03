# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'FetchUtil extractor integration - Discourse topics' do
  include_context 'extractor integration helpers'

  it 'extracts Discourse topic post bodies with post metadata' do
    html = <<~HTML
      <html>
        <head>
          <title>Trust levels explained - Discourse Meta</title>
          <meta name="generator" content="Discourse 3.4.0">
          <meta property="og:site_name" content="Discourse Meta">
        </head>
        <body class="crawler discourse">
          <main id="main-outlet">
            <div id="topic-title"><h1>Trust levels explained</h1></div>
            <section id="post-stream">
              <article class="topic-post" data-post-id="101">
                <div class="topic-meta-data">
                  <span class="names"><a class="username">alice</a></span>
                  <time datetime="2026-06-01T12:00:00Z">Jun 1</time>
                </div>
                <div class="cooked">
                  <p>First post body explains how trust levels unlock community features.</p>
                  <blockquote><p>Quoted guidance should remain visible.</p></blockquote>
                  <ul><li>Read topics</li><li>Reply constructively</li></ul>
                </div>
              </article>
              <article class="topic-post" data-post-id="102">
                <div class="topic-meta-data">
                  <span class="names"><a class="username">bob</a></span>
                  <time datetime="2026-06-02T13:00:00Z">Jun 2</time>
                </div>
                <div class="cooked">
                  <p>Second post body adds moderation context for new members.</p>
                  <pre><code>trust_level = 2</code></pre>
                </div>
              </article>
            </section>
          </main>
        </body>
      </html>
    HTML

    with_url_page('https://meta.discourse.org/t/trust-levels-explained/123', html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload['contentType']).to eq('list')
      expect(payload['readerMode']).to eq(false)
      expect(payload['markdown']).to include('# Trust levels explained')
      expect(payload['markdown']).to include('## post by alice on 2026-06-01')
      expect(payload['markdown']).to include('First post body explains how trust levels unlock community features.')
      expect(payload['markdown']).to include('> Quoted guidance should remain visible.')
      expect(payload['markdown']).to include('Read topics')
      expect(payload['markdown']).to include('Reply constructively')
      expect(payload['markdown']).to include('## post by bob on 2026-06-02')
      expect(payload['markdown']).to include('Second post body adds moderation context for new members.')
      expect(payload['markdown']).to include('```')
      expect(payload['markdown']).to include('trust_level = 2')
    end
  end
end
