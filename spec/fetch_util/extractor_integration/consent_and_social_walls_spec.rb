# frozen_string_literal: true

RSpec.describe 'FetchUtil extractor integration' do
  include_context 'extractor integration helpers'

  it "flags consent interstitial pages as suspect" do
    html = <<~HTML
      <html>
        <head><title>reddit for rubyists</title></head>
        <body>
          <main>
            <h1>reddit for rubyists</h1>
            <p>Let us know your cookie preferences</p>
            <p>Before you continue to Reddit</p>
            <p>Accept all cookies</p>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://www.ft.com/", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["suspect"]).to eq(true)
      expect(payload["warnings"]).to include("consent_interstitial")
    end
  end

  it "summarizes Reddit cookie prompts from metadata and flags them" do
    html = <<~HTML
      <html>
        <head>
          <title>Groundbird Gear out of business? : r/BackpackingDogs</title>
          <meta name="description" content="Discussion about whether Groundbird Gear is out of business.">
        </head>
        <body>
          <main>
            <h1>Groundbird Gear out of business? : r/BackpackingDogs</h1>
            <p>Let us know your cookie preferences</p>
            <p>Before you continue to Reddit</p>
            <p>Reddit uses cookies and similar technologies to keep the website operational.</p>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://www.reddit.com/r/BackpackingDogs/comments/17yd040/groundbird_gear_out_of_business", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["markdown"]).to include("# Groundbird Gear out of business?")
      expect(payload["markdown"]).to include("Discussion about whether Groundbird Gear is out of business.")
      expect(payload["markdown"]).not_to include("Let us know your cookie preferences")
      expect(payload["warnings"]).to include("consent_interstitial")
    end
  end

  it "does not force a Reddit login-required summary when the real post is present after consent" do
    html = <<~HTML
      <html>
        <head>
          <title>Groundbird Gear out of business? : r/BackpackingDogs</title>
        </head>
        <body>
          <main>
            <h1>Groundbird Gear out of business?</h1>
            <p>Let us know your cookie preferences</p>
            <shreddit-post></shreddit-post>
            <faceplate-screen-reader-content>
              I was interested in getting a groundbird gear harness and pack system for my dog.
            </faceplate-screen-reader-content>
            <shreddit-comment></shreddit-comment>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://www.reddit.com/r/BackpackingDogs/comments/17yd040/groundbird_gear_out_of_business", html) do |page|
      payload = FetchUtil::Extractor.new(reader_mode: false).extract(page)

      expect(payload["markdown"]).to include("groundbird gear harness")
      expect(payload["markdown"]).not_to include("This Reddit page requires cookie acceptance or login")
    end
  end

  it "extracts reddit threads with comments without relying on readability" do
    html = <<~HTML
      <html>
        <head>
          <title>Ruby thread : r/ruby</title>
        </head>
        <body>
          <main>
            <shreddit-post author="alice" comment-count="2">
              <div slot="credit-bar">Go to ruby r/ruby 4d ago alice</div>
              <h1 slot="title">Ruby thread</h1>
              <div slot="text-body">Here is the original post body.</div>
            </shreddit-post>
            <shreddit-comment author="bob" depth="0" score="12">
              <div slot="commentMeta">bob 3d ago</div>
              <div slot="comment">First top-level comment.</div>
              <shreddit-comment author="nested" depth="1" score="2">
                <div slot="comment">Nested reply should not be promoted as a top-level heading.</div>
              </shreddit-comment>
            </shreddit-comment>
            <shreddit-comment author="carol" depth="0" score="4">
              <div slot="commentMeta">carol 2d ago</div>
              <div slot="comment">Second top-level comment.</div>
            </shreddit-comment>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://www.reddit.com/r/ruby/comments/123/ruby-thread", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["readerMode"]).to eq(false)
      expect(payload["markdown"]).to include("# Ruby thread")
      expect(payload["markdown"]).to include("Here is the original post body.")
      expect(payload["markdown"]).to include("## Top Comments")
      expect(payload["markdown"]).to include("### bob (12 points)")
      expect(payload["markdown"]).to include("First top-level comment.")
      expect(payload["markdown"]).to include("### carol (4 points)")
      expect(payload["markdown"]).to include("Second top-level comment.")
      expect(payload["markdown"]).not_to include("This Reddit page requires cookie acceptance or login")
    end
  end

  it "summarizes Behance cookie-settings prompts and flags them" do
    html = <<~HTML
      <html>
        <head>
          <title>Embossage Projects :: Photos, videos, logos, illustrations and branding</title>
          <meta name="description" content="Discover projects related to embossage on Behance.">
        </head>
        <body>
          <main>
            <h2>Cookie Settings</h2>
            <p>Adobe and our partners use cookies to personalize advertising.</p>
            <p>Measure performance</p>
            <p>Personalize advertising</p>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://www.behance.net/search/projects/embossage", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["markdown"]).to include("# Embossage Projects")
      expect(payload["markdown"]).to include("Discover projects related to embossage on Behance.")
      expect(payload["markdown"]).not_to include("Adobe and our partners use cookies")
      expect(payload["warnings"]).to include("consent_interstitial")
    end
  end

  it "extracts behance search results when project cards are present" do
    html = <<~HTML
      <html>
        <head>
          <title>Embossage Projects :: Photos, videos, logos, illustrations and branding</title>
          <meta name="description" content="Discover projects related to embossage on Behance.">
        </head>
        <body>
          <main>
            <h1>40 Results for "embossage"</h1>
            <article>
              <a href="/gallery/33413299/Atelier-Embossage?tracking_source=search_projects%7Cembossage">Atelier : Embossage</a>
              <p>Jean-Philippe Ogez 44 views</p>
            </article>
            <article>
              <a href="/gallery/12959385/Embossage?tracking_source=search_projects%7Cembossage">Embossage</a>
              <p>marielle Marenati 746 views</p>
            </article>
            <article>
              <a href="/gallery/166395145/Cration-dun-faire-part-de-mariage?tracking_source=search_projects%7Cembossage">Création d'un faire-part de mariage</a>
            </article>
            <article>
              <a href="/gallery/128386867/Chapitre-02-Paragraphe?tracking_source=search_projects%7Cembossage">Chapitre 02 // Paragraphe</a>
            </article>
            <footer>
              <button>Cookie preferences</button>
            </footer>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://www.behance.net/search/projects/embossage", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["contentType"]).to eq("list")
      expect(payload["markdown"]).to include("- [Atelier : Embossage](https://www.behance.net/gallery/33413299/Atelier-Embossage)")
      expect(payload["markdown"]).to include("- [Chapitre 02 // Paragraphe](https://www.behance.net/gallery/128386867/Chapitre-02-Paragraphe)")
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
