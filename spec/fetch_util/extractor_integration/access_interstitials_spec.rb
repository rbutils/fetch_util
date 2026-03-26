# frozen_string_literal: true

RSpec.describe 'FetchUtil extractor integration' do
  include_context 'extractor integration helpers'

  it "flags meta cookie and login walls and salvages metadata" do
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
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["markdown"]).to include("# Threads page")
      expect(payload["warnings"]).to include("meta_login_wall")
      expect(payload["warnings"]).to include("consent_interstitial")
    end
  end

  it "salvages instagram login walls even without metadata descriptions" do
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
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["markdown"]).to include("# Groundbird (@groundbirdsings)")
      expect(payload["markdown"]).to include("This Instagram page for groundbirdsings requires login before")
      expect(payload["warnings"]).to include("consent_interstitial")
    end
  end

  it "salvages instagram post login walls from og metadata and next-target paths" do
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
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["markdown"]).to include("Activate and hold the button to confirm that you're human.")
      expect(payload["warnings"]).to include("human_verification_interstitial")
      expect(payload["warnings"]).to include("bot_or_access_interstitial")
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

      expect(payload["markdown"]).to include("Help Us Protect Glassdoor")
      expect(payload["warnings"]).to include("human_verification_interstitial")
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

  it "flags subscription and login walls as access interstitials" do
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

  it "flags generic auth walls such as password-reset shells" do
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

  it "summarizes cookie-led consent walls as interstitials" do
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
      expect(payload["markdown"]).to include("cookie or consent wall")
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
