# frozen_string_literal: true

RSpec.describe 'FetchUtil Unidad Editorial extraction' do
  include_context 'extractor integration helpers'

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
