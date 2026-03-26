# frozen_string_literal: true

RSpec.describe 'FetchUtil extractor integration' do
  include_context 'extractor integration helpers'

  it "extracts financial times homepages into compact lead-story lists" do
    html = <<~HTML
      <html>
        <head>
          <title>Home - Financial Times</title>
          <meta property="og:site_name" content="Financial Times">
          <meta name="description" content="News, analysis and opinion from the Financial Times.">
        </head>
        <body>
          <main>
            <section class="story-group-slice">
              <a href="https://www.ft.com/content/a1">Iran threatens vital infrastructure in response to ultimatum</a>
              <p>Tehran's military says its strategy has shifted from defensive to offensive.</p>
            </section>
            <section class="story-group-slice">
              <a href="https://www.ft.com/content/a2">World faces gas supply cliff edge as Gulf shipments approach ports</a>
              <p>Energy traders warn of mounting supply risk.</p>
            </section>
            <section class="story-group-slice">
              <a href="https://www.ft.com/content/a3">How the Iran war could derail the AI boom</a>
              <p>Opinion content.</p>
            </section>
            <section class="story-group-slice">
              <a href="https://www.ft.com/content/a4">Global carmakers retreat from electric vehicle plans</a>
              <p>Demand for petrol engines persists.</p>
            </section>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://www.ft.com/", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["contentType"]).to eq("list")
      expect(payload["markdown"]).to include("- [Iran threatens vital infrastructure in response to ultimatum](https://www.ft.com/content/a1)")
      expect(payload["markdown"]).to include("- [Global carmakers retreat from electric vehicle plans](https://www.ft.com/content/a4)")
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
            <h1>Find deals for any season</h1>
            <h2>Trending destinations</h2>
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

      expect(payload["markdown"]).to include("# Find deals for any season")
      expect(payload["markdown"]).to include("- Trending destinations")
      expect(payload["markdown"]).to include("- [Las Vegas](https://www.booking.com/searchresults.html?dest_id=20079110&dest_type=city)")
      expect(payload["contentType"]).to eq("list")
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

  it "extracts wykop homepages into compact link bullets without privacy chrome" do
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

      expect(payload["contentType"]).to eq("list")
      expect(payload["markdown"]).to include("- [Ruby 3.5 przyspiesza kompilacje](https://wykop.pl/link/1/ruby-3-5-przyspiesza-kompilacje)")
      expect(payload["markdown"]).to include("45 komentarzy")
      expect(payload["markdown"]).not_to include("We value your privacy")
      expect(payload["markdown"]).not_to include("Ustawienia prywatności")
      expect(payload["markdown"]).not_to include("Załóż konto")
    end
  end

  it "extracts large headline-rich homepages into list mode even when card counts are low" do
    utility_links = (1..90).map { |i| %(<a href="/utility/#{i}">Menu #{i}</a>) }.join
    headline_blocks = (1..18).map do |i|
      <<~HTML
        <div class="promo-block">
          <h2><a href="/zpravy/domaci/clanek-#{i}">Hlavní zpráva #{i} o domácím dění a ekonomice</a></h2>
          <p>Souhrn hlavní zprávy #{i} s několika větami vysvětlujícími širší kontext dne.</p>
        </div>
      HTML
    end.join

    html = <<~HTML
      <html>
        <head>
          <title>iDNES.cz</title>
          <meta name="description" content="Zpravodajský portál s hlavními domácími i zahraničními zprávami.">
        </head>
        <body>
          <section class="consent-layer" style="position:fixed; inset:0; background:#fff; z-index:10">
            <p>Pro pokračování vyberte, jakou formou vám máme zobrazovat obsah.</p>
            <p>Než se rozhodnete, využíváme pouze technické cookies.</p>
            <button>Souhlasím</button>
            <button>Pokračovat</button>
          </section>
          <header>
            #{utility_links}
          </header>
          <main>
            <h1>Zprávy</h1>
            #{headline_blocks}
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://www.idnes.cz/", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["contentType"]).to eq("list")
      expect(payload["markdown"]).to include("- [Hlavní zpráva 1 o domácím dění a ekonomice](https://www.idnes.cz/zpravy/domaci/clanek-1)")
      expect(payload["markdown"]).to include("- [Hlavní zpráva 18 o domácím dění a ekonomice](https://www.idnes.cz/zpravy/domaci/clanek-18)")
      expect(payload["markdown"]).not_to include("Menu 1")
      expect(payload["markdown"]).not_to include("Pro pokračování vyberte")
    end
  end

  it "does not treat substantive corporate pages as region selectors when real content is present" do
    html = <<~HTML
      <html>
        <head>
          <title>Construction: design and construction of public works - Ferrovial</title>
          <meta name="description" content="Delivering complex infrastructure projects that connect communities.">
        </head>
        <body>
          <div class="country-switcher" style="display:none">
            <p>Select your country</p>
            <button>Global</button>
          </div>
          <main>
            <h1>Delivering Complex Infrastructure with Confidence</h1>
            <p>Delivering complex infrastructure projects that connect communities, drive economic growth, and create lasting value for generations.</p>
            <section>
              <h2>Construction at Every Scale</h2>
              <p>We focus on civil engineering, building and industrial construction in the infrastructure space.</p>
              <a href="/en/business/projects/new-terminal-one-jfk-international-airport/">New Terminal One</a>
              <a href="/en/business/projects/thames-tideway-tunnel-central-section/">Thames Tideway Tunnel</a>
              <a href="/en/business/projects/farringdon-project-crossrail/">Farringdon Station</a>
            </section>
          </main>
        </body>
      </html>
    HTML

    with_url_page('https://www.ferrovial.com/en/business-lines/construction/', html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload['markdown']).to include('Delivering Complex Infrastructure with Confidence')
      expect(payload['markdown']).to include('Construction at Every Scale')
      expect(payload['warnings']).not_to include('regional_selector_interstitial')
    end
  end

  it "does not collapse substantive reference pages into browser-support interstitials" do
    html = <<~HTML
      <html>
        <head>
          <title>eCFR :: Title 21 of the CFR -- Food and Drugs</title>
        </head>
        <body>
          <div class="browser-support" style="display:none">
            <p>Your browser is not supported. For the best experience, use any of these supported browsers.</p>
          </div>
          <main>
            <h1>Title 21</h1>
            <p>Displaying title 21, up to date as of 3/24/2026.</p>
            <section>
              <h2>Chapter I Food and Drug Administration</h2>
              <a href="/current/title-21/chapter-I/subchapter-A">Subchapter A General</a>
              <a href="/current/title-21/chapter-I/subchapter-B">Subchapter B Food for Human Consumption</a>
              <a href="/current/title-21/chapter-I/subchapter-C">Subchapter C Drugs: General</a>
            </section>
          </main>
        </body>
      </html>
    HTML

    with_url_page('https://www.ecfr.gov/current/title-21', html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload['markdown']).to include('Title 21')
      expect(payload['markdown']).to include('Chapter I Food and Drug Administration')
      expect(payload['warnings']).not_to include('browser_support_interstitial')
    end
  end

  it "falls back to raw headline links when cleaned homepage extraction would be nearly empty" do
    utility_links = %w[Assinaturas Newsletter Podcasts Menu Opinião Economia Internacional].map do |label|
      %(<a href="/util/#{label}">#{label}</a>)
    end.join

    headline_blocks = (1..10).map do |i|
      <<~HTML
        <div class="utility-panel">
          <h2><a href="/economia/story-#{i}">Manchete #{i} sobre economia e política europeia</a></h2>
          <p>Resumo #{i} com contexto adicional para a manchete principal do dia.</p>
        </div>
      HTML
    end.join

    html = <<~HTML
      <html>
        <head>
          <title>Expresso | Liberdade para pensar</title>
          <meta name="description" content="Notícias, análises e opiniões do Expresso.">
        </head>
        <body>
          <header>
            #{utility_links}
          </header>
          <main>
            <h1>Expresso - Liberdade para pensar</h1>
            #{headline_blocks}
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://expresso.pt/", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["markdown"]).to include("[Manchete 1 sobre economia e política europeia](https://expresso.pt/economia/story-1)")
      expect(payload["markdown"]).to include("[Manchete 10 sobre economia e política europeia](https://expresso.pt/economia/story-10)")
      expect(payload["markdown"]).not_to include("Assinaturas")
      expect(payload["markdown"]).not_to include("Newsletter")
    end
  end

  it "ignores navigation chrome when extracting section homepages into list bullets" do
    nav_links = %w[Epaper ताज्या देश शहर क्रीडा मनोरंजन फोटो व्हिडिओ].map do |label|
      %(<a href="/nav/#{label}">#{label}</a>)
    end.join

    html = <<~HTML
      <html>
        <head>
          <title>विज्ञान-तंत्रज्ञान - eSakal</title>
          <meta name="description" content="विज्ञान आणि तंत्रज्ञानविषयक ताज्या बातम्या">
        </head>
        <body>
          <header>
            #{nav_links}
          </header>
          <main>
            <h1>विज्ञान-तंत्रज्ञान</h1>
            <div class="science-stream">
              <div class="headline-block"><h2><a href="/sci-tech/story-1">भारतीय संशोधकांनी नवीन अवकाश सेन्सर विकसित केला</a></h2></div>
              <div class="headline-block"><h2><a href="/sci-tech/story-2">पुण्यात हवामान बदलावर विद्यार्थ्यांची प्रयोगशाळा सुरू</a></h2></div>
              <div class="headline-block"><h2><a href="/sci-tech/story-3">कृषी रोबोट शेतातील पाणी वापर मोजणार</a></h2></div>
              <div class="headline-block"><h2><a href="/sci-tech/story-4">मराठी वैज्ञानिक मासिकात क्वांटम संगणकावर विशेषांक</a></h2></div>
              <div class="headline-block"><h2><a href="/sci-tech/story-5">सूर्यऊर्जेवर चालणारे सिंचन यंत्र गावात वापरात</a></h2></div>
              <div class="headline-block"><h2><a href="/sci-tech/story-6">विद्यार्थ्यांनी कमी किमतीचा हवामान सेन्सर तयार केला</a></h2></div>
              <div class="headline-block"><h2><a href="/sci-tech/story-7">आरोग्य क्षेत्रासाठी मराठी भाषेतील एआय साधन उपलब्ध</a></h2></div>
              <div class="headline-block"><h2><a href="/sci-tech/story-8">जलप्रदूषण मोजण्यासाठी स्वयंचलित तरंगता सेन्सर विकसित</a></h2></div>
              <div class="headline-block"><h2><a href="/sci-tech/story-9">विद्यापीठात जैवतंत्रज्ञान संशोधनासाठी नवीन निधी</a></h2></div>
              <div class="headline-block"><h2><a href="/sci-tech/story-10">महासागर अभ्यासासाठी भारतीय ड्रोन मोहिमेची तयारी</a></h2></div>
              <div class="headline-block"><h2><a href="/sci-tech/story-11">पुणे-मुंबई मार्गावर हवामान निरीक्षण केंद्रे बसवली</a></h2></div>
              <div class="headline-block"><h2><a href="/sci-tech/story-12">कर्करोग निदानासाठी नवीन संगणकीय मॉडेल विकसित</a></h2></div>
            </div>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://www.esakal.com/sci-tech/news", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["markdown"]).to include("भारतीय संशोधकांनी नवीन अवकाश सेन्सर विकसित केला")
      expect(payload["markdown"]).not_to include("Epaper")
      expect(payload["markdown"]).not_to include("मनोरंजन")
    end
  end

  it "prefers section-specific story links over trending rails on multilingual section pages" do
    global_nav = %w[హోమ్ జాతీయం అంతర్జాతీయం బిజినెస్ స్పోర్ట్స్ ఆంధ్రప్రదేశ్ తెలంగాణ వీడియోలు ఫోటోలు].map do |label|
      %(<a href="/rail/#{label}">#{label}</a>)
    end.join

    trending_links = [
      "మత మార్పిడి చేస్తే ఏడేళ్ల జైలు శిక్ష, విధేయత లేదంటే భారీ జరిమానా",
      "వైద్య విద్యార్థికి ISISతో సంబంధాలు.. దర్యాప్తులో కొత్త వివరాలు",
      "చెట్టు చుట్టూ తిరుగుతోన్న పంచాయితీ.. గ్రామంలో ఉద్రిక్తత"
    ].map.with_index(1) do |title, i|
      %(<article class="trend-card"><h2><a href="/india-news/trending-#{i}">#{title}</a></h2></article>)
    end.join

    science_links = [
      "మళ్లీ భూకక్ష్యలోకి చైనా రహస్య స్పేస్ షిప్.. ఏం చేస్తుందో ఎవరికీ అంతుబట్టడం లేదు!",
      "చంద్రయాన్-4.. ల్యాండింగ్‌కు ఎంఎం 4నే ఇస్రో ఎందుకు ఎంచుకుంది? దాని ప్రత్యేకత ఏంటి?",
      "భానుడు మహోగ్రరూపం.. భారత్‌కు సౌర తుఫాను ముప్పు: ఇస్రో హెచ్చరిక",
      "సౌర తుఫానుతో ఉపగ్రహ కమ్యూనికేషన్‌పై ప్రభావం ఉంటుందా? శాస్త్రవేత్తల వివరణ"
    ].map.with_index(1) do |title, i|
      <<~HTML
        <article class="_e">
          <header><h2><a href="/latest-news/science-technology/story-#{i}.cms">#{title}</a></h2></header>
          <p>సైన్స్ అండ్ టెక్నాలజీ విభాగంలోని కథనం #{i} గురించి చిన్న వివరణ.</p>
        </article>
      HTML
    end.join

    html = <<~HTML
      <html>
        <head>
          <title>సైన్స్ అండ్ టెక్నాలజీ: Latest Science News in Telugu - Samayam Telugu</title>
          <meta name="description" content="సైన్స్ అండ్ టెక్నాలజీ వార్తలు">
        </head>
        <body>
          <header class="first-level-menu">
            #{global_nav}
          </header>
          <section class="secondary-navbar">
            #{global_nav}
          </section>
          <section class="top-trending">
            #{trending_links}
          </section>
          <main>
            <div id="childrenContainer">
              <div class="secHead"><h1>సైన్స్ అండ్ టెక్నాలజీ</h1></div>
              <div class="row">
                <div class="col8">
                  <div class="aa">
                    #{science_links}
                  </div>
                </div>
              </div>
              <section class="latest-videos">
                <h2>లేటెస్ట్ వీడియోలు</h2>
                <a href="/videos/1">పాత వీడియో లింక్</a>
              </section>
            </div>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://telugu.samayam.com/latest-news/science-technology/articlelist/47921092.cms", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["markdown"]).to include("మళ్లీ భూకక్ష్యలోకి చైనా రహస్య స్పేస్ షిప్")
      expect(payload["markdown"]).to include("చంద్రయాన్-4")
      expect(payload["markdown"]).not_to include("మత మార్పిడి చేస్తే ఏడేళ్ల జైలు శిక్ష")
    end
  end

  it "demotes subscription and login chrome on Dutch news homepages" do
    html = <<~HTML
      <html>
        <head>
          <title>de Volkskrant - nieuws en achtergronden</title>
          <meta name="description" content="Nieuws, achtergronden en analyses van de Volkskrant.">
        </head>
        <body>
          <header>
            <a href="/abonneren">Abonneren vanaf €1,00 per week</a>
            <a href="/instellingen">Instellingen</a>
            <a href="/login">U bent niet (meer) ingelogd Log in of Maak een account</a>
            <a href="/best-gelezen">BEST GELEZEN MEER</a>
          </header>
          <main>
            <section class="story-stream">
              <article>
                <span>NIEUWS</span>
                <h2><a href="/nieuws-achtergrond/meta-youtube-aansprakelijk~b1">Meta en YouTube aansprakelijk gesteld voor schadelijke aanbevelingen</a></h2>
                <p>Rechters in de VS nemen een historisch besluit over algoritmische aanbevelingen.</p>
              </article>
              <article>
                <span>ANALYSE</span>
                <h2><a href="/nieuws-achtergrond/israel-libanon-infrastructuur~b2">Israël bombardeert cruciale infrastructuur in Libanon</a></h2>
                <p>De laatste escalatie raakt elektriciteitsnetten en logistieke knooppunten.</p>
              </article>
            </section>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://www.volkskrant.nl/", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["markdown"]).to include("Meta en YouTube aansprakelijk gesteld")
      expect(payload["markdown"]).to include("Israël bombardeert cruciale infrastructuur in Libanon")
      expect(payload["markdown"]).not_to include("Abonneren vanaf")
      expect(payload["markdown"]).not_to include("Instellingen")
      expect(payload["markdown"]).not_to include("U bent niet (meer) ingelogd")
      expect(payload["markdown"]).not_to include("BEST GELEZEN MEER")
    end
  end

  it "keeps live status details while dropping dashboard chrome" do
    html = <<~HTML
      <html>
        <head>
          <title>Tube, Overground, Elizabeth line, DLR & Tram status updates - Transport for London</title>
          <meta name="description" content="Live status updates for Tube and rail services.">
        </head>
        <body>
          <header>
            <a href="/modes/tube/">Tube & Rail</a>
            <a href="/major-works-and-events/">Major works and events</a>
            <a href="/fares/">Fares</a>
          </header>
          <main>
            <h1>Status</h1>
            <section class="status-board">
              <button type="button">Northern Minor delays Entire line Part suspended Tooting Broadway Morden</button>
              <p>Northern Line: No service between Tooting Broadway and Morden while we fix a faulty train at South Wimbledon.</p>
              <button type="button">Bakerloo Good service</button>
              <p>Good service on all Bakerloo line services.</p>
              <button type="button">Waterloo &amp; City Planned closure</button>
              <p>Waterloo &amp; City line is closed this weekend for planned engineering work.</p>
            </section>
            <section>
              <h2>The week ahead</h2>
              <p>Check planned engineering works before you travel.</p>
            </section>
            <aside>
              <a href="/status-updates/email-updates">Email updates</a>
              <a href="/about-tfl/">About Tfl</a>
              <a href="/help-and-contact/">Help &amp; contacts</a>
              <a href="/corporate/terms-and-conditions/">Legal information</a>
            </aside>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://tfl.gov.uk/tube-dlr-overground/status/", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["markdown"]).to include("Northern Line: No service between Tooting Broadway and Morden")
      expect(payload["markdown"]).to include("Good service on all Bakerloo line services")
      expect(payload["markdown"]).not_to include("About Tfl")
      expect(payload["markdown"]).not_to include("Legal information")
    end
  end

  it "prefers real section stories over cookie and legal chrome on regional news pages" do
    html = <<~HTML
      <html>
        <head>
          <title>Ticino - Ticinonline</title>
          <meta name="description" content="Notizie e articoli, ticino - Ticinonline">
        </head>
        <body>
          <div class="cookie-panel">
            <h2>Informazioni sulla vostra privacy</h2>
            <button>Accetta tutto</button>
            <button>Gestisci preferenze consenso</button>
            <p>Elenco dei cookie</p>
          </div>
          <header>
            <a href="/news">News</a>
            <a href="/sport">Sport</a>
            <a href="/agenda">Agenda</a>
          </header>
          <main>
            <section class="stream">
              <h1>Ticino</h1>
              <article>
                <h2><a href="/news/a1">Fine dei corsi A e B alla scuola media: ecco come avverrà</a></h2>
                <p>Il nuovo modello entrerà in vigore dal prossimo anno scolastico.</p>
              </article>
              <article>
                <h2><a href="/news/a2">Scuola media, l'addio ai livelli</a></h2>
                <p>Le classi sperimentali saranno estese a tutto il cantone.</p>
              </article>
              <article>
                <h2><a href="/news/a3">È in vigore il divieto assoluto di accendere fuochi all'aperto</a></h2>
                <p>Le autorità chiedono massima prudenza a causa del vento.</p>
              </article>
            </section>
          </main>
          <footer>
            <div>Ticinonline SA</div>
            <div>LINK UTILI</div>
            <div>Copyright 2026. All rights reserved.</div>
          </footer>
        </body>
      </html>
    HTML

    with_url_page("https://www.tio.ch/ticino", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["markdown"]).to include("Fine dei corsi A e B alla scuola media")
      expect(payload["markdown"]).to include("Scuola media, l'addio ai livelli")
      expect(payload["markdown"]).not_to include("Ticinonline SA")
      expect(payload["markdown"]).not_to include("LINK UTILI")
      expect(payload["markdown"]).not_to include("Informazioni sulla vostra privacy")
      expect(payload["markdown"]).not_to include("Elenco dei cookie")
    end
  end

  it "falls back to a news list when article extraction resolves to legal footer copy on a section path" do
    html = <<~HTML
      <html>
        <head>
          <title>Ticino - Ticinonline</title>
        </head>
        <body>
          <article class="content">
            <h1>Ticino</h1>
            <p>Ticinonline SA</p>
            <p>LINK UTILI</p>
            <p>Copyright 2026. All rights reserved.</p>
            <p>Privacy policy. Cookie policy. Terms of use.</p>
          </article>
          <main>
            <section class="stream">
              <article>
                <h2><a href="/news/a1">Fine dei corsi A e B alla scuola media: ecco come avverrà</a></h2>
                <p>Il nuovo modello entrerà in vigore dal prossimo anno scolastico.</p>
              </article>
              <article>
                <h2><a href="/news/a2">Scuola media, l'addio ai livelli</a></h2>
                <p>Le classi sperimentali saranno estese a tutto il cantone.</p>
              </article>
              <article>
                <h2><a href="/news/a3">È in vigore il divieto assoluto di accendere fuochi all'aperto</a></h2>
                <p>Le autorità chiedono massima prudenza a causa del vento.</p>
              </article>
            </section>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://www.tio.ch/ticino", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["markdown"]).to include("Fine dei corsi A e B alla scuola media")
      expect(payload["markdown"]).to include("Scuola media, l'addio ai livelli")
      expect(payload["markdown"]).not_to include("Ticinonline SA")
      expect(payload["markdown"]).not_to include("LINK UTILI")
    end
  end

  it "removes cookie banner text from news index descriptions" do
    html = <<~HTML
      <html>
        <head>
          <title>BTA :: All News</title>
        </head>
        <body>
          <div class="cookies">
            <p>This website uses cookies. By accepting cookies you can enjoy a better experience while browsing pages.</p>
            <a href="#accept">Accept</a>
            <a href="/cookies">More information</a>
          </div>
          <main class="main__inner">
            <h1>All News</h1>
            <article>
              <h2><a href="/story/1">UPDATED Central Election Commission Presents Specimen Ballots for Upcoming Snap Parliamentary Vote</a></h2>
              <p>The commission showed the ballot design ahead of the April vote.</p>
            </article>
            <article>
              <h2><a href="/story/2">Sofia University Rector Dismisses Dean and Deputy Deans of Medical Faculty</a></h2>
              <p>The university leadership announced new interim management.</p>
            </article>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://www.bta.bg/en/news", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["markdown"]).to include("Sofia University Rector Dismisses Dean")
      expect(payload["markdown"]).not_to include("This website uses cookies")
      expect(payload["markdown"]).not_to include("By accepting cookies")
    end
  end

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
              <p>Veðurspá. Reykjavík. Í kvöld: Rigning, suð-suð-austan 5, hiti 4 stig, úrkoma 0.3 millimetrar.</p>
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
