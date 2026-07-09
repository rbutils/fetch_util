# frozen_string_literal: true

RSpec.describe 'FetchUtil Ringier Axel Springer extraction' do
  include_context 'extractor integration helpers'

  it 'extracts Komputer Swiat summary, lead, and body ahead of video metadata fallback' do
    html = <<~HTML
      <html lang="pl">
        <head>
          <title>Wyładowania dodatnie to najgroźniejsze pioruny podczas burzy</title>
          <meta property="og:site_name" content="Komputer Świat">
          <meta property="og:type" content="video">
          <meta name="description" content="Wyładowania dodatnie stanowią zaledwie kilka procent wszystkich piorunów, ale są odpowiedzialne za najwięcej poważnych wypadków i pożarów.">
          <meta property="article:published_time" content="2026-07-05T18:34:31+0200">
          <script type="application/ld+json">
            {"@context":"https://schema.org","@type":"NewsArticle","articleBody":"Poznaj ich mechanizm powstawania, charakterystyczne cechy oraz powody, dla których nawet instalacja odgromowa może nie dać pełnej ochrony."}
          </script>
        </head>
        <body>
          <header><a href="/nauka-i-technika">Nauka i technika</a><a href="/gaming">Gaming</a></header>
          <article class="ods-article-lead" data-section="article-lead">
            <h1 class="ods-m-labeled-h1__text">Wyładowania dodatnie to najgroźniejsze pioruny podczas burzy. Jak powstają?</h1>
            <div class="ods-m-author-authorship__author-item"><a href="/autorzy/bartlomiej-sieja">Bartłomiej Sieja</a></div>
            <div class="ods-m-inline-summary-container__summary">
              <ul class="ods-m-inline-summary-container__list">
                <li>Wyładowania dodatnie są rzadkie, stanowią tylko kilka procent wszystkich piorunów.</li>
                <li>Są odpowiedzialne za najwyższą liczbę poważnych wypadków i pożarów.</li>
                <li>Ich mechanizm powstawania różni się od klasycznych piorunów.</li>
              </ul>
            </div>
            <div class="ods-m-video"><iframe src="https://pulsembed.example/video"></iframe></div>
            <section class="ods-a-lead"><p class="ods-a-lead-text">Wyładowania dodatnie stanowią zaledwie kilka procent wszystkich piorunów, ale są odpowiedzialne za najwięcej poważnych wypadków i pożarów.</p></section>
          </article>
          <main>
            <article class="ods-article-body" data-section="article-body" content-length="277" content-paywall-length="0">
              <div class="ods-a-body-text">Poznaj ich mechanizm powstawania, charakterystyczne cechy oraz powody, dla których nawet instalacja odgromowa może nie dać pełnej ochrony.</div>
            </article>
          </main>
          <aside class="ods-ads__ad-space"><a href="/reklama">Reklama</a></aside>
        </body>
      </html>
    HTML

    extract_from_url('https://www.komputerswiat.pl/nauka-i-technika/kosmos/wyladowania-dodatnie/cfns2q8', html) do |payload|
      expect_content_type(payload, 'article')
      expect(payload['markdown']).to include('## Streszczenie')
      expect(payload['markdown']).to include('Wyładowania dodatnie są rzadkie')
      expect(payload['markdown']).to include('Poznaj ich mechanizm powstawania')
      expect(payload['markdown']).not_to include('pulsembed')
      expect_warnings(payload, exclude: %w[short_extraction truncated_content multi_topic_page])
    end
  end

  it 'keeps Przeglad Sportowy Onet articles as clean articles' do
    html = <<~HTML
      <html lang="pl">
        <head>
          <title>91. minuta hitu i gol, Portugalia za burtą MŚ 2026</title>
          <meta property="og:site_name" content="Przegląd Sportowy Onet">
          <meta name="description" content="Portugalia przegrała z Hiszpanią po golu w doliczonym czasie gry.">
        </head>
        <body>
          <article class="ods-article-lead" data-section="article-lead">
            <h1 class="ods-m-labeled-h1__text">91. minuta hitu i gol, Portugalia za burtą MŚ 2026</h1>
            <div class="ods-m-inline-summary-container__summary"><ul class="ods-m-inline-summary-container__list"><li>Portugalia przegrała z Hiszpanią 0:1.</li><li>Decydującego gola zdobył Mikel Merino.</li><li>Cristiano Ronaldo był wściekły po ostatnim gwizdku.</li></ul></div>
            <section class="ods-a-lead"><p class="ods-a-lead-text">Hiszpania awansowała po dramatycznej końcówce spotkania.</p></section>
          </article>
          <article class="ods-article-body" data-section="article-body">
            <p>Ferran Torres ruszył prawą stroną boiska i zagrał dokładnie w pole karne.</p>
            <p>Mikel Merino wykorzystał podanie, a Portugalczycy nie zdążyli już odpowiedzieć.</p>
          </article>
        </body>
      </html>
    HTML

    extract_from_url('https://przegladsportowy.onet.pl/pilka-nozna/mistrzostwa-swiata-2026/portugalia-za-burta/w5qrxz0', html) do |payload|
      expect_content_type(payload, 'article')
      expect(payload['markdown']).to include('Ferran Torres ruszył prawą stroną boiska')
      expect(payload['markdown']).to include('Mikel Merino wykorzystał podanie')
      expect_warnings(payload, exclude: %w[short_extraction truncated_content])
    end
  end

  it 'preserves ordered Ringier article structure and meaningful media' do
    fixture = File.expand_path('../../fixtures/ringier_ods_sport_article_fidelity.html', __dir__)

    expect_fixture_article(
      url: 'https://przegladsportowy.onet.pl/reprezentacja-polski-poznala-rywala/w5qrxz0',
      fixture_path: fixture,
      includes: [
        '# Zespol poznal termin kolejnego spotkania',
        '## Streszczenie',
        '- Zespol otrzymal informacje o planowanym spotkaniu.',
        'Zespol rozpocznie przygotowania do zaplanowanego spotkania.',
        'Pierwszy akapit przedstawia decyzje organizacyjne',
        'Drugi akapit porzadkuje dane dotyczace przygotowan',
        '![Zespol podczas sesji przygotowawczej](https://cdn.example.test/poland-team.jpg)',
        'Zespol podczas sesji przygotowawczej.',
        '1. Pierwszy etap harmonogramu.',
        '2. Kolejna sesja kontrolna.',
        'Ostatni akapit porzadkuje notatke'
      ],
      excludes: [
        'Dalszy ciąg artykułu pod materiałem wideo',
        'Niezwiązana rekomendacja',
        'advertising navigation chrome',
        'Financial Statement Links',
        'financial-report.pdf',
        'Strona główna'
      ],
      warning_excludes: %w[short_extraction truncated_content],
      byline: 'Edyta Kowalczyk',
      published_time: '2026-07-10T12:30:00+02:00'
    )
  end
end
