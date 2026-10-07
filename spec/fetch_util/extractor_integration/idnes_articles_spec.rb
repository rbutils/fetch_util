# frozen_string_literal: true

require 'nokogiri'

RSpec.describe 'FetchUtil extractor integration for iDNES articles' do
  include_context 'extractor integration helpers'

  it "extracts public iDNES Premium article text and keeps the paywall warning only" do
    html = <<~HTML
      <html lang="cs">
        <head>
          <title>Ultraortodoxní Židé v Izraeli vnucují svůj způsob života všem - iDNES.cz</title>
          <meta property="og:site_name" content="iDNES.cz">
          <meta property="og:title" content="Velká bitva o izraelská města. Ultraortodoxní Židé chtějí nastolit svoje pořádky, je jich navíc čím dál víc">
          <meta property="article:published_time" content="2026-07-06T20:00:00">
          <link rel="canonical" href="https://www.idnes.cz/zpravy/zahranicni/arad-izrael-ultraortodoxni-zide-nepokoje.A260702_195055_zahranicni_krou">
        </head>
        <body>
          <nav>
            <a href="/zpravy">Zprávy</a>
            <a href="/premium">Premium</a>
          </nav>
          <div id="content" class="content">
            <div class="art-full">
              <h1 class="arttit">Žena v reklamě také vadí. Ultraortodoxní Židé chtějí nastolit v Izraeli svoje pořádky</h1>
              <p>6. července 2026 20:00</p>
              <p>Izrael má problém. Ultraortodoxní komunita odmítá vést normální život, což vede ke konfliktům, které musí řešit policie.</p>
              <div class="opener">Od naší spolupracovnice v Izraeli - Ultraortodoxní Židé a v tmavých hidžábech zahalené muslimky. Jinak prázdné ulice, které však vypadaly dobře. Arad je poslední zastávka před cestou k Mrtvému moři.</div>
              <div id="art-text" class="text">
                <p>Že jsou v Aradu pře mezi ultraortodoxními Židy a těmi sekulárními a liberálními, odhalila začátkem roku reportáž v televizi Kan.</p>
                <p>Padala v ní obvinění, že městské obchodní centrum koupili představitelé dynastie chasidů Ger a tamní obchodníci proto museli začít přioblékávat figuríny.</p>
                <blockquote>Zhruba 50 procent ultraortodoxních mužů nepracuje. Komunita často žije z podpor, darů a přídavků.</blockquote>
                <div id="paywall" class="paywall paywall-before">
                  <style>.paywall { color: red; }</style>
                  <h2>Vyzkoušejte si Premium za polovinu</h2>
                  <p>Připojte se ještě dnes a získejte neomezený přístup k obsahu iDNES.cz, Lidovky.cz a Expres.cz.</p>
                  <a class="paywall-login2" href="/login">Přihlásit se</a>
                </div>
              </div>
              <div class="paywall-foot">Právě nejčtenější Premium články: Klaus exkluzivně a další doporučení.</div>
            </div>
          </div>
        </body>
      </html>
    HTML

    extract_from_url("https://www.idnes.cz/zpravy/zahranicni/arad-izrael-ultraortodoxni-zide-nepokoje.A260702_195055_zahranicni_krou", html) do |payload|
      source = Nokogiri::HTML(html)
      lead = source.at_css('.art-full > p:nth-of-type(2)').text
      expect_content_type(payload, "article")
      expect(payload['title']).to eq(source.at_css('h1').text)
      expect(payload['language']).to eq('cs')
      expect(payload['publishedTime']).to eq('2026-07-06T20:00:00')
      expect(payload['excerpt']).to include(lead)
      source.css('.art-full > p, #art-text > p').each do |paragraph|
        expect(Nokogiri::HTML(payload['html']).text).to include(paragraph.text)
      end
      expect(payload["markdown"]).to include("Ultraortodoxní Židé a v tmavých hidžábech zahalené muslimky")
      expect(payload["markdown"]).to include("Zhruba 50 procent ultraortodoxních mužů nepracuje")
      expect(payload["markdown"]).not_to include("další část bude dostupná pouze v iDNES Premium")
      expect(payload["markdown"]).not_to include("Právě nejčtenější Premium články")
      expect_warnings(payload, include: "paywall_partial_content", exclude: %w[truncated_content url_content_mismatch consent_interstitial])
    end
  end

  it 'uses an owned reporting lead after a date-time while preserving authored dated prose' do
    lead = 'The public report describes the complete measurement method and the independent observations supporting its conclusion.'
    dated = '6 juillet 2026 20:00'
    html = <<~HTML
      <html lang="fr"><head><title>Independent observations</title></head><body><article>
        <h1>Independent observations</h1><p>#{dated}</p><p>#{lead}</p>
        <p>The following explanation preserves the original reporting and the context needed to evaluate each observation independently.</p>
      </article></body></html>
    HTML
    extract_from_url('https://journal.example/observations', html) do |payload|
      expect_content_type(payload, 'article')
      expect(payload['excerpt']).to eq(lead)
      expect(Nokogiri::HTML(payload['html']).text).to include(dated, lead)
    end
    prose = "#{dated} marks the start of the reported experiment, a substantive observation retained as the authored lead."
    extract_from_url('https://journal.example/observations', html.sub("<p>#{dated}</p>", "<p>#{prose}</p>")) do |payload|
      expect(payload['excerpt']).to include(prose)
      expect(Nokogiri::HTML(payload['html']).text).to include(prose, lead)
    end
  end
end
