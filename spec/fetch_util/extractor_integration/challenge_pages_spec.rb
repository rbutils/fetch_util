# frozen_string_literal: true

RSpec.describe 'FetchUtil extractor integration' do
  include_context 'extractor integration helpers'

  it "salvages anubis challenge pages and flags them" do
    html = <<~HTML
      <html>
        <head><title>Making sure you're not a bot!</title></head>
        <body>
          <main>
            <h1>Making sure you're not a bot!</h1>
            <p>Loading...</p>
            <p>Please wait a moment while we ensure the security of your connection.</p>
            <p>Sadly, you must enable JavaScript to get past this challenge.</p>
          </main>
          <footer>
            <p>Protected by Anubis</p>
            <p>This website is running Anubis version v1.2.3.</p>
          </footer>
        </body>
      </html>
    HTML

    with_url_page("https://www.ft.com/", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["markdown"]).to include("# Making sure you're not a bot!")
      expect(payload["markdown"]).to include("Sadly, you must enable JavaScript to get past this challenge.")
      expect(payload["markdown"]).not_to include("This website is running Anubis version")
      expect(payload["warnings"]).to include("anubis_challenge_page")
      expect(payload["warnings"]).to include("bot_or_access_interstitial")
    end
  end

  it "salvages cloudflare challenge pages and flags them" do
    html = <<~HTML
      <html>
        <head><title>Just a moment...</title></head>
        <body>
          <main>
            <h1>Verify you are human</h1>
            <p>Performing security verification</p>
            <p>This website uses a security service to protect against malicious bots.</p>
          </main>
          <footer>
            <p>Cloudflare Ray ID: 12345</p>
          </footer>
        </body>
      </html>
    HTML

    with_url_page("https://www.pinterest.com/search/pins/?q=ruby+programming", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["markdown"]).to include("# Just a moment...")
      expect(payload["markdown"]).to include("Performing security verification")
      expect(payload["markdown"]).not_to include("Cloudflare Ray ID")
      expect(payload["warnings"]).to include("cloudflare_challenge_page")
      expect(payload["warnings"]).to include("bot_or_access_interstitial")
    end
  end

  it "does not flag educational cloudflare pages as challenge walls" do
    html = <<~HTML
      <html>
        <head><title>Sample Form with Cloudflare Turnstile</title></head>
        <body>
          <main>
            <h1>Sample Form with Cloudflare Turnstile</h1>
            <p>This page explains how Cloudflare Turnstile is displayed and how Cloudflare Turnstile verification works.</p>
            <p>You can also check how the Cloudflare Challenge works on example page.</p>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://www.ebay.com/sch/i.html?_nkw=ruby+programming", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["markdown"]).to include("This page explains how Cloudflare Turnstile is displayed")
      expect(payload["warnings"]).not_to include("cloudflare_challenge_page")
      expect(payload["warnings"]).not_to include("bot_or_access_interstitial")
    end
  end

  it "flags managed turnstile challenge pages" do
    html = <<~HTML
      <html>
        <head><title>cloudflare turnstile</title></head>
        <body>
          <main>
            <h2>Managed challenge</h2>
          </main>
        </body>
      </html>
    HTML

    with_page(html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["markdown"]).to include("Managed challenge")
      expect(payload["warnings"]).to include("cloudflare_challenge_page")
      expect(payload["warnings"]).to include("bot_or_access_interstitial")
    end
  end

  it "salvages datadome challenge shells with nearly empty doms" do
    html = <<~HTML
      <html>
        <head><title>g2.com</title></head>
        <body>
          <script>var dd = { rt: 'c' };</script>
          <script src="https://ct.captcha-delivery.com/c.js"></script>
          <iframe src="https://geo.captcha-delivery.com/captcha/?foo=bar" title="DataDome CAPTCHA"></iframe>
        </body>
      </html>
    HTML

    with_page(html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["markdown"]).to include("# Access verification required")
      expect(payload["markdown"]).to include("Challenge: DataDome")
      expect(payload["warnings"]).to include("datadome_challenge_page")
      expect(payload["warnings"]).to include("bot_or_access_interstitial")
    end
  end

  it "flags tiny site-unavailable error pages" do
    html = <<~HTML
      <html>
        <head><title>خطایی رخ داده</title></head>
        <body>
          <main>
            <h1>خطایی رخ داده</h1>
            <p>وب سایت مورد نظر در دسترس نیست</p>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://en.mehrnews.com/", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["markdown"]).to include("خطایی رخ داده")
      expect(payload["warnings"]).to include("site_unavailable_interstitial")
      expect(payload["warnings"]).not_to include("bot_or_access_interstitial")
    end
  end

  it "does not add url mismatch warnings on unavailable deep-link pages" do
    html = <<~HTML
      <html>
        <head><title>خطایی رخ داده</title></head>
        <body>
          <main>
            <h1>خطایی رخ داده</h1>
            <p>وب سایت مورد نظر در دسترس نیست</p>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://en.mehrnews.com/news/242944/Iran-sent-its-official-response-to-US-proposal-last-night", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["warnings"]).to include("site_unavailable_interstitial")
      expect(payload["warnings"]).not_to include("url_content_mismatch")
    end
  end
end
