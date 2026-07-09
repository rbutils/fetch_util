# frozen_string_literal: true

RSpec.describe 'FetchUtil extractor integration' do
  include_context 'extractor integration helpers'

  it "extracts financial times homepages into compact lead-story lists" do
    html = <<~HTML
      <html>
        <head>
          <title>Home - Financial Times</title>
          <meta property="og:site_name" content="Financial Times">
          <meta name="description" content="Brief reports, context and commentary from the daily desk.">
        </head>
        <body>
          <main>
            <section class="story-group-slice">
              <a href="https://www.ft.com/content/a1">Harbor repairs continue after a late coastal alert</a>
              <p>Officials say the response now focuses on restoring local services.</p>
            </section>
            <section class="story-group-slice">
              <a href="https://www.ft.com/content/a2">Regional freight schedules tighten as vessels reach port</a>
              <p>Logistics teams report a narrow window for new arrivals.</p>
            </section>
            <section class="story-group-slice">
              <a href="https://www.ft.com/content/a3">Why a crowded timetable could slow the data boom</a>
              <p>Commentary section.</p>
            </section>
            <section class="story-group-slice">
              <a href="https://www.ft.com/content/a4">Vehicle makers revise their plans for quieter roads</a>
              <p>Customers continue to compare several power options.</p>
            </section>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://www.ft.com/", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["contentType"]).to eq("list")
      expect(payload["markdown"]).to include("- [Harbor repairs continue after a late coastal alert](https://www.ft.com/content/a1)")
      expect(payload["markdown"]).to include("- [Vehicle makers revise their plans for quieter roads](https://www.ft.com/content/a4)")
    end
  end

  it "extracts booking homepages into compact highlights and links" do
    html = <<~HTML
      <html>
        <head>
          <title>Booking.com | Official site | The best hotels, flights, car rentals & accommodations</title>
          <meta name="description" content="Find hotels, apartments, resorts, villas, hostels and B&amp;Bs.">
        </head>
        <body>
          <main>
             <h1>Plan a stay for any season</h1>
             <h2>Popular destinations</h2>
            <h2>Browse by property type</h2>
            <a href="https://www.booking.com/searchresults.html?dest_id=20079110&amp;dest_type=city">Las Vegas</a>
            <a href="https://www.booking.com/searchresults.html?dest_id=20088325&amp;dest_type=city">New York</a>
            <a href="https://www.booking.com/searchresults.html?dest_id=-246227&amp;dest_type=city">Tokyo</a>
            <a href="https://www.booking.com/hotel/index.en-us.html">Hotels</a>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://www.booking.com/", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["markdown"]).to include("# Plan a stay for any season")
      expect(payload["markdown"]).to include("- Popular destinations")
      expect(payload["markdown"]).to include("- [Las Vegas](https://www.booking.com/searchresults.html?dest_id=20079110&dest_type=city)")
      expect(payload["contentType"]).to eq("list")
      expect(payload["warnings"]).not_to include("not_found_interstitial")
    end
  end

  it "extracts glassdoor homepages into compact summaries" do
    html = <<~HTML
      <html>
        <head>
          <title>Glassdoor | Job Search &amp; Career Community</title>
          <meta name="description" content="Find jobs, salary tools, company reviews, and interview questions on Glassdoor.">
        </head>
        <body>
          <main>
            <h1>You deserve a job that loves you back</h1>
            <h2>One login to help you get hired</h2>
            <p>Streamline your research and get better job matches across Glassdoor and Indeed with one login.</p>
            <h2>Get ahead with Glassdoor</h2>
            <p>Join your work community</p>
            <p>Find and apply to jobs</p>
            <p>Search company reviews</p>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://www.glassdoor.com/index.htm", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["markdown"]).to include("# You deserve a job that loves you back")
      expect(payload["markdown"]).to include("Streamline your research and get better job matches")
      expect(payload["markdown"]).to include("- Join your work community")
    end
  end

  it "extracts bloomberg regional homepages into compact story bullets" do
    html = <<~HTML
      <html>
        <head>
          <title>Bloomberg Europe</title>
          <meta name="description" content="The latest business and markets news from Bloomberg.">
        </head>
        <body>
          <main>
            <section>
              <a href="https://www.bloomberg.com/news/articles/2026-03-22/iran-warns-trump-after-he-gives-two-day-ultimatum-to-open-hormuz">Trump And Iran Trade War Threats With Hormuz Crisis Building</a>
            </section>
            <section>
              <a href="https://www.bloomberg.com/opinion/articles/2026-03-22/iran-war-trump-seizing-kharg-island-is-a-bad-idea-for-oil-reasons-too-mn1pgo70">Opinion A Kharg Island Invasion Won’t Solve Trump’s Oil Problem</a>
            </section>
            <section>
              <a href="https://www.bloomberg.com/features/2026-prediction-markets-polymarket-kalshi/">How Prediction Markets Are Gamifying Truth</a>
            </section>
            <section>
              <a href="https://www.bloomberg.com/graphics/2026-paris-transformed-hidalgo/">Welcome to Paris, the City That Said No to Cars</a>
            </section>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://www.bloomberg.com/europe", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["contentType"]).to eq("list")
      expect(payload["markdown"]).to include("- [Trump And Iran Trade War Threats With Hormuz Crisis Building](https://www.bloomberg.com/news/articles/2026-03-22/iran-warns-trump-after-he-gives-two-day-ultimatum-to-open-hormuz)")
      expect(payload["markdown"]).to include("- [A Kharg Island Invasion Won’t Solve Trump’s Oil Problem](https://www.bloomberg.com/opinion/articles/2026-03-22/iran-war-trump-seizing-kharg-island-is-a-bad-idea-for-oil-reasons-too-mn1pgo70)")
    end
  end

  it "extracts economist homepages into compact story bullets" do
    html = <<~HTML
      <html>
        <head>
          <title>The Economist | Go beyond breaking news</title>
          <meta name="description" content="Independent journalism from The Economist.">
        </head>
        <body>
          <main>
            <a href="https://www.economist.com/the-americas/2026/03/19/cubas-broken-economy-leaves-it-at-donald-trumps-mercy">Cuba’s broken economy leaves it at Donald Trump’s mercy</a>
            <a href="https://www.economist.com/leaders/2026/03/19/lebanons-leaders-must-take-on-hizbullah">Lebanon’s leaders must take on Hizbullah</a>
            <a href="https://www.economist.com/interactive/1843/2026/03/19/the-battle-for-the-soul-of-the-church-of-england">The battle for the soul of the Church of England</a>
            <a href="https://www.economist.com/science-and-technology/2026/03/18/china-is-a-serious-contender-in-the-race-for-fusion-energy">China is a serious contender in the race for fusion energy</a>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://www.economist.com/", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["contentType"]).to eq("list")
      expect(payload["markdown"]).to include("- [Cuba’s broken economy leaves it at Donald Trump’s mercy](https://www.economist.com/the-americas/2026/03/19/cubas-broken-economy-leaves-it-at-donald-trumps-mercy)")
      expect(payload["markdown"]).to include("- [China is a serious contender in the race for fusion energy](https://www.economist.com/science-and-technology/2026/03/18/china-is-a-serious-contender-in-the-race-for-fusion-energy)")
    end
  end

  it "extracts wykop homepages as social feeds without privacy chrome" do
    html = <<~HTML
      <html>
        <head>
          <title>Wykop.pl - wiadomości, aktualności, ciekawostki, informacje</title>
          <meta property="og:site_name" content="Wykop.pl">
        </head>
        <body>
          <section class="open-left-panel default-layout prerender">
            <section class="home-page" layout="default-layout">
              <nav class="cmp"><ul><li>Ustawienia prywatności</li></ul></nav>
              <div id="modals-container">
                <p>We value your privacy</p>
                <button>Manage choices</button>
              </div>
              <div id="privacy-btn-container">Polityka prywatności i cookies</div>
              <div class="extra-container">Nie widzisz nawet do 30% treści dostępnych w serwisie</div>
              <section class="stream home-stream from-pagination-home-stream">
                <section class="link-block stream-home" id="link-1">
                  <h2 class="heading"><a href="/link/1/ruby-3-5-przyspiesza-kompilacje">Ruby 3.5 przyspiesza kompilacje</a></h2>
                  <p>Nowe optymalizacje skracają czas budowania dużych aplikacji.</p>
                  <a class="comment-counter" href="/link/1/ruby-3-5-przyspiesza-kompilacje#comments">45 komentarzy</a>
                </section>
                <section class="link-block stream-home" id="link-2">
                  <h2 class="heading"><a href="/link/2/fetch-util-lepiej-czysci-markdown">Fetch Util lepiej czyści markdown</a></h2>
                  <p>Autor opisał nowe heurystyki dla stron z oknami zgód.</p>
                  <a class="comment-counter" href="/link/2/fetch-util-lepiej-czysci-markdown#comments">12 komentarzy</a>
                </section>
                <section class="link-block stream-home" id="link-3">
                  <h2 class="heading"><a href="/link/3/przegladarka-usuwa-dialogi-cookies">Przeglądarka usuwa dialogi cookies</a></h2>
                  <p>Zmiana skraca stabilizację i odsłania prawdziwą treść.</p>
                  <a class="comment-counter" href="/link/3/przegladarka-usuwa-dialogi-cookies#comments">8 komentarzy</a>
                </section>
                <section class="link-block stream-home" id="link-4">
                  <h2 class="heading"><a href="/link/4/wykop-prerender-wciaz-dziala">Wykop prerender wciąż działa</a></h2>
                  <p>Strona główna zachowuje komplet linków nawet bez hydracji.</p>
                  <a class="comment-counter" href="/link/4/wykop-prerender-wciaz-dziala#comments">6 komentarzy</a>
                </section>
              </section>
              <section class="register">
                <a href="/zaloz-konto">Załóż konto</a>
                <a href="/login">Zaloguj się</a>
              </section>
            </section>
          </section>
        </body>
      </html>
    HTML

    with_url_page("https://wykop.pl/", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload).to include("contentType" => "social", "socialKind" => "feed", "platform" => "Wykop")
      expect(payload["markdown"]).to include("- [Ruby 3.5 przyspiesza kompilacje](https://wykop.pl/link/1/ruby-3-5-przyspiesza-kompilacje)")
      expect(payload["markdown"]).to include("45 komentarzy")
      expect(payload["markdown"]).not_to include("We value your privacy")
      expect(payload["markdown"]).not_to include("Ustawienia prywatności")
      expect(payload["markdown"]).not_to include("Załóż konto")
    end
  end
end
