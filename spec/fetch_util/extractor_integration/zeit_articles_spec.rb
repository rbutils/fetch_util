# frozen_string_literal: true

RSpec.describe 'FetchUtil extractor integration for Zeit articles' do
  include_context 'extractor integration helpers'

  def extract_with_dom_observation(page, reader_mode: true, inject_assets: true)
    extractor_for(reader_mode).__send__(:inject_assets, page) if inject_assets
    before = page.evaluate('document.documentElement.outerHTML')
    extraction = page.evaluate_async(<<~JS, 5)
      const done = arguments[arguments.length - 1];
      const mutations = [];
      const observer = new MutationObserver(function(records) {
        records.forEach(function(record) {
          mutations.push({
            type: record.type,
            target: record.target.nodeName,
            attribute: record.attributeName || null
          });
        });
      });
      observer.observe(document.documentElement, {
        subtree: true,
        childList: true,
        attributes: true,
        characterData: true
      });
      const payload = window.FetchUtilExtract.extract({reader_mode: #{reader_mode}});
      setTimeout(function() {
        observer.takeRecords().forEach(function(record) {
          mutations.push({
            type: record.type,
            target: record.target.nodeName,
            attribute: record.attributeName || null
          });
        });
        observer.disconnect();
        done({payload, mutations});
      }, 0);
    JS

    [extraction.fetch('payload'), extraction.fetch('mutations'), before,
     page.evaluate('document.documentElement.outerHTML')]
  end

  it "extracts the visible Zeit article body without false empty warnings" do
    html = <<~HTML
      <html>
        <head>
          <title>Der Fall Balogun: Trump bestätigt Bitte um Überprüfung der Balogun-Sperre | DIE ZEIT</title>
          <meta property="og:site_name" content="DIE ZEIT">
          <meta name="description" content="Trump spricht über Baloguns Sperre.">
          <meta property="article:author" content="https://www.zeit.de/autoren/V/Yannick_von-Eisenhart-Rothe/index">
          <script type="application/ld+json">
            {
              "@context": "https://schema.org",
              "@type": "Article",
              "headline": "Trump bestätigt Bitte um Überprüfung der Balogun-Sperre",
              "author": { "@type": "Person", "name": "Yannick von Eisenhart Rothe" }
            }
          </script>
        </head>
        <body>
          <main class="main main--article" id="main">
            <article class="article article--padded article--article" id="js-article">
              <header class="article-header" data-ct-area="articleheader">
                <h1 class="article-heading">
                  <span class="article-heading__kicker">Der Fall Balogun</span><span class="visually-hidden">: </span><span class="article-heading__title">Trump bestätigt Bitte um Überprüfung der Balogun-Sperre</span>
                </h1>
                <div class="summary">»Ich habe lediglich um eine Überprüfung gebeten«, sagt Trump zu seinem Gespräch mit Fifa-Präsident Infantino.</div>
                <a rel="author" title="Yannick von Eisenhart Rothe" href="/autoren/V/Yannick_von-Eisenhart-Rothe/index">yer</a>
              </header>
              <figure>Donald Trump sprach im Oval Office über den Fall Balogun.</figure>
              <div class="article-body article-body--article">
                <div class="iqdcontainer" data-placement="pos_1"></div>
                <div class="audio-player">Ihr Browser kann dieses Tondokument nicht wiedergeben.</div>
                <div class="article-page" data-page-number="1">
                  <p class="paragraph article__item">US-Präsident Donald Trump hat bestätigt, dass er wegen der Roten Karte gegen US-Nationalspieler Folarin Balogun mit Fifa-Präsident Gianni Infantino gesprochen hat. Er habe nicht explizit gefordert, dass die Sperre aufgehoben werde.</p>
                  <p class="paragraph article__item">Die Fifa hatte die Sperre Baloguns für das Viertelfinalspiel gegen Belgien aufgehoben und für ein Jahr auf Bewährung ausgesetzt. Zuvor hatten diverse Medien berichtet, Trump habe sich in die Entscheidung eingemischt.</p>
                  <h2 class="article__item">»Ich wusste nicht, was zur Hölle eine Rote Karte ist«</h2>
                  <p class="paragraph article__item">Er denke, dass die besten Spieler mitspielen müssten, sagte Trump. Die Fifa habe eine brillante Entscheidung getroffen. Die Entscheidung des Schiedsrichters, Balogun vom Platz zu stellen, sei furchtbar gewesen.</p>
                  <aside aria-label="Newsletteranmeldung">Melden Sie sich für den Newsletter an.</aside>
                  <p class="paragraph article__item">Fifa-Präsident Infantino bestätigte in einer Mitteilung ebenfalls, dass Trump ihn wegen der Roten Karte angerufen habe. Er habe diesem erklärt, dass ein laufendes juristisches Verfahren unter der Beteiligung unabhängiger Gremien laufe.</p>
                  <p class="paragraph article__item">Im Sechzehntelfinale der USA gegen Bosnien-Herzegowina war Balogun einem Gegenspieler aus Versehen so auf den Fuß getreten, dass dieser umknickte. Nach Eingriff des Videoassistenten sah der Schiedsrichter sich die Situation an und stellte Balogun vom Platz.</p>
                  <h2 class="article__item">Fifa weist Beschwerde Belgiens zurück</h2>
                  <p class="paragraph article__item">Der belgische Fußballverband legte Einspruch gegen die Aufhebung der Sperre ein. Die Fifa erklärte den Einspruch jedoch für unzulässig, weil der belgische Verband nicht Verfahrenspartei sei.</p>
                </div>
              </div>
              <footer class="article-footer">
                <button>Kommentieren</button><button>Link kopieren</button>
                <nav class="article-tags"><a href="https://www.zeit.de/thema/fussball-wm">Fußball-WM</a></nav>
              </footer>
              <aside aria-label="Mehr zum Thema: Der Fall Balogun">Selbst Sepp Blatter wundert sich</aside>
              <nav aria-label="Seitennavigation"><a href="#comments">Kommentieren</a></nav>
            </article>
          </main>
        </body>
      </html>
    HTML

    url = "https://www.zeit.de/sport/2026-07/donald-trump-gianni-infantino-folarin-balogun-rote-karte-fifa"
    with_url_page(url, html) do |page|
      payload, mutations, before, after = extract_with_dom_observation(page)
      markdown = payload.fetch("markdown")

      expect(payload).to include(
        "contentType" => "article",
        "byline" => "Yannick von Eisenhart Rothe",
        "hostAware" => false,
        "readerMode" => true,
        "suspect" => false,
        "warnings" => []
      )
      expect(markdown).to include(
        "# Der Fall Balogun",
        "US-Präsident Donald Trump hat bestätigt",
        "Nach Eingriff des Videoassistenten",
        "Fifa weist Beschwerde Belgiens zurück",
        "Der belgische Fußballverband legte Einspruch",
        "[Yannick von Eisenhart Rothe](https://www.zeit.de/autoren/V/Yannick_von-Eisenhart-Rothe/index)"
      )
      ordered_body = [
        "»Ich habe lediglich um eine Überprüfung gebeten«",
        "Donald Trump sprach im Oval Office",
        "US-Präsident Donald Trump hat bestätigt",
        "Die Fifa hatte die Sperre Baloguns",
        "»Ich wusste nicht, was zur Hölle eine Rote Karte ist«",
        "Er denke, dass die besten Spieler mitspielen müssten",
        "Fifa-Präsident Infantino bestätigte",
        "Im Sechzehntelfinale der USA gegen Bosnien-Herzegowina",
        "Fifa weist Beschwerde Belgiens zurück",
        "Der belgische Fußballverband legte Einspruch"
      ]
      positions = ordered_body.map { |text| markdown.index(text) }
      expect(positions).to all(be_a(Integer))
      expect(positions.each_cons(2).all? { |left, right| left < right }).to be(true)
      expect(markdown).not_to include(
        "Ihr Browser kann dieses Tondokument nicht wiedergeben",
        "Link kopieren",
        "Newsletteranmeldung",
        "Selbst Sepp Blatter wundert sich"
      )
      expect(payload.fetch("html")).to include(
        'rel="author"',
        'href="https://www.zeit.de/autoren/V/Yannick_von-Eisenhart-Rothe/index"'
      )
      expect(markdown.scan("https://www.zeit.de/autoren/V/Yannick_von-Eisenhart-Rothe/index").length).to eq(1)
      expect(mutations).to eq([])
      expect(after).to eq(before)

      fallback, fallback_mutations, fallback_before, fallback_after = extract_with_dom_observation(
        page,
        reader_mode: false,
        inject_assets: false
      )
      expect(fallback).to include(
        "contentType" => "article",
        "byline" => "Yannick von Eisenhart Rothe",
        "hostAware" => false,
        "readerMode" => false,
        "suspect" => false,
        "warnings" => []
      )
      fallback_markdown = fallback.fetch("markdown")
      fallback_positions = ordered_body.map { |text| fallback_markdown.index(text) }
      expect(fallback_positions).to all(be_a(Integer))
      expect(fallback_positions.each_cons(2).all? { |left, right| left < right }).to be(true)
      expect(
        fallback_markdown.scan(
          "https://www.zeit.de/autoren/V/Yannick_von-Eisenhart-Rothe/index"
        ).length
      ).to eq(1)
      expect(fallback_mutations).to eq([])
      expect(fallback_after).to eq(fallback_before)
      expect(page.evaluate("document.documentElement.outerHTML")).to eq(before)
    end
  end

  it "preserves shared Zeit article resources without the profile" do
    html = <<~HTML
      <main>
        <article>
          <h1>Zeit Artikel mit eigenständigen Ressourcen</h1>
          <p>Der erste ausführliche Absatz beschreibt den Kern der Nachricht und ordnet das Ereignis sachlich ein.</p>
          <figure>
            <img src="/images/zeit-article.jpg" alt="Redaktionelles Zeit-Foto">
            <figcaption>Das redaktionelle Bild gehört unmittelbar zum Artikel.</figcaption>
          </figure>
          <p>Der zweite ausführliche Absatz verweist auf die <a href="/politik/hintergrund">vollständige Hintergrundanalyse</a> der Redaktion.</p>
          <p>Der dritte ausführliche Absatz erläutert die Folgen des Ereignisses und schließt den Artikel vollständig ab.</p>
        </article>
      </main>
    HTML

    with_url_page("https://www.zeit.de/politik/2026-09/zeit-resources", html) do |page|
      payload, mutations, before, after = extract_with_dom_observation(page)

      expect(payload).to include("contentType" => "article", "hostAware" => false, "warnings" => [])
      expect(payload.fetch("markdown")).to include(
        "![Redaktionelles Zeit-Foto](https://www.zeit.de/images/zeit-article.jpg)",
        "[vollständige Hintergrundanalyse](https://www.zeit.de/politik/hintergrund)",
        "Der dritte ausführliche Absatz"
      )
      resource_order = [
        "Der erste ausführliche Absatz",
        "![Redaktionelles Zeit-Foto](https://www.zeit.de/images/zeit-article.jpg)",
        "Das redaktionelle Bild gehört unmittelbar zum Artikel.",
        "[vollständige Hintergrundanalyse](https://www.zeit.de/politik/hintergrund)",
        "Der dritte ausführliche Absatz"
      ]
      positions = resource_order.map { |text| payload.fetch("markdown").index(text) }
      expect(positions).to all(be_a(Integer))
      expect(positions.each_cons(2).all? { |left, right| left < right }).to be(true)
      expect(mutations).to eq([])
      expect(after).to eq(before)
    end
  end

  it "leaves Zeit homepages on shared list extraction" do
    cards = (1..6).map do |index|
      <<~HTML
        <article>
          <h2><a href="/politik/2026-09/zeit-story-#{index}">Zeit Titel #{index}</a></h2>
          <p>Eigenständige Zusammenfassung der Zeit-Nachricht #{index}.</p>
        </article>
      HTML
    end.join
    html = "<main><h1>DIE ZEIT</h1>#{cards}</main>"

    with_url_page("https://www.zeit.de/", html) do |page|
      payload, mutations, before, after = extract_with_dom_observation(page)

      expect(payload).to include(
        "contentType" => "list",
        "hostAware" => false,
        "suspect" => true,
        "warnings" => ["multi_topic_page"]
      )
      (1..6).each do |index|
        expect(payload.fetch("markdown")).to include(
          "[Zeit Titel #{index}](https://www.zeit.de/politik/2026-09/zeit-story-#{index})"
        )
      end
      expect(mutations).to eq([])
      expect(after).to eq(before)
    end
  end
end
