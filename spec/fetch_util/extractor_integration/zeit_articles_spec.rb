# frozen_string_literal: true

RSpec.describe 'FetchUtil extractor integration for Zeit articles' do
  include_context 'extractor integration helpers'

  it "extracts the visible Zeit article body without false empty warnings" do
    html = <<~HTML
      <html>
        <head>
          <title>Der Fall Balogun: Trump bestätigt Bitte um Überprüfung der Balogun-Sperre | DIE ZEIT</title>
          <meta property="og:site_name" content="DIE ZEIT">
          <meta name="description" content="Trump spricht über Baloguns Sperre.">
        </head>
        <body>
          <main class="main main--article" id="main">
            <article class="article article--padded article--article" id="js-article">
              <header class="article-header" data-ct-area="articleheader">
                <h1 class="article-heading">
                  <span class="article-heading__kicker">Der Fall Balogun</span><span class="visually-hidden">: </span><span class="article-heading__title">Trump bestätigt Bitte um Überprüfung der Balogun-Sperre</span>
                </h1>
                <div class="summary">»Ich habe lediglich um eine Überprüfung gebeten«, sagt Trump zu seinem Gespräch mit Fifa-Präsident Infantino.</div>
              </header>
              <figure>Donald Trump sprach im Oval Office über den Fall Balogun.</figure>
              <div class="article-body article-body--article">
                <div class="iqdcontainer" data-placement="pos_1"></div>
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
              <aside aria-label="Mehr zum Thema: Der Fall Balogun">Selbst Sepp Blatter wundert sich</aside>
              <nav aria-label="Seitennavigation"><a href="#comments">Kommentieren</a></nav>
            </article>
          </main>
        </body>
      </html>
    HTML

    extract_from_url("https://www.zeit.de/sport/2026-07/donald-trump-gianni-infantino-folarin-balogun-rote-karte-fifa", html) do |payload|
      expect_content_type(payload, "article")
      expect(payload["markdown"]).to include("# Der Fall Balogun")
      expect(payload["markdown"]).to include("US-Präsident Donald Trump hat bestätigt")
      expect(payload["markdown"]).to include("Fifa weist Beschwerde Belgiens zurück")
      expect(payload["markdown"]).not_to include("Newsletteranmeldung")
      expect(payload["markdown"]).not_to include("Selbst Sepp Blatter wundert sich")
      expect_warnings(payload, exclude: %w[empty_extraction short_extraction url_content_mismatch consent_interstitial])
    end
  end
end
