# frozen_string_literal: true

RSpec.describe 'FetchUtil liveblog discussion ownership' do
  include_context 'extractor integration helpers'

  def discussion(label)
    <<~HTML
      <section class="comments"><article class="comment">
        <p>#{label} reader observation describes the public inspection route.</p>
        <footer><a rel="author" href="/readers/#{label.downcase}">#{label} Reader</a>
          <time datetime="2026-09-29T12:00:00Z">#{label} comment timestamp</time></footer>
      </article></section>
    HTML
  end

  def page_with_discussions(inline:, outside: '')
    <<~HTML
      <html><head><title>Harbor response live updates</title>
        <link rel="canonical" href="https://updates.example.test/live/harbor">
      </head><body><article class="article-content"><main class="liveblog-page">
        <h1>Harbor response live updates</h1><section class="live-updates">
          <article class="live-update" id="first"><h2>First harbor inspection</h2>
            <time datetime="2026-09-29T09:00:00Z">September 29, 2026 09:00</time>
            <p>Inspectors completed the first harbor survey and confirmed the route is open to the public.</p>
            <a rel="bookmark" href="https://updates.example.test/live/harbor?update=first">First update permalink</a>
            #{inline}
          </article>
          <article class="live-update" id="second"><h2>Second harbor inspection</h2>
            <time datetime="2026-09-29T10:00:00Z">September 29, 2026 10:00</time>
            <p>Engineers published the second inspection report with the complete maintenance schedule.</p>
          </article>
        </section></main>#{outside}</article>
        <aside>#{discussion("Unrelated")}</aside>
      </body></html>
    HTML
  end

  it 'preserves represented and outside discussions once despite an empty inline marker' do
    ['<section class="comments"><form><input></form></section>', discussion('Inline')].each do |inline|
      html = page_with_discussions(inline: inline, outside: discussion('Outside'))
      ['', '?update=first'].each do |query|
        with_url_page("https://updates.example.test/live/harbor#{query}", html) do |page|
          payload = extract_payload(page)
          markdown = payload.fetch('markdown')

          expect(payload['title']).to eq('Harbor response live updates')
          expect(payload['byline']).to be_nil
          expect(payload['publishedTime']).to be_nil
          expect(markdown.scan('Outside reader observation').length).to eq(1)
          expect(markdown).to include('Outside Reader', 'Outside comment timestamp', 'Second harbor inspection')
          expect(markdown.index('Second harbor inspection')).to be < markdown.index('Outside reader observation')
          expect(markdown).not_to include('Unrelated reader observation', 'Unrelated Reader')
          if inline.include?('Inline reader observation')
            expect(markdown.scan('Inline reader observation').length).to eq(1)
            expect(markdown).to include('Inline Reader', 'Inline comment timestamp')
          end
        end
      end
    end
  end

  it 'retains addressed-entry comment attribution without making it the update author' do
    html = page_with_discussions(inline: discussion('Inline'))
    with_url_page('https://updates.example.test/live/harbor?update=first', html) do |page|
      payload = extract_payload(page)

      expect(payload['title']).to eq('First harbor inspection')
      expect(payload['publishedTime']).to eq('2026-09-29T09:00:00Z')
      expect(payload['byline']).to be_nil
      expect(payload['markdown'].scan('Inline reader observation').length).to eq(1)
      expect(payload['markdown']).to include('Inline Reader', 'Inline comment timestamp')
      expect(payload['markdown']).not_to include('Second harbor inspection', 'Unrelated Reader')
    end
  end
end
