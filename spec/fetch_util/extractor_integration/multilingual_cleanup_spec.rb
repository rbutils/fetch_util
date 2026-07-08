# frozen_string_literal: true

RSpec.describe 'FetchUtil extractor integration – multilingual cleanup' do
  include_context 'extractor integration helpers'

  describe "lazy-loaded image resolution" do
    it "resolves data-lazy-src when src is an SVG placeholder" do
      html = <<~HTML
        <html>
          <body>
            <main>
              <article>
                <h1>Bordeaux Wine Guide</h1>
                <p>The finest châteaux of Bordeaux.</p>
                <img src="data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 300 200'%3E%3C/svg%3E"
                     data-lazy-src="https://example.com/chateau.jpg"
                     alt="Château photo">
              </article>
            </main>
          </body>
        </html>
      HTML

      with_page(html) do |page|
        payload = FetchUtil::Extractor.new.extract(page)

        expect(payload["markdown"]).to include("chateau.jpg")
        expect(payload["markdown"]).not_to include("data:image/svg+xml")
      end
    end

    it "resolves data-lazy when src is missing" do
      html = <<~HTML
        <html>
          <body>
            <main>
              <article>
                <h1>Image Test</h1>
                <p>A paragraph of content for the article extraction.</p>
                <img data-lazy="https://example.com/lazy-image.jpg" alt="Lazy loaded">
              </article>
            </main>
          </body>
        </html>
      HTML

      with_page(html) do |page|
        payload = FetchUtil::Extractor.new.extract(page)

        expect(payload["markdown"]).to include("lazy-image.jpg")
      end
    end

    it "keeps original src when it is a real URL even if data-lazy-src is present" do
      html = <<~HTML
        <html>
          <body>
            <main>
              <article>
                <h1>Image Test</h1>
                <p>Content with a real image that also has lazy attributes.</p>
                <img src="https://example.com/real.jpg"
                     data-lazy-src="https://example.com/lazy.jpg"
                     alt="Real image">
              </article>
            </main>
          </body>
        </html>
      HTML

      with_page(html) do |page|
        payload = FetchUtil::Extractor.new.extract(page)

        expect(payload["markdown"]).to include("real.jpg")
      end
    end
  end

  describe "comment section stripping" do
    it "removes WordPress comment sections from extracted content" do
      html = <<~HTML
        <html>
          <body>
            <main>
              <article>
                <h1>Polish Pierogi Recipe</h1>
                <p>Mix flour with eggs and water to form the dough. Fill with potato and cheese mixture.</p>
                <p>Boil the pierogi until they float, then pan-fry in butter until golden.</p>
              </article>
              <div id="comments" class="comments-area">
                <h2>3 Comments</h2>
                <ol class="comment-list">
                  <li class="comment">
                    <p>Great recipe! I added some onions too.</p>
                    <a href="#respond">Reply</a>
                  </li>
                  <li class="comment">
                    <p>Can I freeze these before boiling?</p>
                    <a href="#respond">Reply</a>
                  </li>
                  <li class="comment">
                    <p>My babcia would be proud!</p>
                    <a href="#respond">Reply</a>
                  </li>
                </ol>
                <div id="respond">
                  <h3>Leave a Reply</h3>
                  <textarea></textarea>
                </div>
              </div>
            </main>
          </body>
        </html>
      HTML

      with_page(html) do |page|
        payload = FetchUtil::Extractor.new.extract(page)

        expect(payload["markdown"]).to include("Mix flour with eggs")
        expect(payload["markdown"]).to include("pan-fry in butter")
        expect(payload["markdown"]).not_to include("Great recipe")
        expect(payload["markdown"]).not_to include("babcia would be proud")
        expect(payload["markdown"]).not_to include("Leave a Reply")
      end
    end

    it "removes Disqus thread containers" do
      html = <<~HTML
        <html>
          <body>
            <main>
              <article>
                <h1>Hiking in the Alps</h1>
                <p>The best trails through the French Alps offer breathtaking views of Mont Blanc.</p>
              </article>
              <div id="disqus_thread">
                <p>Loading Disqus comments...</p>
                <a href="https://disqus.com">Powered by Disqus</a>
              </div>
            </main>
          </body>
        </html>
      HTML

      with_page(html) do |page|
        payload = FetchUtil::Extractor.new.extract(page)

        expect(payload["markdown"]).to include("best trails through the French Alps")
        expect(payload["markdown"]).not_to include("Disqus")
        expect(payload["markdown"]).not_to include("Loading")
      end
    end
  end

  describe "related article block removal" do
    it "removes related-posts sections by class" do
      html = <<~HTML
        <html>
          <body>
            <main>
              <article>
                <h1>Homemade Kiełbasa</h1>
                <p>A traditional Polish sausage recipe passed down through generations.</p>
                <p>Mix pork shoulder with garlic, marjoram, and salt. Stuff into natural casings.</p>
              </article>
              <div class="related-posts">
                <h3>Polecane</h3>
                <ul>
                  <li><a href="/pierogi">Pierogi Recipe</a><p>Classic potato and cheese pierogi.</p></li>
                  <li><a href="/bigos">Bigos Hunter's Stew</a><p>Traditional Polish hunter's stew.</p></li>
                  <li><a href="/mazurek">Easter Mazurek</a><p>A festive Polish Easter cake.</p></li>
                </ul>
              </div>
            </main>
          </body>
        </html>
      HTML

      with_page(html) do |page|
        payload = FetchUtil::Extractor.new.extract(page)

        expect(payload["markdown"]).to include("traditional Polish sausage")
        expect(payload["markdown"]).not_to include("Polecane")
        expect(payload["markdown"]).not_to include("Pierogi Recipe")
        expect(payload["markdown"]).not_to include("Hunter's Stew")
      end
    end

    it "removes utility sections with multilingual headings via heuristic" do
      html = <<~HTML
        <html>
          <body>
            <main>
              <article>
                <h1>Randonnées dans les Alpes</h1>
                <p>Découvrez les plus beaux sentiers de randonnée des Alpes françaises.</p>
              </article>
              <section>
                <h2>À lire aussi</h2>
                <ul>
                  <li><a href="/trail-1">Sentier du Mont Blanc</a></li>
                  <li><a href="/trail-2">Tour des Écrins</a></li>
                  <li><a href="/trail-3">Traversée de la Vanoise</a></li>
                </ul>
              </section>
            </main>
          </body>
        </html>
      HTML

      with_page(html) do |page|
        payload = FetchUtil::Extractor.new.extract(page)

        expect(payload["markdown"]).to include("beaux sentiers de randonnée")
        expect(payload["markdown"]).not_to include("À lire aussi")
        expect(payload["markdown"]).not_to include("Sentier du Mont Blanc")
      end
    end

    it "removes German-language related article sections" do
      html = <<~HTML
        <html>
          <body>
            <main>
              <article>
                <h1>Schwarzwald Wanderführer</h1>
                <p>Der Schwarzwald bietet wunderschöne Wanderwege durch dichte Wälder.</p>
              </article>
              <section>
                <h2>Ähnliche Beiträge</h2>
                <ul>
                  <li><a href="/path-1">Wanderweg eins</a></li>
                  <li><a href="/path-2">Wanderweg zwei</a></li>
                  <li><a href="/path-3">Wanderweg drei</a></li>
                </ul>
              </section>
            </main>
          </body>
        </html>
      HTML

      with_page(html) do |page|
        payload = FetchUtil::Extractor.new.extract(page)

        expect(payload["markdown"]).to include("wunderschöne Wanderwege")
        expect(payload["markdown"]).not_to include("Ähnliche Beiträge")
      end
    end
  end

  describe "title whitespace normalization" do
    it "strips carriage return and newline characters from the title" do
      html = <<~HTML
        <html>
          <head><title>The Mediterranean Dish\r\n</title></head>
          <body>
            <main>
              <article>
                <h1>Spanish Paella Recipe</h1>
                <p>A delicious and authentic Spanish paella with saffron rice, chicken, and seafood.</p>
              </article>
            </main>
          </body>
        </html>
      HTML

      with_page(html) do |page|
        payload = FetchUtil::Extractor.new.extract(page)

        expect(payload["title"]).not_to match(/[\r\n]/)
        expect(payload["title"]).to eq("The Mediterranean Dish")
      end
    end
  end

  describe "language mismatch detection" do
    it "flags content that does not match the URL language hint" do
      html = <<~HTML
        <html lang="en">
          <head><title>Draw and Tell Stories for Kids</title></head>
          <body>
            <main>
              <article>
                <h1>Draw and Tell Stories</h1>
                <p>These creative drawing activities help children develop their storytelling skills
                   through fun and interactive exercises. Each story begins with a simple drawing
                   that children can expand upon with their imagination and creativity. The activities
                   are designed for young learners who enjoy combining visual art with narrative elements.
                   Teachers and parents can use these stories as educational tools in classrooms and at home.</p>
              </article>
            </main>
          </body>
        </html>
      HTML

      with_url_page("https://www.outdooractive.com/de/wanderungen/5143", html) do |page|
        payload = FetchUtil::Extractor.new.extract(page)

        expect(payload["warnings"]).to include("url_content_mismatch")
        expect(payload["suspect"]).to be true
      end
    end

    it "does not flag content that matches the URL language hint" do
      html = <<~HTML
        <html lang="de">
          <head><title>Wanderungen in den Alpen</title></head>
          <body>
            <main>
              <article>
                <h1>Wanderungen in den Alpen</h1>
                <p>Die schönsten Wanderwege durch die Alpen bieten atemberaubende Ausblicke
                   auf die Berglandschaft. Wanderer können zwischen verschiedenen Schwierigkeitsgraden
                   wählen und die Natur in vollen Zügen genießen. Die Alpenregion ist bekannt für
                   ihre vielfältigen Wandermöglichkeiten und die hervorragende Infrastruktur mit
                   gut markierten Wegen und gemütlichen Berghütten.</p>
              </article>
            </main>
          </body>
        </html>
      HTML

      with_url_page("https://www.outdooractive.com/de/wanderungen/5143", html) do |page|
        payload = FetchUtil::Extractor.new.extract(page)

        expect(payload["warnings"]).not_to include("url_content_mismatch")
      end
    end

    it "does not flag Wikipedia-style article slugs that only differ by diacritics" do
      cases = [
        {
          url: "https://hu.wikipedia.org/wiki/Magyarorsz%C3%A1g",
          lang: "hu",
          title: "Magyarország",
          body: [
            "<table><tr><th>Főváros</th><td>Budapest</td></tr><tr><th>Nyelv</th><td>magyar</td></tr></table>",
            "<p>Magyarország Közép-Európában található ország, amelyet a Duna és a Tisza folyó is meghatároz.</p>",
            "<p>Az ország története, kultúrája és földrajza szorosan kapcsolódik a szomszédos régiók fejlődéséhez és a Kárpát-medence hagyományaihoz.</p>"
          ].join("\n")
        },
        {
          url: "https://cs.wikipedia.org/wiki/%C4%8Cesko",
          lang: "cs",
          title: "Česko",
          body: [
            "<table><tr><th>Hlavní město</th><td>Praha</td></tr><tr><th>Jazyk</th><td>čeština</td></tr></table>",
            "<p>Česko leží ve střední Evropě a jeho krajina zahrnuje města, řeky i horské oblasti.</p>",
            "<p>Historie státu je spojena s kulturní tradicí, průmyslem a dlouhodobým evropským vývojem.</p>"
          ].join("\n")
        },
        {
          url: "https://hr.wikipedia.org/wiki/Hrvatska",
          lang: "hr",
          title: "Hrvatska",
          body: [
            "<table><tr><th>Glavni grad</th><td>Zagreb</td></tr><tr><th>Jezik</th><td>hrvatski</td></tr></table>",
            "<p>Hrvatska je država u jugoistočnoj Europi, a obala Jadranskog mora važan je dio njezina identiteta.</p>",
            "<p>Povijest, kultura i gospodarstvo zemlje povezani su s regijom, trgovinom i dugotrajnom mediteranskom tradicijom.</p>"
          ].join("\n")
        }
      ]

      cases.each do |test_case|
        html = <<~HTML
          <html lang="#{test_case[:lang]}">
            <head><title>#{test_case[:title]}</title></head>
            <body>
              <main>
                <article>
                  <h1>#{test_case[:title]}</h1>
                  #{test_case[:body]}
                </article>
              </main>
            </body>
          </html>
        HTML

        with_url_page(test_case[:url], html) do |page|
          payload = FetchUtil::Extractor.new.extract(page)

          expect(payload["contentType"]).to eq("article")
          expect(payload["warnings"]).not_to include("url_content_mismatch")
        end
      end
    end

    it "does not flag transliterated article slugs on localized Latin-script news URLs" do
      url = "https://www.vijesti.me/mundijal-2026/vijesti/816881/" \
            "kompletirani-parovi-cetvrtfinala-mundijala-u-srijedu-je-konacno-slobodan-dan-a-onda-krece-rasplet"
      html = <<~HTML
        <html lang="sr">
          <head><title>Kompletirani parovi četvrtfinala Mundijala: U srijedu je konačno slobodan dan, a onda kreće rasplet</title></head>
          <body>
            <main>
              <article>
                <h1>Kompletirani parovi četvrtfinala Mundijala: U srijedu je konačno slobodan dan, a onda kreće rasplet</h1>
                <p>Završeni su mečevi osmine finala na Svjetskom prvenstvu u fudbalu, poznati su svi parovi četvrtfinala.</p>
                <p>U četvrtfinalu se sastaju: Francuska - Maroko, Španija - Belgija, Norveška - Engleska i Argentina - Švajcarska.</p>
                <p>Na Mundijalu je u srijedu, konačno, slobodan dan, a u četvrtak počinje rasplet.</p>
              </article>
            </main>
          </body>
        </html>
      HTML

      with_url_page(url, html) do |page|
        payload = FetchUtil::Extractor.new.extract(page)

        expect(payload["markdown"]).to include("Kompletirani parovi četvrtfinala Mundijala")
        expect(payload["warnings"]).not_to include("url_content_mismatch")
      end
    end

    it "does not flag Polish legal text that matches the page language" do
      html = <<~HTML
        <html lang="pl">
          <head><title>II K 84/16 Szczegóły orzeczenia</title></head>
          <body>
            <main>
              <article>
                <h1>II K 84/16 Szczegóły orzeczenia</h1>
                <p>Sąd Rejonowy po rozpoznaniu sprawy w dniu dwudziestego maja wskazał, że oskarżony działał w warunkach opisanych w akcie oskarżenia.</p>
                <p>W ocenie sądu materiał dowodowy został zgromadzony prawidłowo, a zeznania świadków oraz dokumenty z akt sprawy są spójne.</p>
                <p>Ponadto sąd zważył, że kara powinna uwzględniać stopień winy, cele zapobiegawcze oraz okoliczności dotyczące zachowania po zdarzeniu.</p>
              </article>
            </main>
          </body>
        </html>
      HTML

      with_url_page("https://www.saos.org.pl/judgments/227221", html) do |page|
        payload = FetchUtil::Extractor.new.extract(page)

        expect(payload["markdown"]).to include("Sąd Rejonowy po rozpoznaniu sprawy")
        expect(payload["warnings"]).not_to include("url_content_mismatch")
      end
    end

    it "still flags English content on a Polish-language URL" do
      html = <<~HTML
        <html lang="pl">
          <head><title>Portal information</title></head>
          <body>
            <main>
              <article>
                <h1>Portal information</h1>
                <p>This article describes a public information portal with account settings, service notices, and general navigation for visitors. The page explains how readers can browse categories, manage saved searches, and review support resources without presenting Polish-language article content.</p>
                <p>Editors update the homepage throughout the week with summaries, links, and background material for international readers.</p>
              </article>
            </main>
          </body>
        </html>
      HTML

      with_url_page("https://www.example.com/pl/portal/informacje", html) do |page|
        payload = FetchUtil::Extractor.new.extract(page)

        expect(payload["warnings"]).to include("url_content_mismatch")
      end
    end
  end

  describe "opaque article urls with strong metadata" do
    it "keeps article extraction instead of downgrading to list mode on likely-list paths" do
      html = <<~HTML
        <html lang="ko">
          <head>
            <title>연합뉴스 기사</title>
            <meta property="og:title" content="연합뉴스 기사">
            <meta property="og:description" content="정책 변화가 산업 현장에 미치는 영향을 짚은 기사다.">
            <meta property="article:published_time" content="2026-03-26T08:00:00+09:00">
            <meta property="article:author" content="김지연">
          </head>
          <body>
            <main>
              <article class="story-summary">
                <h1>연합뉴스 기사</h1>
                <p>정부 발표 이후 관련 업계에서는 비용 구조와 채용 계획을 다시 검토하고 있으며, 부품 조달 시기와 설비 투자 순서를 함께 조정하고 있다.</p>
                <p>현장 관계자들은 단기 충격보다 공급망 재편과 투자 일정 조정이 더 큰 변수라고 보며, 수출 기업일수록 환율과 물류비를 동시에 반영한 대응책이 필요하다고 말한다.</p>
                <p>전문가들은 상반기 실적보다 하반기 고용 계획이 더 큰 영향을 받을 수 있다고 분석하면서, 지역별 지원 정책이 기업 의사결정의 속도를 좌우할 가능성이 높다고 설명했다.</p>
                <p>업계 단체는 연구개발과 설비 투자에 대한 세제 지원이 유지되지 않으면 중견기업부터 신규 채용을 늦출 가능성이 높다고 덧붙였다.</p>
                <p>현장 인터뷰에 응한 기업 관계자들은 원재료 가격과 물류 부담, 인력 확보 문제까지 동시에 겹치며 사업 계획을 수정하는 사례가 늘고 있다고 설명했다.</p>
                <p>정부는 조만간 후속 대책을 발표할 예정이지만, 기업들은 발표 시점보다 실제 집행 속도와 지역별 세부 지침을 더 중요하게 보고 있다.</p>
              </article>
              <section class="hot-news">
                <h2>핫뉴스</h2>
                <ul>
                  <li><a href="/view/AKR20260326000451086">관련 영상 1</a></li>
                  <li><a href="/view/AKR20260326000451087">관련 영상 2</a></li>
                  <li><a href="/view/AKR20260326000451088">관련 영상 3</a></li>
                  <li><a href="/view/AKR20260326000451089">관련 영상 4</a></li>
                  <li><a href="/view/AKR20260326000451090">관련 영상 5</a></li>
                </ul>
              </section>
              <section class="ranking-news">
                <h2>랭킹뉴스</h2>
                <article><a href="/view/AKR20260326000451091">랭킹 기사 1</a></article>
                <article><a href="/view/AKR20260326000451092">랭킹 기사 2</a></article>
                <article><a href="/view/AKR20260326000451093">랭킹 기사 3</a></article>
                <article><a href="/view/AKR20260326000451094">랭킹 기사 4</a></article>
              </section>
            </main>
          </body>
        </html>
      HTML

      with_url_page("https://www.yna.co.kr/view/AKR20260326000451085", html) do |page|
        payload = FetchUtil::Extractor.new.extract(page)

        expect(payload["contentType"]).to eq("article")
        expect(payload["markdown"]).to include("정부 발표 이후 관련 업계에서는 비용 구조")
        expect(payload["markdown"]).not_to include("- [관련 영상 1]")
      end
    end
  end

  describe "fallback over weak readability output" do
    it "prefers substantial fallback article content when readability collapses to an ad block" do
      html = <<~HTML
        <html lang="sr">
          <head>
            <title>Analiza kampanje</title>
            <meta property="og:title" content="Analiza kampanje">
            <meta property="og:description" content="Detaljna analiza lokalne kampanje i ponašanja birača u završnici izbornog ciklusa.">
          </head>
          <body>
            <article class="promo-shell">
              <div id="billboard_banner">
                <p>Oglas</p>
                <p>!!!!</p>
              </div>
            </article>
            <div id="page-content" class="page-content">
              <div class="article-meta">
                <h1>Analiza kampanje</h1>
                <p>Autor: Redakcija</p>
              </div>
              <div class="article-copy">
                <p>Lokalni izbori pokazuju da su pitanja komunalne infrastrukture i cena života preuzela primat nad nacionalnim temama.</p>
                <p>Istraživači navode da su birači znatno više reagovali na direktan kontakt sa kandidatima nego na centralizovane medijske poruke.</p>
                <p>U završnici kampanje stranke su pojačale terenske aktivnosti, dok su nezavisne liste bolje prolazile u urbanim sredinama.</p>
                <p>Analitičari procenjuju da će upravo razlike između gradskih i prigradskih birača odrediti konačan odnos snaga.</p>
              </div>
            </div>
          </body>
        </html>
      HTML

      with_url_page("https://n1info.rs/vesti/analiza-kampanje/", html) do |page|
        payload = FetchUtil::Extractor.new.extract(page)

        expect(payload["contentType"]).to eq("article")
        expect(payload["markdown"]).to include("Lokalni izbori pokazuju da su pitanja komunalne infrastrukture")
        expect(payload["markdown"]).not_to include("Oglas\n\n!!!!")
      end
    end
  end
end
