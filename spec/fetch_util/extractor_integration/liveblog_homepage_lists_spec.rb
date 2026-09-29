# frozen_string_literal: true

RSpec.describe 'FetchUtil liveblog homepage list compatibility' do
  include_context 'extractor integration helpers'

  def linked_cards(count: 8)
    (1..count).map do |index|
      <<~CARD
        <article>
          <h3><a href="/updates/#{index}">Live update #{index}</a></h3>
          <time datetime="2026-04-10T#{format("%02d", 8 + index)}:00:00">#{8 + index}:00 CET</time>
          <p>Verified development #{index} in a continuing public event.</p>
        </article>
      CARD
    end.join
  end

  def schema_liveblog(headline)
    <<~HTML
      <script type="application/ld+json">
        {"@context":"https://schema.org","@type":"LiveBlogPosting","headline":"#{headline}"}
      </script>
    HTML
  end

  def materialized_updates
    (1..3).map do |index|
      <<~UPDATE
        <article class="live-update" data-liveblog-update>
          <h2><a href="/updates/#{index}">Update #{index}: Public event development</a></h2>
          <time datetime="2026-04-10T#{format("%02d", 8 + index)}:00:00">#{8 + index}:00 CET</time>
          <p>Officials confirmed development #{index}, described the public response, and explained the next steps in detail.</p>
          <p class="byline">By <a href="/authors/reporter-#{index}">Reporter #{index}</a></p>
          <footer><a href="/reports/background-#{index}">Background report #{index}</a></footer>
        </article>
      UPDATE
    end.join
  end

  def inline_liveblog_page
    <<~HTML
      <article class="liveblog-page">
        <h1>Public event updates</h1>
        <section class="live-updates">#{materialized_updates}</section>
      </article>
    HTML
  end

  it 'classifies independently linked root-page update cards as a list despite parent liveblog schema' do
    html = <<~HTML
      <html><head><title>Public event updates</title>#{schema_liveblog("Public event updates")}</head>
        <body><main><h1>Public event updates</h1>#{linked_cards}</main></body></html>
    HTML

    with_url_page('https://www.example.com/', html) do |page|
      payload = extract_payload(page)

      expect(payload['contentType']).to eq('list')
      expect(payload['contentFormat']).to eq('liveblog')
      (1..8).each do |index|
        expect(payload['markdown']).to include(
          "Live update #{index}",
          "https://www.example.com/updates/#{index}",
          "2026-04-10T#{format("%02d", 8 + index)}:00:00",
          "Verified development #{index} in a continuing public event."
        )
      end
    end
  end

  ['https://www.example.com/', 'https://www.example.com/live-coverage'].each do |url|
    it "retains all materialized inline updates with their owned parent at #{url}" do
      html = <<~HTML
        <html><head><title>Public event updates</title>#{schema_liveblog("Public event updates")}</head>
          <body><main>#{inline_liveblog_page}</main></body></html>
      HTML

      with_url_page(url, html) do |page|
        payload = extract_payload(page)

        expect(payload['contentType']).to eq('article')
        expect(payload['contentFormat']).to eq('liveblog')
        markdown = payload['markdown']
        positions = (1..3).map do |index|
          expect(markdown).to include(
            "Update #{index}: Public event development",
            "Officials confirmed development #{index}, described the public response, and explained the next steps in detail.",
            "Reporter #{index}",
            "https://www.example.com/authors/reporter-#{index}",
            "Background report #{index}",
            "https://www.example.com/reports/background-#{index}",
            "#{8 + index}:00 CET"
          )
          markdown.index("Update #{index}: Public event development")
        end
        expect(positions).to eq(positions.sort)
      end
    end
  end

  it 'retains homepage updates whose individual records carry the liveblog source marker' do
    html = <<~HTML
      <html><head><title>Public event updates</title>#{schema_liveblog("Public event updates")}</head>
        <body><main><h1>Public event updates</h1><section class="update-feed">#{materialized_updates}</section></main></body></html>
    HTML

    with_url_page('https://www.example.com/', html) do |page|
      payload = extract_payload(page)
      markdown = payload['markdown']

      expect(payload['contentType']).to eq('article')
      expect(payload['contentFormat']).to eq('liveblog')
      (1..3).each do |index|
        expect(markdown).to include(
          "Update #{index}: Public event development",
          "Reporter #{index}",
          "Background report #{index}",
          "https://www.example.com/reports/background-#{index}"
        )
      end
      expect((1..3).map { |index| markdown.index("Update #{index}: Public event development") }).to eq(
        (1..3).map { |index| markdown.index("Update #{index}: Public event development") }.sort
      )
    end
  end

  ['#update-', '/?post='].each do |destination|
    it "retains same-document updates addressed by #{destination} without liveblog CSS markers" do
      updates = materialized_updates
                .gsub('<article class="live-update" data-liveblog-update>', '<article>')
                .gsub(%r{href="/updates/(\d+)"}, "href=\"#{destination}\\1\"")
      html = <<~HTML
        <html><head><title>Public event updates</title>#{schema_liveblog("Public event updates")}</head>
          <body><main><h1>Public event updates</h1>#{updates}</main></body></html>
      HTML

      with_url_page('https://www.example.com/', html) do |page|
        payload = extract_payload(page)
        expect(payload['contentType']).to eq('article')
        expect(payload['contentFormat']).to eq('liveblog')
        positions = (1..3).map do |index|
          expect(payload['markdown']).to include(
            "Officials confirmed development #{index}", "Reporter #{index}", "Background report #{index}"
          )
          payload['markdown'].index("Update #{index}: Public event development")
        end
        expect(positions).not_to include(nil)
        expect(positions).to eq(positions.sort)
      end
    end
  end

  it 'does not let sidebar and related linked records displace a non-root liveblog parent' do
    liveblog = <<~HTML
      <article class="liveblog-page">
        <h1>Regional response live updates</h1>
        <section class="live-updates">
          <article class="live-update"><time datetime="2026-09-27T09:00:00Z">09:00</time><h2>Initial response</h2><p>Officials published the initial response after a new inspection, confirmed responsibility and explained the next public notice. <a href="/reports/initial">Background report</a></p></article>
          <article class="live-update"><time datetime="2026-09-27T10:30:00Z">10:30</time><h2>Bridge inspection complete</h2><p>Officials completed the bridge inspection after a new review, confirmed responsibility and explained the next public notice. <a href="/reports/bridge">Background report</a></p></article>
        </section>
      </article>
    HTML
    extras = <<~HTML
      <aside class="sidebar">#{linked_cards(count: 4)}</aside>
      <section class="related-stories">#{linked_cards(count: 4)}</section>
      <div hidden>#{linked_cards(count: 4)}</div>
    HTML
    html = <<~HTML
      <html><head><title>Regional response live updates</title>
        <link rel="canonical" href="https://wire.example/live/dispatch">
        #{schema_liveblog("Regional response live updates")}
      </head><body><main>#{liveblog}#{extras}</main></body></html>
    HTML

    with_url_page('https://wire.example/live/dispatch', html) do |page|
      payload = extract_payload(page)

      expect(payload['contentType']).to eq('article')
      expect(payload['contentFormat']).to eq('liveblog')
      expect(payload['markdown']).to include('Initial response', 'Bridge inspection complete')
      expect(payload['markdown']).not_to include('Live update 1')
    end
  end
end
