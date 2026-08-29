# frozen_string_literal: true

RSpec.describe 'FetchUtil extractor integration' do
  include_context 'extractor integration helpers'

  it "extracts financial times homepages into compact lead-story lists" do
    longest_title = 'F' * 180
    overlong_title = 'G' * 181
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
              <a href="https://www.ft.com/content/a1">
                <h2>Opinion Content. Harbor repairs continue after a late coastal alert</h2>
                <span>Subscriber analysis</span>
              </a>
              <p>Officials say the response now focuses on restoring local services.</p>
            </section>
            <section class="story-group-slice">
              <a href="https://www.ft.com/content/a2">Regional freight schedules tighten as vessels reach port</a>
              <p>Logistics teams report a narrow window for new arrivals.</p>
            </section>
            <section class="story-group-slice">
              <a href="https://www.ft.com/content/a3">A separate freight outlook keeps its distinct destination</a>
              <p>A separate report keeps its distinct destination.</p>
            </section>
            <section class="story-group-slice">
              <a href="https://www.ft.com/content/a4">#{longest_title}</a>
              <p>The accepted title is exactly 180 characters long.</p>
            </section>
            <a href="https://www.ft.com/content/a1">Duplicate headline must not replace the first</a>
            <a href="https://www.ft.com/content/a5">#{overlong_title}</a>
            <a href="https://www.ft.com/content/a6">More Technology</a>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://www.ft.com/", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)
      markdown = payload["markdown"]

      expect(payload["contentType"]).to eq("list")
      expect(payload).to include("title" => "Home - Financial Times", "siteName" => "Financial Times")
      expect(markdown).to include("- [Harbor repairs continue after a late coastal alert Subscriber analysis](https://www.ft.com/content/a1)")
      expect(markdown).to include("- [Regional freight schedules tighten as vessels reach port](https://www.ft.com/content/a2)")
      expect(markdown).to include("- [A separate freight outlook keeps its distinct destination](https://www.ft.com/content/a3)")
      expect(markdown).to include("- [#{longest_title}](https://www.ft.com/content/a4)")
      expect(markdown).not_to include("Duplicate headline", "https://www.ft.com/content/a5", "https://www.ft.com/content/a6")
      expect(markdown.index("/content/a1")).to be < markdown.index("/content/a2")
      expect(markdown.index("/content/a2")).to be < markdown.index("/content/a3")
      expect(markdown.index("/content/a3")).to be < markdown.index("/content/a4")
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

  it "preserves booking homepage summaries without enough links for a list" do
    html = <<~HTML
      <html>
        <head><title>Booking.com</title></head>
        <body>
          <main>
            <h1>Find your next stay</h1>
            <h2>Seasonal city breaks</h2>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://www.booking.com/", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["contentType"]).to eq("article")
      expect(payload["title"]).to eq("Find your next stay")
      expect(payload["markdown"]).to include("- Seasonal city breaks")
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
    longest_title = 'B' * 220
    overlong_title = 'C' * 221
    html = <<~HTML
      <html>
        <head>
          <title>Bloomberg Europe</title>
          <meta name="description" content="The latest business and markets news from Bloomberg.">
        </head>
        <body>
          <main>
            <section>
              <a href="https://www.bloomberg.com/news/articles/2026-03-22/market-outlook">AP Photo Market Outlook Improves as Regional Trade Routes Reopen</a>
            </section>
            <section>
              <a href="https://www.bloomberg.com/opinion/articles/2026-03-22/shared-outlook-one">Opinion A Measured Bloomberg Outlook for Regional Markets</a>
            </section>
            <section>
              <a href="https://www.bloomberg.com/features/2026-shared-outlook-two/">A Separate Bloomberg Feature Tracks Changing Trade Routes</a>
            </section>
            <section>
              <a href="https://www.bloomberg.com/graphics/2026-boundary-title/">#{longest_title}</a>
            </section>
            <a href="https://www.bloomberg.com/news/articles/2026-03-22/market-outlook">Duplicate Bloomberg headline must not replace the first</a>
            <a href="https://www.bloomberg.com/news/articles/2026-03-22/overlong-title">#{overlong_title}</a>
            <a href="https://www.bloomberg.com/news/articles/2026-03-22/businessweek-label">Bloomberg Businessweek</a>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://www.bloomberg.com/europe", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)
      markdown = payload["markdown"]

      expect(payload["contentType"]).to eq("list")
      expect(payload).to include("title" => "Bloomberg Europe", "siteName" => "www.bloomberg.com")
      expect(markdown).to include("- [Market Outlook Improves as Regional Trade Routes Reopen](https://www.bloomberg.com/news/articles/2026-03-22/market-outlook)")
      expect(markdown).to include("- [A Measured Bloomberg Outlook for Regional Markets](https://www.bloomberg.com/opinion/articles/2026-03-22/shared-outlook-one)")
      expect(markdown).to include("- [A Separate Bloomberg Feature Tracks Changing Trade Routes](https://www.bloomberg.com/features/2026-shared-outlook-two/)")
      expect(markdown).to include("- [#{longest_title}](https://www.bloomberg.com/graphics/2026-boundary-title/)")
      expect(markdown).not_to include("Duplicate Bloomberg", "overlong-title", "businessweek-label")
      expect(markdown.index("market-outlook")).to be < markdown.index("shared-outlook-one")
      expect(markdown.index("shared-outlook-one")).to be < markdown.index("shared-outlook-two")
      expect(markdown.index("shared-outlook-two")).to be < markdown.index("boundary-title")
    end
  end

  it "extracts economist homepages into compact story bullets" do
    longest_title = 'E' * 180
    overlong_title = 'H' * 181
    html = <<~HTML
      <html>
        <head>
          <title>The Economist | Go beyond breaking news</title>
          <meta name="description" content="Independent journalism from The Economist.">
        </head>
        <body>
          <main>
            <article>
              <a href="https://www.economist.com/the-americas/2026/03/19/first-outlook">
                <h2>A measured outlook for regional economic recovery</h2>
                <span>Subscriber label</span>
              </a>
            </article>
            <article>
              <a href="https://www.economist.com/leaders/2026/03/19/shared-outlook-one">A durable Economist outlook for international trade</a>
            </article>
            <article>
              <a href="https://www.economist.com/interactive/1843/2026/03/19/shared-outlook-two">An interactive Economist report on changing demographics</a>
            </article>
            <article>
              <a href="https://www.economist.com/science-and-technology/2026/03/18/boundary-title">#{longest_title}</a>
            </article>
            <a href="https://www.economist.com/the-americas/2026/03/19/first-outlook">Duplicate Economist headline must not replace the first</a>
            <a href="https://www.economist.com/leaders/2026/03/19/overlong-title">#{overlong_title}</a>
            <a href="https://www.economist.com/leaders/2026/03/19/navigation-label">Business &amp; Economics</a>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://www.economist.com/", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)
      markdown = payload["markdown"]

      expect(payload["contentType"]).to eq("list")
      expect(payload).to include("title" => "The Economist | Go beyond breaking news", "siteName" => "www.economist.com")
      expect(markdown).to include("- [A measured outlook for regional economic recovery](https://www.economist.com/the-americas/2026/03/19/first-outlook)")
      expect(markdown).to include("- [A durable Economist outlook for international trade](https://www.economist.com/leaders/2026/03/19/shared-outlook-one)")
      expect(markdown).to include("- [An interactive Economist report on changing demographics](https://www.economist.com/interactive/1843/2026/03/19/shared-outlook-two)")
      expect(markdown).to include("- [#{longest_title}](https://www.economist.com/science-and-technology/2026/03/18/boundary-title)")
      expect(markdown).not_to include("Duplicate Economist", "overlong-title", "navigation-label")
      expect(markdown.index("first-outlook")).to be < markdown.index("shared-outlook-one")
      expect(markdown.index("shared-outlook-one")).to be < markdown.index("shared-outlook-two")
      expect(markdown.index("shared-outlook-two")).to be < markdown.index("boundary-title")
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
