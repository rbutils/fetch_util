# frozen_string_literal: true

RSpec.describe 'FetchUtil extractor integration' do
  include_context 'extractor integration helpers'

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

  it "summarizes Instagram login-required pages even without metadata descriptions" do
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

      expect(payload["markdown"]).to include("# Groundbird (@groundbirdsings)")
      expect(payload["markdown"]).to include("Original content on this Instagram page for groundbirdsings is not available without login.")
      expect_warnings(payload, include: "consent_interstitial")
    end
  end

  it "summarizes Instagram post login-required pages from OG metadata and next-target paths" do
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

      expect(payload["markdown"]).to include("# Cristiano Ronaldo on Instagram")
      expect(payload["markdown"]).to include("- Author: @cristiano")
      expect(payload["markdown"]).to include("- Published: November 24, 2024")
      expect(payload["markdown"]).to include("- Post: /p/DCwL2cKggIk/")
      expect(payload["markdown"]).to include("- 8M likes")
      expect(payload["markdown"]).to include("- 59K comments")
      expect(payload["markdown"]).to include("😎")
    end
  end

  it "treats username-prefixed instagram post urls as posts instead of profile login-required summaries" do
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

      expect(payload["markdown"]).to include("# Ronaldo on Instagram")
      expect(payload["markdown"]).to include("- Author: @ronaldo")
      expect(payload["markdown"]).to include("- Published: March 30, 2026")
      expect(payload["markdown"]).to include("- Post: /p/DWh3vbdkXI1/")
      expect(payload["markdown"]).not_to include("Original content on this Instagram page for ronaldo is not available without login.")
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

  it "extracts visible instagram comments from the public post text" do
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
            <div>153.9K</div>
            <div>1.3K</div>
            <div>4 days ago</div>
            <div>Log in to like or comment.</div>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://www.instagram.com/ronaldo/p/DWh3vbdkXI1/", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["markdown"]).to include("## Comments")
      expect(payload["markdown"]).to include("@douglas_kadosh: Sim meu 09, acho que já tá na hora de parar de brincar né?")
      expect(payload["markdown"]).to include("@k.le.bersou: Esse Daniel parece um fantasma.👻")
      expect(payload["markdown"]).not_to include("Access notice: Instagram login required")
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
