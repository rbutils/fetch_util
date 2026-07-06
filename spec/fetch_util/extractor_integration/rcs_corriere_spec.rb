# frozen_string_literal: true

RSpec.describe 'FetchUtil RCS Corriere extraction' do
  include_context 'extractor integration helpers'

  it 'extracts full public Corriere article bodies without teaser or false paywall warnings' do
    public_paragraphs = Array.new(14) do |index|
      <<~TEXT.strip
        L'ultima sparata di Donald Trump contro Giorgia Meloni arriva alla vigilia del vertice Nato di Ankara, con i governi europei impegnati a definire una posizione comune sulla difesa. La ricostruzione pubblica dell'articolo numero #{index + 1} descrive il contesto politico, le reazioni diplomatiche e i passaggi del confronto senza interrompersi dopo il sommario.
      TEXT
    end

    html = <<~HTML
      <html lang="it">
        <head>
          <title>Trump oltre ogni limite contro Meloni: «Serve un ordine restrittivo» | Corriere.it</title>
          <meta property="og:site_name" content="Corriere della Sera">
          <meta name="description" content="Il presidente Usa ha pubblicato sul suo social una foto che lo ritrae con la premier italiana.">
          <meta property="article:published_time" content="2026-07-05T21:15:22Z">
        </head>
        <body>
          <main>
            <section class="hero-teaser">
              <h1>Federica Cappelletti ricorda Paolo Rossi: «Non se ne voleva andare»</h1>
              <a href="/cronache/teaser.shtml">Una storia in evidenza da non confondere con l'articolo corrente.</a>
            </section>
            <div class="paywall piano">Abbonati per leggere contenuti premium e gestire il tuo account.</div>
            <section class="body-article has-font-sz-18">
              <h1 class="title-art-hp">Trump oltre ogni limite contro Meloni: «Serve un ordine restrittivo»</h1>
              <div class="column is-8" id="content-to-read" data-mrf-recirculation="Article links">
                <div class="content fxr-between-center"><span class="author-art">di <span class="writer">Paola Di Caro</span></span></div>
                <div class="widget-audio-article">Ascolta l'articolo 4 min Questo audio è generato in automatico.</div>
                <p>Il presidente Usa ha pubblicato sul suo social una foto che lo ritrae con la premier italiana.</p>
                #{public_paragraphs.map { |paragraph| "<p>#{paragraph}</p>" }.join("\n                ")}
                <p>La mossa del presidente americano scalda ancora di più il vertice Nato e chiude un articolo pubblico completo, non un semplice estratto riservato agli abbonati.</p>
                <div class="sharebar">Condividi questo articolo sui social</div>
                <div class="scoreboard">Portogallo0Spagna1FINE</div>
              </div>
            </section>
          </main>
        </body>
      </html>
    HTML

    url = 'https://www.corriere.it/esteri/26_luglio_05/trump-attacca-meloni-serve-un-ordine-restrittivo-946133ff-0f0f-4bc5-a9ea-4ace650a2xlk.shtml'

    extract_from_url(url, html) do |payload|
      expect_content_type(payload, 'article')
      expect(payload['markdown']).to include('Trump oltre ogni limite contro Meloni')
      expect(payload['markdown']).to include("L'ultima sparata di Donald Trump contro Giorgia Meloni")
      expect(payload['markdown']).to include('La mossa del presidente americano scalda ancora di più')
      expect(payload['markdown']).not_to include('Federica Cappelletti ricorda Paolo Rossi')
      expect(payload['markdown']).not_to include('Portogallo0Spagna1FINE')
      expect(payload['markdown']).not_to include('Ascolta l\'articolo')
      expect_warnings(payload, exclude: %w[paywall_partial_content empty_extraction short_extraction url_content_mismatch consent_interstitial])
    end
  end
end
