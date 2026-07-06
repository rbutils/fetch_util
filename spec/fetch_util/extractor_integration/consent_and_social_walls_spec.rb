# frozen_string_literal: true

RSpec.describe 'FetchUtil extractor integration' do
  include_context 'extractor integration helpers'
  include_context 'fixture html helpers'

  it "dismisses a OneTrust banner before extracting the article" do
    html = <<~HTML
      <html>
        <head><title>City council approves new transport plan</title></head>
        <body style="overflow:hidden" class="modal-open">
          <div id="onetrust-banner-sdk" role="dialog" aria-modal="true" style="position:fixed; inset:0; background:#fff; z-index:9999">
            <h2>Your Privacy Settings</h2>
            <p>We use cookies and similar technologies to personalize content and measure advertising.</p>
            <button id="onetrust-accept-btn-handler" onclick="window.__acceptedCookies = true">Accept all</button>
          </div>
          <main>
            <article>
              <h1>City council approves new transport plan</h1>
              <p>The city council approved a detailed transport plan after months of public consultation and engineering review.</p>
              <p>The proposal adds dedicated bus lanes, safer crossings, and timetable changes for neighborhoods with limited service.</p>
              <p>Officials said the first phase will begin this autumn, with progress reports published every quarter.</p>
            </article>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://www.example-news.test/2026/07/06/transport-plan", html) do |page|
      browser = FetchUtil::Browser.new(browser_path: browser_path, wait: 0, wait_for_idle: false)

      expect(browser.send(:accept_cookie_consent, page)).to eq(true)
      expect(page.evaluate("window.__acceptedCookies === true")).to eq(true)
      expect(page.evaluate("document.querySelector('#onetrust-banner-sdk') === null")).to eq(true)

      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["markdown"]).to include("The city council approved a detailed transport plan")
      expect(payload["markdown"]).not_to include("Your Privacy Settings")
      expect(payload["warnings"]).not_to include("consent_interstitial")
    end
  end

  it "removes a Cookiebot overlay before extracting the article" do
    html = <<~HTML
      <html>
        <head><title>Regional growers report stronger harvest</title></head>
        <body style="overflow:hidden" class="scroll-lock">
          <div id="CybotCookiebotDialog" style="position:fixed; inset:0; background:#fff; z-index:9999">
            <h2>Cookie declaration</h2>
            <p>This website uses cookies to collect personal data, manage consent preferences, and personalize advertising.</p>
            <p>Necessary, statistics, and marketing cookies can be managed from this consent panel.</p>
          </div>
          <article>
            <h1>Regional growers report stronger harvest</h1>
            <p>Regional growers reported a stronger harvest after spring rainfall improved soil conditions across the valley.</p>
            <p>Cooperatives said storage capacity and rail access remain the main constraints for smaller farms this season.</p>
            <p>Market analysts expect stable prices if export demand continues through the next quarter.</p>
          </article>
        </body>
      </html>
    HTML

    with_url_page("https://www.example-news.test/2026/07/06/harvest", html) do |page|
      browser = FetchUtil::Browser.new(browser_path: browser_path, wait: 0, wait_for_idle: false)

      expect(browser.send(:accept_cookie_consent, page)).to eq(true)
      expect(page.evaluate("document.querySelector('#CybotCookiebotDialog') === null")).to eq(true)

      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["markdown"]).to include("Regional growers reported a stronger harvest")
      expect(payload["markdown"]).not_to include("Cookie declaration")
      expect(payload["warnings"]).not_to include("consent_interstitial")
    end
  end

  it "flags multilingual cookie centers as consent interstitials" do
    html = <<~HTML
      <html>
        <head><title>推しカラー（推し色）とは？</title></head>
        <body>
          <main>
            <h1>推しカラー（推し色）とは？</h1>
            <h2>クッキープリファレンスセンター</h2>
            <p>当社は Cookie を利用してサイト体験を改善します。</p>
            <button>すべて受け入れる</button>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://www.lifestyle-expo.jp/hub/ja-jp/blog/lifestyle/ls/color.html", html) do |page|
      payload = FetchUtil::Extractor.new(reader_mode: false).extract(page)

      expect(payload["warnings"]).to include("consent_interstitial")
      expect(payload["suspect"]).to eq(true)
    end
  end

  it "prefers the real article when hidden OneTrust markup remains in the DOM" do
    html = <<~HTML
      <html>
        <head><title>推しカラー（推し色）とは？</title></head>
        <body>
          <div id="onetrust-consent-sdk" style="display:none">
            <h2>クッキープリファレンスセンター</h2>
            <p>当社は Cookie を利用してサイト体験を改善します。</p>
            <button id="accept-recommended-btn-handler">すべて許可する</button>
          </div>
          <article class="article-body">
            <h1>推しカラー（推し色）とは？</h1>
            <p>推しカラーは、応援している相手を象徴する色として使われます。</p>
            <p>グッズや衣装、会場演出にも使いやすく、ファンの認識をそろえる役割があります。</p>
            <p>ライブ会場ではペンライトや服の色にも反映され、遠くからでも誰を応援しているかが伝わります。</p>
            <h2>推しカラーの役割</h2>
            <p>ファン同士のコミュニケーションやグッズ展開にも役立ちます。</p>
            <p>企業にとっても、商品企画や売り場演出を考える際の分かりやすい切り口になります。</p>
          </article>
        </body>
      </html>
    HTML

    with_url_page("https://www.lifestyle-expo.jp/hub/ja-jp/blog/lifestyle/ls/color.html", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["markdown"]).to include("推しカラーは、応援している相手を象徴する色として使われます。")
      expect(payload["markdown"]).not_to include("クッキープリファレンスセンター")
      expect(payload["warnings"]).not_to include("consent_interstitial")
    end
  end

  it "removes hidden multilingual OneTrust markup even when the copy is not in the keyword list" do
    html = <<~HTML
      <html lang="sr">
        <head><title>Analiza kampanje</title></head>
        <body>
          <div id="onetrust-consent-sdk" style="display:none">
            <h2>О вашој приватности</h2>
            <p>Користимо колачиће и обрађујемо податке како бисмо чували и/или приступали информацијама на уређају.</p>
            <button id="accept-recommended-btn-handler">Прихватам</button>
          </div>
          <div id="onetrust-pc-sdk" style="display:none; position:fixed">
            <p>Управљање жељеним поставкама за пристанак</p>
          </div>
          <article class="article-body">
            <h1>Анализа кампање</h1>
            <p>Локални избори показују да је излазност у урбаним срединама порасла у односу на претходни циклус.</p>
            <p>Истраживачи наводе да су локалне теме и инфраструктура имале већу тежину од националних порука.</p>
            <p>У завршници кампање странке су појачале теренске активности и директан контакт са бирачима.</p>
          </article>
        </body>
      </html>
    HTML

    with_url_page("https://n1info.rs/vesti/analiza-kampanje/", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["markdown"]).to include("Локални избори показују")
      expect(payload["markdown"]).not_to include("О вашој приватности")
      expect(payload["markdown"]).not_to include("Управљање жељеним поставкама за пристанак")
      expect(payload["warnings"]).not_to include("consent_interstitial")
    end
  end

  it "removes visible Amharic cookie banners when the article content is present" do
    html = <<~HTML
      <html lang="am">
        <head><title>አዲስ ዜና</title></head>
        <body>
          <div role="dialog" aria-modal="true" class="cookie-banner" style="position:fixed; inset:0; background:#fff; z-index:99">
            <h2>የእርስዎ ግላዊነት</h2>
            <p>ይህ ጣቢያ ኩኪዎችን እና ተመሳሳይ ቴክኖሎጂዎችን ይጠቀማል።</p>
            <button>ተቀበል</button>
            <button>አስተካክል</button>
          </div>
          <article class="article-body">
            <h1>አዲስ ዜና</h1>
            <p>በዚህ ሳምንት በከተማው ውስጥ የህዝብ መጓጓዣ ስርዓት ላይ አዲስ ለውጦች ተጀምረዋል።</p>
            <p>ባለሙያዎች እነዚህ ለውጦች በተሳፋሪዎች የጉዞ ጊዜ እና የአገልግሎት ጥራት ላይ አዎንታዊ ተፅእኖ እንደሚያሳድሩ ይገልጻሉ።</p>
          </article>
        </body>
      </html>
    HTML

    with_url_page("https://www.jw.org/am/%E1%88%9D%E1%8A%95-%E1%8A%A0%E1%8B%B2%E1%88%B5-%E1%8A%90%E1%8C%88%E1%88%AD-%E1%8A%A0%E1%88%88/", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["markdown"]).to include("የህዝብ መጓጓዣ ስርዓት")
      expect(payload["markdown"]).not_to include("የእርስዎ ግላዊነት")
      expect(payload["markdown"]).not_to include("ኩኪዎችን")
      expect(payload["warnings"]).not_to include("consent_interstitial")
    end
  end

  it "removes privacy preference center banners when real streaming content is present" do
    html = <<~HTML
      <html>
        <head><title>Watch The Mandalorian | Full episodes | Disney+</title></head>
        <body>
          <div id="onetrust-consent-sdk" data-nosnippet="true">
            <div id="onetrust-banner-sdk" class="ot-sdk-container">
              <h2>Your Privacy Settings</h2>
              <p>We and our partners may store and access information on your device.</p>
              <button id="onetrust-reject-all-handler">Reject All</button>
              <button id="onetrust-accept-btn-handler">Accept All</button>
            </div>
            <div id="onetrust-pc-sdk" class="ot-pc-root" style="display:none">
              <h2>Privacy Preference Center</h2>
              <div class="ot-accordion-layout">
                <p>Targeting & Advertising Cookies</p>
              </div>
              <button>List of Partners (vendors)</button>
            </div>
          </div>
          <main>
            <section>
              <h1>The Mandalorian</h1>
              <p>After the fall of the Empire, a lone Mandalorian makes his way through the lawless galaxy with Grogu.</p>
              <p>Release Date: 2019 - 2023</p>
            </section>
          </main>
          <footer>
            <a href="#">Manage Privacy Preferences</a>
          </footer>
        </body>
      </html>
    HTML

    with_url_page('https://www.disneyplus.com/series/the-mandalorian/3jLIGMDYINqD', html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload['markdown']).to include('The Mandalorian')
      expect(payload['markdown']).to include('After the fall of the Empire')
      expect(payload['markdown']).not_to include('Your Privacy Settings')
      expect(payload['markdown']).not_to include('Privacy Preference Center')
      expect(payload['markdown']).not_to include('Targeting & Advertising Cookies')
      expect(payload['markdown']).not_to include('List of Partners')
    end
  end

  it "removes privacy and player shell text when real audio catalog content is present" do
    html = <<~HTML
      <html>
        <head><title>Listen to the Best Podcasts & Shows Online, Free | iHeart</title></head>
        <body>
          <div id="onetrust-banner-sdk">
            <h2>Privacy Preference Center</h2>
            <p>Manage Consent Preferences for advertising and analytics cookies.</p>
            <button>Confirm My Choices</button>
            <button>Reject All</button>
          </div>
          <section class="player-shell">
            <button>Play</button>
            <button>Rewind 10 Seconds</button>
            <button>Closed Captions</button>
            <button>Settings</button>
            <p>Volume 60%</p>
            <p>Learn More</p>
          </section>
          <main>
            <section>
              <h1>Stream Top Podcasts</h1>
              <article>
                <h2>Stuff You Should Know</h2>
                <p>Learn about history, science, and culture with new episodes every week.</p>
              </article>
              <article>
                <h2>Las Culturistas</h2>
                <p>Comedy and pop-culture interviews from two very online hosts.</p>
              </article>
            </section>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://www.iheart.com/podcast/", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["markdown"]).to include("Stream Top Podcasts")
      expect(payload["markdown"]).to include("Stuff You Should Know")
      expect(payload["markdown"]).not_to include("Privacy Preference Center")
      expect(payload["markdown"]).not_to include("Confirm My Choices")
      expect(payload["markdown"]).not_to include("Rewind 10 Seconds")
      expect(payload["markdown"]).not_to include("Volume 60%")
      expect(payload["markdown"]).not_to include("Closed Captions")
    end
  end

  it "removes large cookie consent overlays exceeding 5000 chars of privacy text" do
    # Regression test: cookieNoticeText() had a 5000-char limit that let verbose
    # consent walls (e.g. TVP Info's 6,511-char overlay) escape cleanup.
    # The fix in cookieChromeNode() now bypasses cookieNoticeText() for elements
    # whose class/id already matches a cookie/consent pattern when text > 5000 chars.
    privacy_text = "Wykorzystujemy pliki cookie do celów analitycznych i marketingowych. " * 80 # ~5,600 chars
    html = <<~HTML
      <html>
        <head><title>Wiadomości - TVP Info</title></head>
        <body>
          <div class="tvp-cookie-overlay" style="position:fixed; inset:0; z-index:999">
            <div class="tvp-covl">
              <h2>Szanowny Użytkowniku</h2>
              <p>#{privacy_text}</p>
              <div class="tvp-covl__ab">Akceptuję i przechodzę do serwisu</div>
            </div>
          </div>
          <section class="wallpaper">
            <article>
              <h1>Prorosyjska oś wpływów rozbita</h1>
              <p>Służby zatrzymały podejrzanych o szpiegostwo na rzecz obcego wywiadu w ramach międzynarodowej operacji.</p>
              <p>Śledztwo objęło kilka krajów Europy Środkowej i trwało ponad rok.</p>
            </article>
          </section>
        </body>
      </html>
    HTML

    with_url_page("https://www.tvp.info/", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["markdown"]).to include("Prorosyjska oś wpływów rozbita")
      expect(payload["markdown"]).not_to include("Szanowny Użytkowniku")
      expect(payload["markdown"]).not_to include("Wykorzystujemy pliki cookie")
    end
  end

  # Consent wall extraction cascade: real article behind a consent wall
  it "extracts the real article when a consent wall is detected but real content exists behind it" do
    # Simulates the case where Ruby-side consent dismissal partially worked:
    # the consent wall DOM is still present (so JS detects consent_wall interstitial)
    # but the real article is also accessible in the DOM.
    paragraphs = 8.times.map do |i|
      "<p>Detailed analysis paragraph #{i + 1} about the economic policy impact on Nordic countries and their trade agreements with neighboring states.</p>"
    end.join("\n")
    html = <<~HTML
      <html>
        <head><title>Dine personverninnstillinger</title></head>
        <body>
          <div class="cookie-consent" style="position:fixed; z-index:999">
            <h1>Dine personverninnstillinger</h1>
            <p>Vi bruker informasjonskapsler og lignende teknologier for å gi deg en bedre opplevelse.</p>
            <p>Vi og våre partnere lagrer og bruker informasjonskapsler for å tilpasse innhold og annonser.</p>
            <button>Godta alle</button>
          </div>
          <main>
            <article>
              <h1>Nordic Trade Agreement Analysis</h1>
              #{paragraphs}
            </article>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://www.document.no/nordic-trade-analysis", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      # Should extract the real article, not the synthetic interstitial
      expect(payload["markdown"]).to include("economic policy impact on Nordic countries")
      expect(payload["markdown"]).not_to include("Interstitial:")
    end
  end

  it "returns synthetic content when consent wall dominates and no real article exists" do
    html = simple_consent_wall_html(
      title: "Cookie-inställningar",
      heading: "Vi använder kakor",
      paragraphs: [
        "Vi anvander kakor och liknande tekniker for att ge dig en battre upplevelse.",
        "Samtycke till personanpassade annonser och innehall.",
        "Vi anvander kakor for att forbattra prestanda."
      ],
      buttons: ["Acceptera alla", "Avvisa valfria kakor"]
    )

    with_url_page("https://www.svd.se/consent-only-page", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      # Should flag as consent interstitial since there's no real content
      expect(payload["warnings"]).to include("consent_interstitial")
    end
  end

  # Latvian consent wall detection
  it "detects Latvian consent wall interstitial" do
    html = simple_consent_wall_html(
      title: "Sīkdatņu iestatījumi",
      heading: "Sīkdatņu iestatījumi",
      paragraphs: [
        "Izmantojam sīkdatnes un līdzīgas tehnoloģijas, lai uzlabotu jūsu pieredzi.",
        "Sīkdatņu iestatījumi ļauj jums izvēlēties kādus sīkfailus izmantojam."
      ],
      buttons: ["Pieņemt visus", "Noraidīt izvēles sīkdatnes"]
    )

    with_url_page("https://www.delfi.lv/some-article", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["warnings"]).to include("consent_interstitial")
    end
  end

  # Hungarian consent wall detection
  it "detects Hungarian consent wall interstitial" do
    html = simple_consent_wall_html(
      title: "Süti beállítások",
      heading: "Sütiket használunk",
      paragraphs: [
        "Sütiket és hasonló technológiákat használunk az élmény javítása érdekében.",
        "Adatvédelmi beállítások lehetővé teszik a sütik kezelését."
      ],
      buttons: ["Elfogadom", "Elutasítom az opcionális sütiket"]
    )

    with_url_page("https://www.index.hu/some-article", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["warnings"]).to include("consent_interstitial")
    end
  end

  it "preserves richer visible copy for Google-style consent shells and keeps consent warnings" do
    html = <<~HTML
      <html>
        <head><title>Google</title></head>
        <body>
          <main>
            <h1>Before you continue to Google</h1>
            <p>We use cookies and data to deliver and maintain Google services, track outages, and protect against spam, fraud, and abuse.</p>
            <ul>
              <li>Develop and improve new services</li>
              <li>Deliver and measure the effectiveness of ads</li>
              <li>Show personalized content, depending on your settings</li>
            </ul>
            <button>Reject all</button>
            <button>More options</button>
            <button>Accept all</button>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://www.google.com/", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["markdown"]).to include("# Before you continue to Google")
      expect(payload["markdown"]).to include("We use cookies and data to deliver and maintain Google services")
      expect(payload["markdown"]).to include("Develop and improve new services")
      expect(payload["markdown"]).to include("Control: Reject all")
      expect(payload["markdown"]).to include("Control: More options")
      expect(payload["warnings"]).to include("consent_interstitial")
      expect(payload["suspect"]).to eq(true)
    end
  end

  it "keeps non-Google consent walls compact and flagged" do
    html = simple_consent_wall_html(
      title: "Cookie Settings",
      heading: "Cookie Settings",
      paragraphs: ["We use cookies to keep this service reliable and to measure audience activity.", "Essential cookies are always active."],
      buttons: ["Reject optional cookies", "Accept all cookies"]
    )

    with_url_page("https://example.org/privacy/consent", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["markdown"]).to include("# Cookie Settings")
      expect(payload["markdown"]).to include("We use cookies to keep this service reliable")
      expect(payload["markdown"]).to include("Control: Accept all cookies")
      expect(payload["warnings"]).to include("consent_interstitial")
      expect(payload["suspect"]).to eq(true)
    end
  end

  it "classifies short privacy choice fragments as consent interstitials" do
    html = <<~HTML
      <html>
        <head><title>Legal Code of Conduct</title></head>
        <body>
          <main>
            <a href="/privacy/choices">Do Not Sell or Share My Personal Information</a>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://www.example.org/content/legal-code-of-conduct.html", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["markdown"]).to include("Do Not Sell or Share My Personal Information")
      expect(payload["contentType"]).to eq("interstitial")
      expect(payload["warnings"]).to include("consent_interstitial")
      expect(payload["suspect"]).to eq(true)
    end
  end

  it "keeps richer consent summaries classified as consent walls" do
    html = <<~HTML
      <html>
        <head><title>Your privacy choices</title></head>
        <body>
          <main>
            <h1>Before you continue</h1>
            <p>We use cookies and data to provide maps, video recommendations, personalized content, product features, security monitoring, outage tracking, audience measurement, and advertising controls across this service.</p>
            <p>You can manage privacy settings for personalized ads, browsing history, device identifiers, and partner measurement before continuing.</p>
            <ul>
              <li>Personalized content and recommendations</li>
              <li>Personalized ads and measurement</li>
              <li>Privacy settings for cookies and data</li>
            </ul>
            <button>Reject all</button>
            <button>Manage options</button>
            <button>Accept all</button>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://accounts.example.org/consent", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["markdown"]).to include("# Before you continue")
      expect(payload["markdown"]).to include("Personalized content and recommendations")
      expect(payload["markdown"]).to include("Control: Manage options")
      expect(payload["warnings"]).to include("consent_interstitial")
      expect(payload["suspect"]).to eq(true)
    end
  end

  it "removes hidden cookie declaration text when real section content is present" do
    html = <<~HTML
      <html>
        <head><title>TURKIYE | Daily Sabah</title></head>
        <body>
          <div class="hidden">
            <div class="CookieDeclaration">
              <h2>Cookie declaration</h2>
              <p>Cookies are used for the purpose of performing advertising and marketing activities.</p>
              <p>Cookie declaration last updated on 26/03/2026</p>
              <p>Consent ID: abc-123</p>
              <p>Change your consent</p>
              <p>Your current state: Deny.</p>
              <p>Necessary (4)</p>
              <p>Marketing (12)</p>
            </div>
          </div>
          <main>
            <section>
              <h1>TURKIYE</h1>
              <article>
                <h2><a href="/turkiye/story-1">Türkiye arrests woman posing as NATO official over alleged fraud scheme</a></h2>
                <p>Authorities say the suspect used forged credentials in Ankara.</p>
              </article>
              <article>
                <h2><a href="/turkiye/story-2">Heavy winter rains spike tick population risk in Türkiye</a></h2>
                <p>Experts warn that warmer conditions could prolong the season.</p>
              </article>
            </section>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://www.dailysabah.com/turkiye", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["markdown"]).to include("Türkiye arrests woman posing as NATO official")
      expect(payload["markdown"]).to include("Heavy winter rains spike tick population risk in Türkiye")
      expect(payload["markdown"]).not_to include("Cookie declaration")
      expect(payload["markdown"]).not_to include("Consent ID")
      expect(payload["markdown"]).not_to include("Your current state")
      expect(payload["warnings"]).not_to include("consent_interstitial")
    end
  end
end
