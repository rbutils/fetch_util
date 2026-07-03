# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'FetchUtil extractor integration - consent language walls' do
  include_context 'extractor integration helpers'
  include_context 'fixture html helpers'

  it "detects Norwegian consent wall interstitial" do
    html = simple_consent_wall_html(
      title: "Dine personverninnstillinger",
      heading: "Dine personverninnstillinger",
      paragraphs: [
        "Vi bruker informasjonskapsler og lignende teknologier for å gi deg en bedre opplevelse.",
        "Vi og våre partnere lagrer og bruker informasjonskapsler for å tilpasse innhold og annonser."
      ],
      buttons: ["Godta alle", "Avvis valgfrie informasjonskapsler"]
    )

    with_url_page("https://www.document.no/some-article", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["warnings"]).to include("consent_interstitial")
    end
  end

  it "detects Swedish consent wall interstitial" do
    html = simple_consent_wall_html(
      title: "Cookie-inställningar",
      heading: "Vi använder kakor",
      paragraphs: [
        "Vi anvander kakor och liknande tekniker for att ge dig en battre upplevelse.",
        "Samtycke till personanpassade annonser och innehall."
      ],
      buttons: ["Acceptera alla", "Avvisa valfria kakor"]
    )

    with_url_page("https://www.svd.se/some-article", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["warnings"]).to include("consent_interstitial")
    end
  end

  it "detects Finnish consent wall interstitial" do
    html = simple_consent_wall_html(
      title: "Evästeasetukset",
      heading: "Evästeasetukset",
      paragraphs: [
        "Käytämme evästeitä ja vastaavia teknologioita parantaaksemme käyttökokemustasi.",
        "Me ja kumppanimme käytämme evästeitä mainonnan ja sisällön personointiin."
      ],
      buttons: ["Hyväksy kaikki", "Hylkää valinnaiset evästeet"]
    )

    with_url_page("https://www.hs.fi/some-article", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["warnings"]).to include("consent_interstitial")
    end
  end

  it "detects Lithuanian consent wall interstitial" do
    html = simple_consent_wall_html(
      title: "Slapukų nustatymai",
      heading: "Naudojame slapukus",
      paragraphs: [
        "Naudojame slapukus ir panašias technologijas, kad pagerintume jūsų patirtį.",
        "Slapukų nustatymai leidžia jums pasirinkti kokius slapukus naudojame."
      ],
      buttons: ["Priimti visus", "Atmesti pasirinktinius slapukus"]
    )

    with_url_page("https://www.delfi.lt/some-article", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["warnings"]).to include("consent_interstitial")
    end
  end

  it "does not flag residual cookie navigation on accessible public pages" do
    html = <<~HTML
      <html>
        <head><title>GOV.UK</title></head>
        <body>
          <header>
            <button>Cookies on GOV.UK</button>
            <a href="/help/cookies">Manage cookie preferences</a>
          </header>
          <main>
            <h1>Welcome to GOV.UK</h1>
            <p>Find government services and information including benefits, births, citizenship, business, tax, and working in the UK.</p>
            <p>Use this service index to renew documents, check official guidance, apply for support, and find departments responsible for public services.</p>
            <section>
              <h2>Services and information</h2>
              <a href="/browse/benefits">Benefits</a>
              <a href="/browse/tax">Money and tax</a>
              <a href="/browse/working">Working, jobs and pensions</a>
              <a href="/browse/education">Education and learning</a>
            </section>
            <section>
              <h2>Government activity</h2>
              <p>Read announcements, consultations, statistics, policy papers, and transparency updates from departments and agencies.</p>
              <a href="/government/organisations">Departments</a>
              <a href="/search/news-and-communications">News</a>
            </section>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://www.gov.uk/", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["markdown"]).to include("# Welcome to GOV.UK")
      expect(payload["markdown"]).to include("Education and learning")
      expect(payload["warnings"]).not_to include("consent_interstitial")
    end
  end

  it "still flags compact pages dominated by cookie consent copy" do
    html = simple_consent_wall_html(
      title: "Cookies on GOV.UK",
      heading: "Cookies on GOV.UK",
      paragraphs: [
        "We use some essential cookies to make this website work.",
        "We would like to set additional cookies to understand how you use GOV.UK, remember your settings and improve government services."
      ],
      buttons: ["Accept additional cookies", "Reject additional cookies"]
    )

    with_url_page("https://www.gov.uk/some-service", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["warnings"]).to include("consent_interstitial")
    end
  end
end
