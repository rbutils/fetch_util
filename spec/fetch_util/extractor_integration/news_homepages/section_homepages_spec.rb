# frozen_string_literal: true

RSpec.describe 'FetchUtil extractor integration' do
  include_context 'extractor integration helpers'

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
end
