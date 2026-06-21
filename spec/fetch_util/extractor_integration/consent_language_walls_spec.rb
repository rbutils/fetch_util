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
end
