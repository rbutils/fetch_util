# frozen_string_literal: true

RSpec.describe 'FetchUtil Unidad Editorial extraction' do
  include_context 'extractor integration helpers'

  it 'extracts Marca article bodies without false truncation warnings' do
    expect_fixture_article(
      url: 'https://www.marca.com/futbol/mundial/cronica/2026/07/07/belgica-acaba-trumpas-cita-espana-cuartos.html',
      fixture_path: File.expand_path('../../fixtures/marca_article.html', __dir__),
      includes: [
        '# Ni Trump puede evitar lo inevitable',
        'Bélgica convirtió el ruido en rabia',
        'La mejor Bélgica del Mundial',
        'Freese regala el tercero'
      ],
      excludes: ['Power Ranking', 'Compartir en redes sociales', 'Suscríbete'],
      warning_excludes: %w[truncated_content empty_extraction short_extraction url_content_mismatch consent_interstitial]
    )
  end

  it 'extracts full public El Mundo article bodies without false paywall warnings' do
    public_paragraphs = Array.new(5) do |index|
      <<~TEXT.strip
        La decisión la ha adoptado el magistrado Antonio Viejo en sustitución de Juan Carlos Peinado, que este lunes había iniciado una semana de vacaciones, después de revisar los escritos de las partes y comprobar que el permiso solicitado no impide mantener las medidas cautelares acordadas en la causa número #{index + 1}.
        El auto permite a Begoña Gómez viajar a Londres para asistir a la graduación de su hija, pero no acompañar a Pedro Sánchez a la cumbre de la OTAN en Ankara mientras continúa la investigación judicial.
      TEXT
    end

    html = <<~HTML
      <html lang="es">
        <head>
          <title>El juez no autoriza a Begoña Gómez a acompañar a Pedro Sánchez a la cumbre de la OTAN</title>
          <meta property="og:site_name" content="EL MUNDO">
          <meta name="description" content="La decisión la ha adoptado el magistrado Antonio Viejo.">
          <script type="application/ld+json">
            {"@context":"https://schema.org","@type":"NewsArticle","headline":"El juez no autoriza a Begoña Gómez a acompañar a Pedro Sánchez a la cumbre de la OTAN","isAccessibleForFree":"False"}
          </script>
        </head>
        <body>
          <main>
            <h1 class="ue-c-article__title">El juez no autoriza a Begoña Gómez a acompañar a Pedro Sánchez a la cumbre de la OTAN</h1>
            <p class="ue-c-article__standfirst">La decisión la ha adoptado el magistrado Antonio Viejo en sustitución de Juan Carlos Peinado.</p>
            <div class="ue-c-paywall">Suscríbete para acceder a todas las ventajas de PREMIUM.</div>
            <div class="ue-c-article__body" data-section="articleBody">
              #{public_paragraphs.map { |paragraph| "<p class=\"ue-c-article__paragraph\">#{paragraph}</p>" }.join("\n              ")}
              <div class="ue-c-article__share">Compartir en redes sociales</div>
              <section class="ue-c-article__comments"><a href="#comments">Comentarios</a></section>
            </div>
          </main>
        </body>
      </html>
    HTML

    url = 'https://www.elmundo.es/espana/2026/07/06/el-juez-no-autoriza-begona-gomez-acompanar-pedro-sanchez-cumbre-otan-ankara-londres-graduacion-hija.html'

    extract_from_url(url, html) do |payload|
      expect_content_type(payload, 'article')
      expect(payload['markdown']).to include('# El juez no autoriza a Begoña Gómez')
      expect(payload['markdown']).to include('La decisión la ha adoptado el magistrado Antonio Viejo')
      expect(payload['markdown']).not_to include('Suscríbete para acceder')
      expect(payload['markdown']).not_to include('Comentarios')
      expect_warnings(payload, exclude: %w[paywall_partial_content empty_extraction short_extraction url_content_mismatch consent_interstitial])
    end
  end

  it 'extracts full public Sport article bodies without false paywall warnings' do
    public_paragraphs = [
      <<~TEXT.strip,
        El Madrid sigue en su empeño de reventar el mercado de fichajes. Ayer oficializó la incorporación de Dumfries,
        una manera de reconocer que la llegada de Trent Alexander-Arnold ha sido de momento un sonoro fracaso y que el
        club blanco vuelve a corregir su propia planificación.
      TEXT
      <<~TEXT.strip,
        Hay una primera lectura curiosa de los movimientos sísmicos en el mercado blanco: su innegable voluntad de
        autoenmendarse la plana, como si los refuerzos que hizo hace solo doce meses fueran casi papel mojado para la
        nueva dirección deportiva.
      TEXT
      <<~TEXT.strip,
        Dicho esto, el movimiento Dumfries-Cucurella es sin duda estratégico e independientemente de cómo termine
        resultando su rendimiento es consecuencia de una acertada visión sobre el creciente rol de los laterales en el
        fútbol moderno.
      TEXT
      <<~TEXT.strip,
        El doble fichaje Dumfries-Cucurella pone sobre la mesa que el Real Madrid va a intentar jugar la Champions de los
        laterales y evidencia su obsesión con una posición que se ha convertido en decisiva para atacar y defender.
      TEXT
      <<~TEXT.strip,
        La jugada de ajedrez de los laterales blancos pondrá inevitablemente deberes al Barça, tranquilo en la Liga,
        donde solventa sus compromisos casi sin despeinarse, pero demasiado exigido en Europa, donde esta temporada ha
        vuelto a comprobar que todavía le falta un peldaño para llegar a la élite continental.
      TEXT
      <<~TEXT.strip
        El equipo de Flick necesita o bien recuperar la mejor versión de Balde y Koundé, o bien encontrar otra joya en La
        Masia, o bien reforzar esa demarcación. También en el mercado, Madrid y Barça siguen siendo vasos comunicantes.
      TEXT
    ]

    html = <<~HTML
      <html lang="es">
        <head>
          <title>Dos fichajes, un mensaje: el mercato blanco que pone deberes al Barça</title>
          <meta property="og:site_name" content="SPORT">
          <script type="application/ld+json">
            {"@context":"https://schema.org","@type":"NewsArticle","headline":"Dos fichajes, un mensaje: el mercato blanco que pone deberes al Barça","isAccessibleForFree":"False"}
          </script>
        </head>
        <body>
          <article>
            <header>
              <h1 class="ft-title">Dos fichajes, un mensaje: el mercato blanco que pone deberes al Barça</h1>
              <div class="ft-mol-writer"><p class="ft-mol-writer__titleOpinion">Ernest Folch</p></div>
            </header>
            <div class="ft-layout-grid-flex__colXs-12 ft-layout-grid-flex__colSm-11">
              <div class="ft-mol-multimedia">0 seconds of 0 seconds Volume 0% Cargando anuncio</div>
              #{public_paragraphs.map { |paragraph| "<p class=\"ft-text\">#{paragraph}</p>" }.join("\n              ")}
              <div class="ft-mol-related">Noticias relacionadas y más</div>
              <div class="ft-ad ft-ad--taboola">CONTENIDO PATROCINADO</div>
            </div>
          </article>
        </body>
      </html>
    HTML

    url = 'https://www.sport.es/es/noticias/opinion/fichajes-mensaje-mercato-blanco-pone-132148159'

    extract_from_url(url, html) do |payload|
      expect_content_type(payload, 'article')
      expect(payload['markdown']).to include('# Dos fichajes, un mensaje')
      expect(payload['markdown']).to include('El Madrid sigue en su empeño de reventar el mercado de fichajes')
      expect(payload['markdown']).to include('El equipo de Flick necesita o bien recuperar la mejor versión de Balde')
      expect(payload['markdown']).not_to include('Cargando anuncio')
      expect(payload['markdown']).not_to include('Noticias relacionadas')
      expect(payload['markdown']).not_to include('CONTENIDO PATROCINADO')
      expect_warnings(payload, exclude: %w[paywall_partial_content empty_extraction short_extraction url_content_mismatch consent_interstitial])
    end
  end

  it 'keeps El Mundo homepage story lists from using comment links as articles' do
    html = <<~HTML
      <html lang="es">
        <head><title>EL MUNDO - Portada</title><meta property="og:site_name" content="EL MUNDO"></head>
        <body>
          <main>
            #{Array.new(5) do |index|
              <<~CARD
                <article class="ue-c-cover-content">
                  <h2><a class="ue-c-cover-content__link" href="/espana/2026/07/0#{index + 1}/6a4bd739e85ece9b0f8b45#{index}#{index}.html"><span class="ue-c-cover-content__headline">Historia principal de portada con enfoque informativo #{index + 1}</span></a></h2>
                  <a class="ue-c-cover-content__comments" href="/comentarios/noticia-#{index}">#{20 + index} comentarios</a>
                  <p>Detalle de apoyo para la noticia principal de portada #{index + 1}.</p>
                </article>
              CARD
            end.join}
          </main>
        </body>
      </html>
    HTML

    extract_from_url('https://www.elmundo.es/', html) do |payload|
      expect_content_type(payload, 'list')
      expect(payload['markdown']).to include('Historia principal de portada con enfoque informativo 1')
      expect(payload['markdown']).not_to include('/comentarios/noticia')
      expect(payload['markdown']).not_to include('comentarios](https://www.elmundo.es/comentarios')
    end
  end
end
