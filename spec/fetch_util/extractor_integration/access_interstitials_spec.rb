# frozen_string_literal: true

RSpec.describe 'FetchUtil extractor integration' do
  include_context 'extractor integration helpers'

  def not_found_context_test_source
    root = File.expand_path('../../..', __dir__)
    source = File.readlines(File.join(root, 'websieve/manifest.txt'), chomp: true)
                 .reject { |line| line.empty? || line.start_with?('#') }
                 .map { |path| File.read(File.join(root, 'websieve', path)) }.join("\n")
    source.sub(
      '})(window);',
      [
        'global.__continuousTickerUnavailableNode = continuousTickerUnavailableNode;',
        'global.__continuousTickerRootUnavailable = continuousTickerRootUnavailable;',
        'global.__continuousTickerToken = continuousTickerToken;',
        'global.__collectContinuousTickerRecords = collectContinuousTickerRecords;',
        'global.__continuousTickerRecordKey = continuousTickerRecordKey;',
        'global.__insertMissingTickerRecordLines = insertMissingTickerRecordLines;',
        'global.__supplementNotFoundTickerHtml = supplementNotFoundTickerHtml;',
        'global.__supplementNotFoundTickerRecordsForTest = function(content) {',
        '  return supplementNotFoundTickerRecords(content, collectMetadata(), pageReadableText());',
        '};',
        '})(window);'
      ].join(' ')
    )
  end

  it "flags meta cookie and login-required pages and summarizes metadata" do
    html = <<~HTML
      <html>
        <head>
          <title>Threads • Log in</title>
          <meta property="og:site_name" content="Threads">
          <meta name="description" content="Join Threads to share ideas, ask questions, post random thoughts, find your people and more. Log in with your Instagram.">
        </head>
        <body>
          <main>
            <h1>Allow the use of cookies from Threads by Instagram on this browser?</h1>
            <p>We use cookies and similar technologies to help provide and improve content on Meta Products.</p>
            <p>Essential cookies</p>
          </main>
        </body>
      </html>
    HTML

    with_page(html) do |page|
      payload = extract_payload(page)

      expect(payload["markdown"]).to include("# Threads page")
      expect_warnings(payload, include: %w[meta_login_wall consent_interstitial])
    end
  end

  it "classifies account login shells without public content as interstitials" do
    html = <<~HTML
      <html>
        <head><title>The IUCN Red List of Threatened Species</title></head>
        <body>
          <main>
            <h1>Page cannot be found</h1>
            <section class="account-panel">
              <h1>My Account</h1>
              <h2>Log in</h2>
              <p>You must log in to access advanced IUCN Red List functionality. Please enter your e-mail address and password below.</p>
              <label>Email address</label><input type="email">
              <label>Password</label><input type="password">
              <a href="/users/password/new">Forgot your password?</a>
              <p>Register for an account</p>
              <a href="/users/sign_up">Register now</a>
            </section>
          </main>
        </body>
      </html>
    HTML

    with_url_page('https://www.iucnredlist.org/species/9728/123456', html) do |page|
      payload = extract_payload(page)

      expect_content_type(payload, 'interstitial')
      expect_warnings(payload, include: 'auth_or_login_interstitial')
      expect(payload['markdown']).to include('Access notice: login or account required')
    end
  end

  it "keeps Instagram login-required pages as interstitials without social fields" do
    html = <<~HTML
      <html>
        <head>
          <title>Groundbird (@groundbirdsings) • Instagram photos and videos</title>
        </head>
        <body>
          <main>
            <p>Allow the use of cookies from Instagram on this browser?</p>
            <p>Log in to see photos and videos.</p>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://www.instagram.com/accounts/login/?next=%2Fgroundbirdsings%2F", html) do |page|
      payload = extract_payload(page)

      expect_content_type(payload, "interstitial")
      expect(payload.values_at("socialKind", "platform", "handle")).to all(be_nil)
      expect_warnings(payload, include: %w[meta_login_wall consent_interstitial])
    end
  end

  it "does not treat Instagram post Open Graph metadata as public content" do
    html = <<~HTML
      <html>
        <head>
          <title>Instagram</title>
          <meta property="og:title" content="Cristiano Ronaldo on Instagram: &quot;&#x1f60e;&quot;">
          <meta property="og:description" content="8M likes, 59K comments - cristiano on November 24, 2024: &quot;&#x1f60e;&quot;.">
          <meta property="og:image" content="https://example.com/cristiano.jpg">
        </head>
        <body>
          <main>
            <p>Log in to see photos and videos.</p>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://www.instagram.com/accounts/login/?next=%2Fp%2FDCwL2cKggIk%2F", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect_content_type(payload, "interstitial")
      expect(payload.values_at("socialKind", "platform", "handle")).to all(be_nil)
      expect_warnings(payload, include: "meta_login_wall")
    end
  end

  it "does not treat Instagram unavailable post metadata as public content" do
    html = <<~HTML
      <html>
        <head>
          <title>Instagram</title>
          <meta property="og:title" content="Ronaldo on Instagram: &quot;Miami open 🎾 Que semana incrível! Obrigado, @itau&quot;">
          <meta property="og:description" content="8M likes, 59K comments - ronaldo on March 30, 2026: &quot;Miami open 🎾 Que semana incrível! Obrigado, @itau&quot;.">
          <meta property="og:image" content="https://example.com/ronaldo.jpg">
        </head>
        <body>
          <main>
            <p>Log in to see photos and videos.</p>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://www.instagram.com/ronaldo/p/DWh3vbdkXI1/", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect_content_type(payload, "interstitial")
      expect(payload.values_at("socialKind", "platform", "handle")).to all(be_nil)
      expect_warnings(payload, include: "meta_login_wall")
    end
  end

  it "does not return an Instagram login-required summary when a short visible username-prefixed post is present" do
    html = <<~HTML
      <html>
        <head>
          <title>Ronaldo on Instagram: &quot;Miami open 🎾 Que semana incrível! Obrigado, @itau&quot;</title>
        </head>
        <body>
          <main>
            <article>
              <h1>Ronaldo on Instagram</h1>
              <img src="https://example.com/ronaldo.jpg" alt="Ronaldo on court">
              <p>Miami open 🎾 Que semana incrível! Obrigado, @itau</p>
            </article>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://www.instagram.com/ronaldo/p/DWh3vbdkXI1/", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["markdown"]).to include("Miami open")
      expect(payload["markdown"]).not_to include("Access notice: Instagram login required")
    end
  end

  it "preserves every visible Instagram comment from the public post text" do
    additional_comments = (1..12).map do |index|
      <<~HTML
        <div>commenter_#{index}</div>
        <div>#{index}m</div>
        <div>Visible comment #{index} remains distinct.</div>
        <div>Like</div>
        <div>Reply</div>
      HTML
    end.join
    html = <<~HTML
      <html>
        <head>
          <title>Instagram</title>
          <meta property="og:title" content="Ronaldo on Instagram: &quot;Miami open 🎾 Que semana incrível! Obrigado, @itau&quot;">
          <meta property="og:description" content="153.9K likes, 1.3K comments - ronaldo on March 30, 2026: &quot;Miami open 🎾 Que semana incrível! Obrigado, @itau&quot;.">
          <meta property="og:image" content="https://example.com/ronaldo.jpg">
        </head>
        <body>
          <main>
            <article>
            <div>ronaldo</div>
            <div>4d</div>
            <div>Miami open 🎾 Que semana incrível! Obrigado, @itau</div>
            <div>douglas_kadosh</div>
            <div>2m</div>
            <div>Sim meu 09, acho que já tá na hora de parar de brincar né?</div>
            <div>Like</div>
            <div>Reply</div>
            <div>k.le.bersou</div>
            <div>25m</div>
            <div>Esse Daniel parece um fantasma.👻</div>
            <div>Like</div>
            <div>Reply</div>
            #{additional_comments}
            <div>153.9K</div>
            <div>1.3K</div>
            <div>4 days ago</div>
            <div>Log in to like or comment.</div>
            </article>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://www.instagram.com/ronaldo/p/DWh3vbdkXI1/", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)
      markdown = payload["markdown"]

      expect(payload).to include("contentType" => "social", "socialKind" => "post", "platform" => "Instagram", "handle" => "@ronaldo")
      expected_comments = [
        ["douglas_kadosh", "Sim meu 09, acho que já tá na hora de parar de brincar né?"],
        ["k.le.bersou", "Esse Daniel parece um fantasma.👻"]
      ] + (1..12).map { |index| ["commenter_#{index}", "Visible comment #{index} remains distinct."] }
      expected_comments.each do |user, text|
        expect(markdown.lines.count { |line| line.strip == user.gsub('_', '\\_') }).to eq(1)
        expect(markdown.lines.count { |line| line.strip == text }).to eq(1)
      end
      positions = expected_comments.map { |_user, text| markdown.index(text) }
      expect(positions).to eq(positions.sort)
      expect(markdown).not_to include("Access notice: Instagram login required")
    end
  end

  it "flags human verification gates" do
    html = <<~HTML
      <html>
        <head><title>Robot or human?</title></head>
        <body>
          <main>
            <h1>Robot or human?</h1>
            <p>Activate and hold the button to confirm that you're human.</p>
          </main>
        </body>
      </html>
    HTML

    with_page(html) do |page|
      payload = extract_payload(page)

      expect(payload["markdown"]).to include("Activate and hold the button to confirm that you're human.")
      expect_content_type(payload, "interstitial")
      expect_warnings(payload, include: %w[human_verification_interstitial bot_or_access_interstitial])
    end
  end

  it "flags press-and-hold human verification gates" do
    html = <<~HTML
      <html>
        <head><title>Access to this page has been denied</title></head>
        <body>
          <div id="px-captcha-wrapper" dir="auto">
            <p><img height="40" src="https://www.zillowstatic.com/s3/pfs/static/z-logo-default.svg" alt="Logo"></p>
            <p>Press &amp; Hold to confirm you are<br>a human (and not a bot).</p>
            <p>Reference ID 5a1eb63e-7789-11f1-ba2c-bbc8a3f3072d</p>
          </div>
        </body>
      </html>
    HTML

    with_url_page("https://www.zillow.com/homedetails/3500-S-Washington-St-Arlington-VA-22227/52117882_zpid/", html) do |page|
      payload = extract_payload(page)

      expect(payload["markdown"]).to include("Press & Hold to confirm you are")
      expect_warnings(
        payload,
        include: %w[human_verification_interstitial bot_or_access_interstitial],
        exclude: "url_content_mismatch"
      )
    end
  end

  it "does not classify phone press-and-hold help as human verification" do
    resources = (1..7).map do |index|
      %(<li><a href="/resources/#{index}">CaptionCall mobile resource #{index}</a></li>)
    end.join
    html = <<~HTML
      <!doctype html>
      <html>
        <head><title>How to Check Voicemail | CaptionCall</title></head>
        <body>
          <div class="ginput_recaptchav3" style="display: none"><input name="g-recaptcha-response"></div>
          <main>
            <article>
              <h1>How to Check Voicemail</h1>
              <p>CaptionCall Mobile provides public instructions and accessibility resources for checking voicemail on supported phones.</p>
              <h2>Open your voicemail</h2>
              <ul><li>Press and hold the 1 on the CaptionCall Mobile dialer (or dial *97).</li></ul>
              <h2>Related resources</h2>
              <ul>#{resources}</ul>
            </article>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://caption.example.test/help/mobile", html) do |page|
      payload = extract_payload(page)

      expect(payload["contentType"]).not_to eq("interstitial")
      expect_warnings(payload, exclude: %w[human_verification_interstitial bot_or_access_interstitial interstitial])
      (1..7).each do |index|
        expect(payload["markdown"]).to include("https://caption.example.test/resources/#{index}")
      end
    end
  end

  it "flags help-us-protect verification pages" do
    html = <<~HTML
      <html>
        <head><title>Just a moment...</title></head>
        <body>
          <main>
            <h1>Help Us Protect Glassdoor</h1>
            <p>Please help us protect Glassdoor by verifying that you're a real person.</p>
            <p>If you continue to see this message, please review our Help Center article.</p>
          </main>
        </body>
      </html>
    HTML

    with_page(html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      # "Just a moment..." title triggers Cloudflare challenge detection;
      # challenge content is simplified to sentinel-only output
      expect(payload["markdown"]).to include("Challenge: Cloudflare")
      expect(payload["warnings"]).to include("cloudflare_challenge_page")
      expect(payload["warnings"]).to include("bot_or_access_interstitial")
    end
  end

  it "flags blocked request shells" do
    html = <<~HTML
      <html>
        <head><title>Blocked - Indeed.com</title></head>
        <body>
          <main>
            <h1>Request Blocked</h1>
            <p>You have been blocked.</p>
            <p>Troubleshooting Cloudflare Errors</p>
          </main>
        </body>
      </html>
    HTML

    with_page(html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["markdown"]).to include("# Blocked - Indeed.com")
      expect(payload["warnings"]).to include("access_error_interstitial")
      expect(payload["warnings"]).to include("bot_or_access_interstitial")
    end
  end

  it "does not flag substantial public government pages that mention access errors incidentally" do
    paragraphs = (1..8).map do |index|
      <<~HTML
        <p>Section #{index} explains how agencies publish official notices, public comments, effective dates, regulatory history, docket identifiers, and compliance deadlines for readers who need a complete administrative record.</p>
      HTML
    end.join

    html = <<~HTML
      <html>
        <head><title>Public notice access guidance</title></head>
        <body>
          <main>
            <article>
              <h1>Public notice access guidance</h1>
              <p>Some users may see an access denied message when a stale cache entry is requested, but this public government page remains available.</p>
              #{paragraphs}
            </article>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://www.federalregister.gov/documents/2024/01/01/public-notice-access-guidance", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["contentType"]).to eq("article")
      expect(payload["markdown"]).to include("Section 1 explains how agencies publish official notices")
      expect(payload["warnings"]).not_to include("access_error_interstitial")
      expect(payload["warnings"]).not_to include("bot_or_access_interstitial")
    end
  end

  it "flags regional selector shells" do
    html = <<~HTML
      <html>
        <head><title>Best Buy International: Select your Country</title></head>
        <body>
          <main>
            <h1>Hello!</h1>
            <h2>Choose a country.</h2>
            <p>Shopping in the U.S.?</p>
          </main>
        </body>
      </html>
    HTML

    with_page(html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["markdown"]).to include("Choose a country.")
      expect(payload["warnings"]).to include("regional_selector_interstitial")
    end
  end

  it "flags unsupported browser shells without trending noise" do
    html = <<~HTML
      <html>
        <head><title>Ticketmaster: Buy Verified Tickets for Concerts, Sports, Theater and Events</title></head>
        <body>
          <main>
            <p>Your browser is not supported. For the best experience, use any of these supported browsers: Chrome, Firefox, Safari, Edge.</p>
            <h2>Trending Searches</h2>
            <p>Showing slide 1, 2, 3, 4 and 5 of 10</p>
          </main>
        </body>
      </html>
    HTML

    with_page(html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["markdown"]).to include("Your browser is not supported.")
      expect(payload["markdown"]).not_to include("Trending Searches")
      expect(payload["warnings"]).to include("browser_support_interstitial")
    end
  end

  it "flags not-found shells and compacts them into a short summary" do
    html = <<~HTML
      <html>
        <head><title>404 - Page Not Found</title></head>
        <body>
          <main>
            <h1>Page Not Found</h1>
            <p>Sorry, we can't find the page you requested.</p>
            <p>Return to the home page.</p>
          </main>
        </body>
      </html>
    HTML

    with_page(html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["markdown"]).to include("Page Not Found")
      expect(payload["warnings"]).to include("not_found_interstitial")
    end
  end

  it "preserves every safe unique record from explicit continuous tickers on not-found pages" do
    records = (1..25).map do |number|
      "<a style='display:inline-block;width:220px' href='/updates/#{number}'>Public update headline #{number}</a>"
    end.join
    html = <<~HTML
      <html><head><title>404 - Story not found</title><style>
        .ticker-window { width: 320px; overflow-x: hidden; }
        .react-marquee-box { display: flex; width: 12000px; }
        .ticker-prefix, .ticker-track { display: flex; flex: none; }
        .ticker-prefix { width: 440px; }
        .ticker-track { width: 10000px; }
      </style></head><body>
        <main><h1>Story not found</h1><p>The requested story is no longer available.</p></main>
        <section data-breaking-news='true' class='ticker-window'>
          <h2>Live public updates</h2>
          <div class='react-marquee-box'>
            <div class='ticker-prefix'>
              <a style='display:inline-block;width:220px' href='/updates/1'>Public update headline 1</a>
              <a style='display:inline-block;width:220px' href='/updates/2'>Public update headline 2</a>
            </div>
            <div class='ticker-track'>#{records}#{records}</div>
          </div>
          <a href='javascript:openStory()'>Unsafe public update action</a>
          <a href='https://user:secret@private.example/record'>Credential update action</a>
          <a href='data:text/plain,unsafe'>Data update action</a>
          <div hidden><a href='/hidden'>Hidden ticker update</a></div>
          <div class='carousel'><a href='/inactive'>Inactive carousel update</a></div>
        </section>
        <section data-breaking-news='true' hidden>
          <a href='/hidden-root/1'>Hidden root update one</a>
          <a href='/hidden-root/2'>Hidden root update two</a>
          <a href='/hidden-root/3'>Hidden root update three</a>
        </section>
        <div inert>
          <section data-breaking-news='true'>
            <a href='/hidden-ancestor/1'>Hidden ancestor update one</a>
            <a href='/hidden-ancestor/2'>Hidden ancestor update two</a>
            <a href='/hidden-ancestor/3'>Hidden ancestor update three</a>
          </section>
        </div>
      </body></html>
    HTML

    with_url_page("https://publisher.example/missing-story", html) do |page|
      before = page.evaluate("document.body.outerHTML")
      page.add_script_tag(content: not_found_context_test_source)
      payload = page.evaluate(<<~JAVASCRIPT)
        (function() {
          var represented = [1, 2];
          var links = represented.map(function(number) {
            return '<li><a href="https://publisher.example/updates/' + number + '">' +
              'Public update headline ' + number + '</a></li>';
          }).join('');
          var markdown = represented.map(function(number) {
            return '- [Public update headline ' + number + ']' +
              '(https://publisher.example/updates/' + number + ')';
          }).join(String.fromCharCode(10)) + String.fromCharCode(10) + String.fromCharCode(10) +
            '## 404 - Story not found' + String.fromCharCode(10) + String.fromCharCode(10) +
            'The requested story is no longer available.';
          return window.__supplementNotFoundTickerRecordsForTest({
            html: '<ul>' + links + '</ul><h2>404 - Story not found</h2>' +
              '<p>The requested story is no longer available.</p>',
            markdown: markdown,
            textContent: markdown
          });
        })()
      JAVASCRIPT

      expect(payload["markdown"]).to include("requested story is no longer available")
      (1..25).each do |number|
        expect(payload["markdown"].scan("https://publisher.example/updates/#{number})").length).to eq(1)
        expect(payload["html"].scan(%(href="https://publisher.example/updates/#{number}")).length).to eq(1)
      end
      expect(payload["markdown"]).not_to include("javascript:", "private.example", "data:text", "/hidden", "/inactive")
      expect(page.evaluate("document.body.outerHTML")).to eq(before)
    end
  end

  it "rejects hidden, inactive, unsafe, and control-only ticker records at the classifier boundary" do
    records = (1..3).map do |number|
      hidden = number == 1 ? "<span hidden>Hidden label text</span>" : ""
      "<a href='/safe/#{number}'>Safe public update #{number}#{hidden}</a>"
    end.join
    large_records = (1..150).map do |number|
      "<a href='/large/#{number}'>Large public update #{number}</a>"
    end.join
    html = <<~HTML
      <main>
        <section id='safe' role='marquee'>
          #{records}
          <a href='https://user:secret@private.example/update'>Private update</a>
          <a href='/hidden-label'><span hidden>Hidden label only</span></a>
          <a href='/aria-hidden-label'><span aria-hidden='true'>ARIA-hidden label only</span></a>
        </section>
        <section id='uppercase-marquee' role='MARQUEE presentation'>#{records}</section>
        <section id='swiper' class='swiper-slide'>#{records}</section>
        <section id='carousel' class='carousel-container'>#{records}</section>
        <section id='tab' role='tab'>#{records}</section>
        <section id='tablist' role='tablist'>#{records}</section>
        <section id='uppercase-tab' role='TAB presentation'>#{records}</section>
        <section id='panel' role='tabpanel'>#{records}</section>
        <section id='closed' data-state='closed'>#{records}</section>
        <section id='unselected' aria-selected='false'>#{records}</section>
        <section id='display-none' style='display:none'>#{records}</section>
        <div inert><section id='hidden-ancestor'>#{records}</section></div>
        <section id='controls'>
          <a href='/subscribe'>Subscribe</a><a href='/newsletter'>Newsletter</a><a href='/register'>Register</a>
        </section>
        <section id='static-news' data-breaking-news='true'>#{records}</section>
        <section id='static-ticker' class='ticker'>#{records}</section>
        <section id='static-data-ticker' data-ticker>#{records}</section>
        <section id='static-react-marquee' class='react-marquee-box'>#{records}</section>
        <section id='large' class='react-marquee-box'>#{large_records}#{large_records}</section>
      </main>
    HTML

    with_url_page("https://publisher.example/missing-story", html) do |page|
      page.add_script_tag(content: not_found_context_test_source)
      decisions = page.evaluate(<<~JAVASCRIPT)
        ({
          safe: window.__collectContinuousTickerRecords(document.querySelector('#safe')).map(function(record) {
            return { url: record.url, text: record.text };
          }),
          uppercaseMarquee: window.__collectContinuousTickerRecords(document.querySelector('#uppercase-marquee')).length,
          swiper: window.__continuousTickerUnavailableNode(document.querySelector('#swiper')),
          carousel: window.__continuousTickerUnavailableNode(document.querySelector('#carousel')),
          tab: window.__continuousTickerUnavailableNode(document.querySelector('#tab')),
          tablist: window.__continuousTickerUnavailableNode(document.querySelector('#tablist')),
          uppercaseTab: window.__continuousTickerUnavailableNode(document.querySelector('#uppercase-tab')),
          panel: window.__continuousTickerUnavailableNode(document.querySelector('#panel')),
          closed: window.__continuousTickerUnavailableNode(document.querySelector('#closed')),
          unselected: window.__continuousTickerUnavailableNode(document.querySelector('#unselected')),
          displayNone: window.__continuousTickerUnavailableNode(document.querySelector('#display-none')),
          hiddenAncestor: window.__continuousTickerRootUnavailable(document.querySelector('#hidden-ancestor')),
          controls: window.__collectContinuousTickerRecords(document.querySelector('#controls')),
          staticNews: window.__continuousTickerToken(document.querySelector('#static-news')),
          staticTicker: window.__continuousTickerToken(document.querySelector('#static-ticker')),
          staticDataTicker: window.__collectContinuousTickerRecords(document.querySelector('#static-data-ticker')),
          staticReactMarquee: window.__collectContinuousTickerRecords(document.querySelector('#static-react-marquee')),
          large: window.__collectContinuousTickerRecords(document.querySelector('#large')).length,
          prefix: (function() {
            var records = [1, 2, 3, 4, 5].map(function(number) {
              var text = 'Public update ' + number;
              var url = 'https://publisher.example/updates/' + number;
              return { text: text, url: url, key: window.__continuousTickerRecordKey(text, url) };
            });
            var markdown = '## Updates\\n\\n- [Public update 1](https://publisher.example/updates/1)\\n' +
              '- [Public update 2](https://publisher.example/updates/2)\\n\\n## 404\\n\\nMissing page';
            return window.__insertMissingTickerRecordLines(markdown, records, records.slice(2));
          })(),
          split: (function() {
            var records = [1, 2, 3, 4, 5].map(function(number) {
              var text = 'Public update ' + number;
              var url = 'https://publisher.example/updates/' + number;
              return { text: text, url: url, key: window.__continuousTickerRecordKey(text, url) };
            });
            var markdown = [
              '- [Public update 1](https://publisher.example/updates/1)',
              '',
              '## 404',
              '',
              '- [Public update 2](https://publisher.example/updates/2)'
            ].join(String.fromCharCode(10));
            return {
              before: markdown,
              after: window.__insertMissingTickerRecordLines(markdown, records, records.slice(2))
            };
          })(),
          noPrefix: (function() {
            var records = [1, 2, 3].map(function(number) {
              var text = 'Public update ' + number;
              var url = 'https://publisher.example/updates/' + number;
              return { text: text, url: url, key: window.__continuousTickerRecordKey(text, url) };
            });
            var markdown = '## 404' + String.fromCharCode(10) + String.fromCharCode(10) + 'Missing page';
            return {
              before: markdown,
              after: window.__insertMissingTickerRecordLines(markdown, records, records)
            };
          })(),
          htmlBoundaries: (function() {
            var records = [1, 2, 3].map(function(number) {
              var text = 'Public update ' + number;
              var url = 'https://publisher.example/updates/' + number;
              return { text: text, url: url, key: window.__continuousTickerRecordKey(text, url) };
            });
            var represented = new Set(records.slice(0, 2).map(function(record) { return record.key; }));
            var supplement = function(html) {
              var repaired = window.__supplementNotFoundTickerHtml(html, records, represented, records.slice(2));
              if (!repaired) return { html: repaired, nested: null };
              var container = document.createElement('div');
              container.innerHTML = repaired;
              var link = container.querySelector('a[href="https://publisher.example/updates/3"]');
              return { html: repaired, nested: !!(link && link.parentElement.closest('a')) };
            };
            return {
              anchorWrap: supplement('<a href="/updates/1"><article>Public update 1</article></a>' +
                '<a href="/updates/2">Public update 2</a>'),
              articleWrap: supplement('<article><a href="/updates/1">Public update 1</a></article>' +
                '<article><a href="/updates/2">Public update 2</a></article>'),
              duplicate: supplement('<a href="/updates/1">Public update 1</a>' +
                '<a href="/updates/2">Public update 2</a>' +
                '<a href="/updates/1">Public update 1</a>'),
              noncontiguous: supplement('<a href="/updates/1">Public update 1</a>' +
                '<a href="/other">Other reference</a>' +
                '<a href="/updates/2">Public update 2</a>'),
              splitByHeading: supplement('<p><a href="/updates/1">Public update 1</a></p>' +
                '<h2>404 unavailable</h2>' +
                '<p><a href="/updates/2">Public update 2</a></p>'),
              splitByProse: supplement('<p><a href="/updates/1">Public update 1</a></p>' +
                '<p>Other page context</p>' +
                '<p><a href="/updates/2">Public update 2</a></p>')
            };
          })()
        })
      JAVASCRIPT

      expect(decisions.fetch("safe")).to eq((1..3).map do |number|
        { "url" => "https://publisher.example/safe/#{number}", "text" => "Safe public update #{number}" }
      end)
      expect(decisions.fetch("uppercaseMarquee")).to eq(3)
      expect(decisions.values_at("swiper", "carousel", "tab", "tablist", "uppercaseTab", "panel", "closed", "unselected", "displayNone", "hiddenAncestor"))
        .to all(be(true))
      expect(decisions.fetch("controls")).to eq([])
      expect(decisions.fetch("staticNews")).to be(false)
      expect(decisions.fetch("staticTicker")).to be(false)
      expect(decisions.fetch("staticDataTicker")).to eq([])
      expect(decisions.fetch("staticReactMarquee")).to eq([])
      expect(decisions.fetch("large")).to eq(150)
      prefix = decisions.fetch("prefix")
      (1..5).each do |number|
        expect(prefix.scan("https://publisher.example/updates/#{number}").length).to eq(1)
      end
      expect(prefix.lines.grep(/^- \[/).map(&:strip)).to eq((1..5).map do |number|
        "- [Public update #{number}](https://publisher.example/updates/#{number})"
      end)
      expect(prefix.index("/updates/5")).to be < prefix.index("## 404")
      expect(decisions.dig("split", "after")).to eq(decisions.dig("split", "before"))
      expect(decisions.dig("noPrefix", "after")).to eq(decisions.dig("noPrefix", "before"))
      expect(decisions.dig("htmlBoundaries", "duplicate", "html")).to be_nil
      expect(decisions.dig("htmlBoundaries", "noncontiguous", "html")).to be_nil
      expect(decisions.dig("htmlBoundaries", "splitByHeading", "html")).to be_nil
      expect(decisions.dig("htmlBoundaries", "splitByProse", "html")).to be_nil
      %w[anchorWrap articleWrap].each do |shape|
        repaired = decisions.dig("htmlBoundaries", shape, "html")
        expect(repaired.scan('href="https://publisher.example/updates/3"').length).to eq(1)
        expect(decisions.dig("htmlBoundaries", shape, "nested")).to be(false)
      end
    end
  end

  it "does not supplement continuous ticker records on ordinary article pages" do
    records = (1..8).map do |number|
      "<a href='/updates/#{number}'>Unrelated site ticker headline #{number}</a>"
    end.join
    html = <<~HTML
      <html><head><title>Detailed public infrastructure report</title></head><body>
        <main><article><h1>Detailed public infrastructure report</h1>
          <p>This report explains the completed infrastructure project and its effects on communities across the region.</p>
          <p>Engineers documented the construction work, safety checks, environmental review, and public consultation in detail.</p>
          <p>The final project remains available to residents and visitors throughout the year.</p>
        </article></main>
        <aside data-breaking-news='true'>#{records}</aside>
      </body></html>
    HTML

    with_url_page("https://publisher.example/reports/infrastructure", html) do |page|
      before = page.evaluate("document.body.outerHTML")
      payload = extract_payload(page)
      expect_content_type(payload, "article")
      expect(payload["markdown"]).not_to include("/updates/8")
      expect(page.evaluate("document.body.outerHTML")).to eq(before)
    end
  end

  it "flags publisher unavailable pages as interstitials" do
    html = <<~HTML
      <html>
        <head><title>Page Unavailable | Springer Nature Link</title></head>
        <body>
          <header class="eds-c-header">
            <a href="https://link.springer.example/" data-test="springerlink-logo">
              <img src="/logo.svg" alt="Springer Nature Link">
            </a>
          </header>
          <div class="eds-c-header__expander eds-c-header__expander--search">
            <h2>Search</h2>
          </div>
          <div class="eds-c-header__expander eds-c-header__expander--menu">
            <h2>Navigation</h2>
            <ul>
              <li><a href="/journals/">Find a journal</a></li>
              <li><a href="https://www.springernature.example/authors">Publish with us</a></li>
              <li><a href="/home/">Track your research</a></li>
            </ul>
          </div>
        </body>
      </html>
    HTML

    with_url_page("https://publisher.example/articles/10.1186/s12859-023-05456-7", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["contentType"]).to eq("interstitial")
      expect(payload["markdown"]).to include("# Page Unavailable | Springer Nature Link")
      expect(payload["warnings"]).to include("site_unavailable_interstitial")
    end
  end

  it "flags soft-404 bodies after navigation chrome" do
    html = <<~HTML
      <html>
        <head><title>RubyDoc.info: Documenting RubyGems, Stdlib, and GitHub Projects</title></head>
        <body>
          <nav>
            <a href="/">Home</a>
            <a href="/current">Current</a>
            <a href="/downloads">Downloads</a>
          </nav>
          <main>
            <h2>We're sorry, but that page cannot be found.</h2>
            <a href="https://ruby-doc.org/">Return to the main page</a>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://www.ruby-doc.org/3.4.2/", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["markdown"]).to include("We're sorry, but that page cannot be found")
      expect(payload["warnings"]).to include("not_found_interstitial")
    end
  end

  it "flags structured publisher not-found shells despite heavy chrome" do
    html = <<~HTML
      <html>
        <head><title>Error (Publisher Platform)</title></head>
        <body>
          <header>
            <a href="/">Publisher Home</a>
            <a href="/journals">Journals A-Z</a>
            <a href="/action/ssostart">Access through institution</a>
            <a href="/login">Log In</a>
          </header>
          <main>
            <div class="container">
              <h1>Page Not Found</h1>
              <h3>We're sorry, but the page you requested cannot be accessed for one of the following reasons:</h3>
              <ul>
                <li>The address was typed incorrectly</li>
                <li>The page does not exist</li>
                <li>The page cannot be found</li>
                <li>Cookies and/or Javascript may need to be enabled to view this page</li>
              </ul>
              <h3>Please try one of the following pages to find what you're looking for:</h3>
              <ul>
                <li><a href="/">Publications Home Page</a></li>
                <li><a href="/search/advanced">Publications Search</a></li>
                <li><a href="/help">Help</a></li>
              </ul>
            </div>
          </main>
          <footer>
            <a href="/references">References</a>
            <a href="/subscriptions">Subscription Information</a>
          </footer>
        </body>
      </html>
    HTML

    with_url_page("https://publisher.example/doi/10.1021/example", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["markdown"]).to include("page you requested cannot")
      expect(payload["warnings"]).to include("not_found_interstitial")
    end
  end

  it "classifies link-heavy not-found pages as interstitials" do
    related_links = 8.times.map do |index|
      <<~LINK
        <li><a href="/resource/#{index}">Related standards resource #{index}</a> - Guidance and standards updates.</li>
      LINK
    end.join("\n")
    html = <<~HTML
      <html>
        <head><title>ANSI Introduction</title></head>
        <body>
          <main>
            <section class="score-pic-stripe" style="background-image: url('/404-hero.jpg')">
              <h1>The page you are looking for can't be found.</h1>
              <p>We're sorry for the error. Try using the search bar above to find what you're looking for.</p>
              <p>If you're still having trouble, let us know the issue by emailing the web team. The page may have moved, the address may have changed, or the resource may no longer be available in this section. These navigation suggestions are provided only to help visitors recover from the missing page.</p>
            </section>
            <aside class="related-guidance">
              <ul>
                #{related_links}
              </ul>
            </aside>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://www.standards.example/about/ansi-introduction", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["contentType"]).to eq("interstitial")
      expect(payload["markdown"]).to include("The page you are looking for can't be found")
      expect(payload["warnings"]).to include("not_found_interstitial")
    end
  end

  it "flags court-style soft 404 pages where the error is in the opinion title" do
    html = <<~HTML
      <html>
        <head>
          <title>404 U.S. ___, Page Not Found - Court Search</title>
          <meta property="og:site_name" content="Court Search">
        </head>
        <body>
          <main>
            <h1>Court Search</h1>
            <h2>404 U.S. ___, Page Not Found</h2>
            <p>Sorry, that page does not exist.</p>
            <ul>
              <li><a href="/opinion/">Do a new search in the Case Law database</a></li>
              <li><a href="/citation/">Try citation lookup</a></li>
              <li><a href="/contact/">Let us know it is missing</a></li>
              <li><a href="/faq/">Learn about neutral citations</a></li>
            </ul>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://courts.example/opinion/1/", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["markdown"]).to include("404 U.S. ___, Page Not Found")
      expect(payload["warnings"]).to include("not_found_interstitial")
    end
  end

  it "flags short repository project pages that redirect to a root not-found shell" do
    html = <<~HTML
      <html>
        <head><title>OSF</title></head>
        <body>
          <main>
            <h1>OSF</h1>
            <p>Not found.</p>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://repository.example.org/", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["markdown"]).to include("Not found")
      expect(payload["warnings"]).to include("not_found_interstitial")
      expect(payload["warnings"]).not_to include("short_extraction")
    end
  end

  it "flags unavailable dataset record interstitials" do
    html = <<~HTML
      <html>
        <head><title>Dataset unavailable</title></head>
        <body>
          <main>
            <p>The dataset you are trying to view is not available.</p>
            <p>If you are the owner of this dataset, you may visit your My datasets page to check the status of your submission.</p>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://repository.example.org/dataset/doi:10.5061/example.dead", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["warnings"]).to include("not_found_interstitial")
    end
  end

  it "flags DOI system records that cannot be found as not-found interstitials" do
    html = <<~HTML
      <html>
        <head><title>DOI Not Found</title></head>
        <body>
          <main>
            <p>This DOI cannot be found in the DOI System. Possible reasons are:</p>
            <ul>
              <li><a href="https://www.doi.org/">DOI.ORG homepage</a> - You can try to search again from</li>
            </ul>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://doi.example.org/10.5061/example.dead", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["warnings"]).to include("not_found_interstitial")
      expect(payload["warnings"]).not_to include("short_extraction")
    end
  end

  it "flags non-English legal not-found pages as not-found interstitials" do
    html = <<~HTML
      <html>
        <head><title>e-Gov 法令検索</title></head>
        <body>
          <main>
            <div class="titleArea"><div class="titleMsg">ご利用のページが見つかりません</div></div>
            <div class="wrap1"><div class="wrap2"><div class="detailsMsg">
              <p>アクセスいただいたURLには、ページまたはファイルが存在しません。</p>
              <p>・移動または削除されている場合があります。</p>
              <p>・ご入力いただいたURLに誤りがある可能性があります。</p>
              <p>・一時的に利用できない状況にある可能性があります。</p>
            </div></div></div>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://laws.e-gov.example/awcontents/41500AC0001E0010000/i_00001.html", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["contentType"]).to eq("interstitial")
      expect(payload["warnings"]).to include("not_found_interstitial")
    end
  end

  it "does not flag valid repository records as not-found interstitials" do
    html = <<~HTML
      <html>
        <head>
          <title>Valid climate observations dataset</title>
          <script type="application/ld+json">
          {"@context":"https://schema.org","@type":"Dataset","name":"Valid climate observations dataset"}
          </script>
        </head>
        <body>
          <main>
            <article>
              <h1>Valid climate observations dataset</h1>
              <p>This dataset is available for download and contains station observations, DOI metadata, authorship, version history, methods, and repository files.</p>
              <p>Researchers can cite the record, inspect the data files, and reuse the observations under the repository license.</p>
            </article>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://repository.example.org/dataset/doi:10.5061/example.live", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["markdown"]).to include("Valid climate observations dataset")
      expect(payload["warnings"]).not_to include("not_found_interstitial")
    end
  end

  it "does not flag valid non-English legal documents as not-found interstitials" do
    html = <<~HTML
      <html>
        <head><title>民法 | e-Gov 法令検索</title></head>
        <body>
          <main>
            <article>
              <h1>民法</h1>
              <p>第一条　私権は、公共の福祉に適合しなければならない。</p>
              <p>権利の行使及び義務の履行は、信義に従い誠実に行わなければならない。</p>
              <p>この法令本文は、公布された条文、附則、改正履歴、施行日、引用情報を含む公式な法令データとして提供されています。</p>
            </article>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://laws.e-gov.example/document/129AC0000000089", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["markdown"]).to include("# 民法")
      expect(payload["warnings"]).not_to include("not_found_interstitial")
    end
  end

  it "does not flag real court opinions that mention legal citations" do
    paragraphs = (1..6).map do |index|
      <<~HTML
        <p>Opinion paragraph #{index} discusses the record, the applicable standard, counsel arguments,
        and the court's reasoning in a published case-law decision with enough continuous prose to be
        treated as primary legal content.</p>
      HTML
    end.join

    html = <<~HTML
      <html>
        <head>
          <title>Brown v. Board of Education - Court Search</title>
          <meta property="og:site_name" content="Court Search">
        </head>
        <body>
          <main>
            <article>
              <h1>Brown v. Board of Education</h1>
              <p>347 U.S. 483</p>
              #{paragraphs}
            </article>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://courts.example/opinion/105221/brown-v-board-of-education/", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["markdown"]).to include("Brown v. Board of Education")
      expect(payload["warnings"]).not_to include("not_found_interstitial")
    end
  end

  it "flags retired service shutdown notices as access interstitials" do
    html = <<~HTML
      <html>
        <head><title>Example Legal Research</title></head>
        <body>
          <main>
            <h1>Example Legal Research</h1>
            <p>This service is no longer available, but we appreciate you being a part of it.</p>
            <p>For legal research, please visit our new research platform.</p>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://research.example/case/brown-v-board", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["markdown"]).to include("This service is no longer available")
      expect(payload["warnings"]).to include("access_error_interstitial")
      expect_content_type(payload, "interstitial")
    end
  end

  it "keeps substantial articles about retired services as articles" do
    sections = (1..8).map do |index|
      <<~HTML
        <section>
          <h2>Migration phase #{index}</h2>
          <p>Phase #{index} documents the replacement architecture, compatibility boundaries, migration checkpoints, operational metrics, validation evidence, rollout controls, and recovery procedures for engineering teams moving their production workloads.</p>
          <p><a href="/migration/#{index}">Review migration phase #{index}</a></p>
        </section>
      HTML
    end.join

    html = <<~HTML
      <html>
        <head><title>Planning a service retirement</title></head>
        <body>
          <main>
            <article>
              <h1>Planning a service retirement</h1>
              <p>The legacy service is no longer available after a carefully managed migration.</p>
              #{sections}
            </article>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://example.com/guides/service-retirement", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect_content_type(payload, "article")
      expect(payload["warnings"]).not_to include("access_error_interstitial")
    end
  end

  it "does not flag substantial articles that mention not-found text incidentally" do
    sections = (1..8).map do |index|
      <<~HTML
        <section>
          <h2>Diagnostic step #{index}</h2>
          <p>Section #{index} explains routing diagnostics, fallback handlers, cache invalidation, deployment checks, and how teams should investigate production behavior with structured logs, metrics, trace identifiers, release metadata, and reproducible request samples.</p>
          <p><a href="/routing/#{index}">Read the routing guide #{index}</a></p>
        </section>
      HTML
    end.join

    html = <<~HTML
      <html>
        <head><title>Reliable routing diagnostics</title></head>
        <body>
          <main>
            <article>
              <h1>Reliable routing diagnostics</h1>
              <p>A template may say Page not found when a route is missing, but this article is about preventing that outcome in production systems.</p>
              #{sections}
            </article>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://example.com/blog/reliable-routing-diagnostics", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["markdown"]).to include("Reliable routing diagnostics")
      expect(payload["warnings"]).not_to include("not_found_interstitial")
    end
  end

  it "flags empty SPA shells as empty extractions" do
    html = <<~HTML
      <html>
        <head><title>Hashnode</title></head>
        <body>
          <div id="__next"></div>
          <script src="/static/chunks/app.js"></script>
        </body>
      </html>
    HTML

    with_url_page("https://hashnode.io/", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["warnings"]).to include("empty_extraction")
    end
  end

  it "flags short generic error-title shells" do
    html = <<~HTML
      <html>
        <head><title>Example Archive: Error</title></head>
        <body>
          <main>
            <ul>
              <li><a href="/apps/ios">Wayback Machine (iOS)</a></li>
              <li><a href="/apps/android">Wayback Machine (Android)</a></li>
              <li><a href="/explore">Explore the Collections</a></li>
            </ul>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://example.test/details/missing_item", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["warnings"]).to include("access_error_interstitial")
      expect_content_type(payload, "interstitial")
    end
  end

  it "flags subscription and login-required pages as access interstitials" do
    html = <<~HTML
      <html>
        <head><title>Rare Entry | Example Dictionary</title></head>
        <body>
          <main>
            <h1>Rare Entry</h1>
            <p>Subscribe to continue reading this entry.</p>
            <p>Institutional access is available.</p>
          </main>
        </body>
      </html>
    HTML

    with_page(html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["markdown"]).to include("Rare Entry")
      expect(payload["warnings"]).to include("subscription_interstitial")
    end
  end

  it "does not flag rich public pages with incidental subscription access copy" do
    html = <<~HTML
      <html>
        <head><title>The Shawshank Redemption Reviews | Example Reviews</title></head>
        <body>
          <main>
            <article>
              <h1>The Shawshank Redemption</h1>
              <p>Wrongly convicted, Andy Dufresne is sentenced to two consecutive life terms in Shawshank prison for the murders of his wife and her lover.</p>
              <p>The film follows Andy as he learns to survive inside the prison, builds friendships, and keeps hope alive over many years.</p>
              <section>
                <h2>Critic Reviews</h2>
                <p>Universal acclaim based on twenty-two critic reviews, with praise for Frank Darabont's direction and the performances by Tim Robbins and Morgan Freeman.</p>
                <a href="/movie/the-shawshank-redemption/critic-reviews">Read critic reviews</a>
              </section>
              <section>
                <h2>User Reviews</h2>
                <p>Audiences describe the drama as moving, humane, and memorable, with many reviews highlighting the long friendship at the center of the story.</p>
                <a href="/movie/the-shawshank-redemption/user-reviews">Read user reviews</a>
                <a href="/movie/the-shawshank-redemption/cast">View cast</a>
                <a href="/movie/the-shawshank-redemption/details">View details</a>
              </section>
            </article>
            <aside>
              <p>Read with a subscription for premium industry newsletters.</p>
            </aside>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://www.example-reviews.test/movie/the-shawshank-redemption", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["markdown"]).to include("Wrongly convicted, Andy Dufresne")
      expect(payload["warnings"]).not_to include("subscription_interstitial")
    end
  end

  it "flags generic auth pages such as password-reset screens" do
    html = <<~HTML
      <html>
        <head><title>Reset your password</title></head>
        <body>
          <main>
            <h1>Reset your password</h1>
            <p>Check your email for a reset link or sign in to continue.</p>
          </main>
        </body>
      </html>
    HTML

    with_page(html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["markdown"]).to include("Reset your password")
      expect(payload["warnings"]).to include("auth_or_login_interstitial")
    end
  end

  it "flags login interstitials returned for browse paths" do
    html = <<~HTML
      <html>
        <head><title>Log in - Example Community</title></head>
        <body>
          <main>
            <h1>Log in</h1>
            <p>Connect an account to browse your community projects.</p>
            <a href="/accounts/github/login/">Log in with GitHub</a>
            <a href="/accounts/gitlab/login/">Log in with GitLab</a>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://example.com/projects/", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["markdown"]).to include("Log in")
      expect(payload["warnings"]).to include("auth_or_login_interstitial")
    end
  end

  it "does not flag expected login paths as unexpected auth interstitials" do
    html = <<~HTML
      <html>
        <head><title>Log in - Example Community</title></head>
        <body>
          <main>
            <h1>Log in</h1>
            <form action="/login" method="post">
              <input type="email" name="email">
              <input type="password" name="password">
            </form>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://example.com/login/", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["warnings"]).not_to include("auth_or_login_interstitial")
    end
  end

  it "summarizes cookie-led consent prompts as interstitials" do
    html = <<~HTML
      <html>
        <head><title>Google</title></head>
        <body>
          <main>
            <h1>Before you continue to Google</h1>
            <p>We use cookies and data to deliver and maintain Google services.</p>
            <p>Accept all or reject all to continue.</p>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://www.google.com/webhp?hl=en", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["markdown"]).to include("Before you continue to Google")
      expect(payload["markdown"]).to include("cookie or consent prompt")
      expect(payload["warnings"]).to include("consent_interstitial")
    end
  end

  it "does not mislabel public homepages as auth walls just because sign-in chrome is present" do
    html = <<~HTML
      <html>
        <head><title>Trainline | Search, Compare &amp; Buy Cheap Train Tickets</title></head>
        <body>
          <main>
            <header>
              <a href="/login">Sign in to continue</a>
              <form class="hidden-login" style="display:none">
                <input type="email" name="email">
                <input type="password" name="password">
                <a href="/forgotten-password">Forgotten password?</a>
              </form>
            </header>
            <section>
              <h1>Search, Compare &amp; Buy Cheap Train Tickets</h1>
              <p>Book rail and coach travel across Europe.</p>
            </section>
            <section>
              <h2>Popular routes</h2>
              <a href="/routes/paris-london">Paris to London</a>
              <a href="/routes/rome-milan">Rome to Milan</a>
            </section>
            <section>
              <h2>Travel tools</h2>
              <a href="/help">Help center</a>
              <a href="/stations">Station guides</a>
            </section>
          </main>
          <script>
            window.__REACT_QUERY_STATE__ = { prompt: "sign in to continue" };
          </script>
        </body>
      </html>
    HTML

    with_url_page("https://example.com/", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["warnings"]).not_to include("auth_or_login_interstitial")
      expect(payload["markdown"]).to include("Search, Compare & Buy Cheap Train Tickets")
    end
  end
end
