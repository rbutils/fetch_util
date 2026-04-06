# frozen_string_literal: true

RSpec.describe 'FetchUtil extractor integration' do
  include_context 'extractor integration helpers'

  it "treats numeric slug article pages as article-like instead of related-story lists" do
    html = <<~HTML
      <html>
        <head>
          <title>Morocco condemns Iranian attacks on Arab states at UN Human Rights Council</title>
          <meta name="description" content="Morocco condemns Iranian attacks on Arab states at UN Human Rights Council">
        </head>
        <body>
          <main>
            <article>
              <h1>Morocco condemns Iranian attacks on Arab states at UN Human Rights Council</h1>
              <p>By Hespress EN</p>
              <p>Morocco condemned the attacks and urged respect for the sovereignty of Arab states during the UN Human Rights Council session.</p>
              <p>The foreign ministry said the escalation threatens regional stability and called for restraint.</p>
              <p>Officials reiterated support for diplomatic efforts and emphasized the importance of multilateral dialogue.</p>
            </article>
            <section>
              <h2>RELATED ARTICLES</h2>
              <article><h3><a href="/story/a">War in the Middle East: casualty figures</a></h3></article>
              <article><h3><a href="/story/b">Iran rejects US proposal</a></h3></article>
              <article><h3><a href="/story/c">Gulf states ask for de-escalation</a></h3></article>
            </section>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://en.hespress.com/134438-morocco-condemns-iranian-attacks-on-arab-states-at-un-human-rights-council.html", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["contentType"]).to eq("article")
      expect(payload["markdown"]).to include("Morocco condemned the attacks")
      expect(payload["markdown"]).not_to include("War in the Middle East")
      expect(payload["markdown"]).not_to include("RELATED ARTICLES")
    end
  end

  it "demotes tv schedule promo tiles when stronger news headlines are present" do
    html = <<~HTML
      <html>
        <head>
          <title>Vsak dan prvi | 24ur.com</title>
        </head>
        <body>
          <header>
            <a href="/slovenija">Slovenija</a>
            <a href="/tujina">Tujina</a>
            <a href="/sport">Šport</a>
          </header>
          <main>
            <section class="promo-schedule">
              <article>
                <h2><a href="/tv/a">Spin Fighters vrtavke</a></h2>
                <p>Vsak dan 21.55</p>
              </article>
              <article>
                <h2><a href="/tv/b">MotoGP - dirka VN Amerik</a></h2>
                <p>Poglej več</p>
              </article>
            </section>
            <section class="news-stream">
              <article>
                <h2><a href="/novice/a">Veter odkriva strehe, podira drevesa po Sloveniji</a></h2>
                <p>Močan veter je povzročil težave v več regijah.</p>
              </article>
              <article>
                <h2><a href="/novice/b">Inšpekcijski nadzor: Petrol mora prilagoditi poslovanje</a></h2>
                <p>Odločitev je sprožila odzive v gospodarstvu.</p>
              </article>
              <article>
                <h2><a href="/novice/c">Batistuta o Maradoni in argentinski reprezentanci</a></h2>
                <p>Nekdanji napadalec je spregovoril o nogometni zapuščini.</p>
              </article>
            </section>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://www.24ur.com/", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["markdown"]).to include("Veter odkriva strehe")
      expect(payload["markdown"]).to include("Inšpekcijski nadzor")
      expect(payload["markdown"]).not_to include("Spin Fighters vrtavke")
      expect(payload["markdown"]).not_to include("Vsak dan 21.55")
    end
  end

  it "prefers real news stories over weather widgets on news index pages" do
    html = <<~HTML
      <html>
        <head>
          <title>Fréttir - RÚV.is</title>
        </head>
        <body>
          <main>
            <article class="weather-widget">
              <h3>Veðurspá næsta sólarhring</h3>
              <p>Veðurspá. Reykjavík. Í kvöld: Rigning, su-suðaustan 5, hiti 4 stig, úrkoma 0.3 millimetrar.</p>
              <p>Veðurspá. Akureyri. Á morgun: Alskýjað, norðan 8, hiti 2 stig, úrkoma 0 millimetrar.</p>
              <p>Veðurspá. Ísafjörður. Á miðnætti: Alskýjað, aust-norð-austan 10, frost 2 stig.</p>
            </article>
            <section class="news-stream">
              <article>
                <h2><a href="/frettir/a1">Sjö sóttu um forstjórastöðu á SAk</a></h2>
                <p>Sjúkrahúsið á Akureyri hefur birt umsækjendalista og hefst nú ráðningarferlið.</p>
              </article>
              <article>
                <h2><a href="/frettir/a2">McCartney gefur út nýtt lag þrungið minningum frá Liverpool</a></h2>
                <p>Ný plata kemur út í maílok og er sögð byggja á bernskuminningum hans.</p>
              </article>
              <article>
                <h2><a href="/frettir/a3">Leiðtogar Íslands, Noregs og Finnlands vilja auka stuðning við Úkraínu</a></h2>
                <p>Forsætisráðherrarnir funduðu í Reykjavík og kölluðu eftir áframhaldandi samstöðu.</p>
              </article>
            </section>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://www.ruv.is/frettir", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["markdown"]).to include("Sjö sóttu um forstjórastöðu á SAk")
      expect(payload["markdown"]).to include("McCartney gefur út nýtt lag")
      expect(payload["markdown"]).not_to include("Veðurspá næsta sólarhring")
    end
  end
end
