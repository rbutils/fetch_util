# frozen_string_literal: true

RSpec.describe 'FetchUtil extractor integration' do
  include_context 'extractor integration helpers'

  it "extracts Globo article bodies instead of regional navigation lists" do
    html = <<~HTML
      <html>
        <head>
          <title>Morre Tiago Pitthan, que organizou festa para o próprio velório após diagnóstico terminal | G1</title>
          <meta property="og:site_name" content="G1">
          <meta name="description" content="Aos 47 anos, ele transformou a própria despedida em um encontro com música, amigos e histórias.">
        </head>
        <body class="multicontent amp-mode-mouse">
          <nav>
            <a href="https://globoplay.globo.com/globo-comunidade-df/p/4504/">Globo Comunidade DF</a>
            <a href="https://globoplay.globo.com/bom-dia-go/p/5368/">Bom Dia GO</a>
            <a href="https://globoplay.globo.com/ja-1a-edicao/p/5369/">JA 1ª Edição</a>
            <a href="https://globoplay.globo.com/mttv-1a-edicao-cuiaba/p/5246/">MT TV 1ª Edição</a>
          </nav>
          <main class="mc-body theme">
            <h1 class="content-head__title">Morre Tiago Pitthan, que organizou festa para o próprio velório após diagnóstico terminal: 'Tudo valeu a pena'</h1>
            <p class="content-head__subtitle">Aos 47 anos, ele transformou a própria despedida em um encontro com música, amigos e histórias.</p>
            <div class="content-publication-data__from">Por Talyta Vespa, g1</div>
            <article>
              <div class="mc-article-body">
                <article class="cxm-block-video__player-wrapper">Assista também no 00:00 / 01:56 Minimizar vídeo</article>
                <p class="codex-caption codex-caption--small">Morre Tiago Pitthan, que organizou festa para o próprio velório após diagnóstico terminal</p>
                <p class="content-text__container">Tiago Martins Pitthan, o homem que decidiu organizar o próprio velório porque não queria faltar à despedida, morreu aos 47 anos, em Campo Grande.</p>
                <p class="content-text__container">Diagnosticado com um câncer de estômago em estágio avançado, ele transformou o que costuma ser um momento de ausência em presença: reuniu amigos, familiares e desconhecidos para celebrar a própria história.</p>
                <p class="content-text__container">No hospital, Tiago publicou um último vídeo nas redes sociais e deixou uma mensagem de despedida dizendo que estava em paz e feliz.</p>
                <blockquote>“Estou bem, em paz, feliz. Valeu a pena. Tudo valeu a pena. Tive uma vida boa e é isso. Eu venci.”</blockquote>
                <p class="content-text__container">A história mobilizou pessoas de várias cidades, que enviaram mensagens de carinho e lembraram a forma generosa como ele encarou o tratamento.</p>
              </div>
            </article>
          </main>
        </body>
      </html>
    HTML

    extract_from_url("https://g1.globo.com/saude/noticia/2026/07/06/morre-tiago-pitthan.ghtml", html) do |payload|
      expect_content_type(payload, "article")
      expect(payload["markdown"]).to include("Tiago Martins Pitthan, o homem que decidiu organizar o próprio velório")
      expect(payload["markdown"]).to include("Tudo valeu a pena")
      expect(payload["markdown"]).not_to include("Globo Comunidade DF")
      expect(payload["markdown"]).not_to include("Minimizar vídeo")
      expect_warnings(payload, exclude: %w[empty_extraction short_extraction url_content_mismatch consent_interstitial])
    end
  end
end
