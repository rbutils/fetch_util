# frozen_string_literal: true

RSpec.describe 'FetchUtil extractor integration' do
  include_context 'extractor integration helpers'

  it 'extracts a single Index.hu Mindekozben post without adjacent feed posts' do
    html = <<~HTML
      <html lang="hu">
        <head>
          <title>Az unokák imádják, a felesége kevésbé, négy dinoszaurusszal tért haza a nagypapa - Mindeközben - Index</title>
          <meta property="og:site_name" content="index.hu">
          <meta property="article:published_time" content="2014-10-21T16:06:00+02:00">
          <meta property="og:updated_time" content="2026-06-01T14:51:53+02:00">
        </head>
        <body>
          <main>
            <div id="post-site" class="container border cikk-torzs-container">
              <ul class="current-post">
                <li id="pp6240447" class="post pp-post pp_post pp_avatar poszt-nincs-perc">
                  <div class="mindenkozben_post_content content">
                    <h3 class="title"><a href="/mindekozben/poszt/2026/07/06/online-vasarolt-dinokat-a-nagypapa-az-unokainak-de-varatlan-fordulat-jott/">Az unokák imádják, a felesége kevésbé, négy dinoszaurusszal tért haza a nagypapa</a></h3>
                    <p>Ilyen sztorit se hallani mindennap, mint amelyik az angliai Wrea Greenben élő Darren Schreiberrel történt.</p>
                    <p>Az 58 éves nagypapa eredetileg építőipari gépekre szeretett volna licitálni egy netes aukción, ám végül egészen mással távozott: négy hatalmas dinoszaurusszal.</p>
                    <p>Az online vásárolt dinókat a nagypapa az unokáinak szánta, de a váratlan fordulat csak akkor jött, amikor haza kellett szállítani őket.</p>
                    <div id="szerkfoto_gallery_70339187"><p>Galéria: Véletlenül négy óriási dinoszauruszt vett, az unokák viszont odavannak érte</p></div>
                    <p>Darren eleinte úgy gondolta, lehet esélye sem lesz megszerezni a látványos őslényeket, de végül még három óriási példányra is licitált, és mindet megnyerte.</p>
                    <p>A különös szerzeményeknek akadtak lelkes rajongói is: Darren öt unokája egyszerűen odáig van a dinoszauruszokért.</p>
                  </div>
                </li>
              </ul>
              <div class="new-posts">új poszt érkezett, kattintson a megtekintéshez!</div>
              <ul class="post-list">
                <li class="post"><div class="mindenkozben_post_content content"><h3>Valkusz Milán megszólalt a balesete után</h3><p>Ez egy másik, a cél URL-hez nem tartozó poszt szövege.</p></div></li>
              </ul>
            </div>
          </main>
        </body>
      </html>
    HTML

    url = 'https://index.hu/mindekozben/poszt/2026/07/06/online-vasarolt-dinokat-a-nagypapa-az-unokainak-de-varatlan-fordulat-jott/'

    extract_from_url(url, html) do |payload|
      expect(payload['contentType']).to eq('article')
      expect(payload['title']).to eq('Az unokák imádják, a felesége kevésbé, négy dinoszaurusszal tért haza a nagypapa')
      expect(payload['publishedTime']).to eq('2026-07-06T00:00:00+02:00')
      expect(payload['markdown']).to include('Ilyen sztorit se hallani mindennap')
      expect(payload['markdown']).to include('Darren öt unokája egyszerűen odáig van')
      expect(payload['markdown']).not_to include('új poszt érkezett')
      expect(payload['markdown']).not_to include('Valkusz Milán megszólalt')
      expect(payload['warnings']).not_to include('stale_content')
      expect(payload['warnings']).not_to include('multi_topic_page')
      expect(payload['warnings']).not_to include('url_content_mismatch')
      expect(payload['warnings']).not_to include('consent_interstitial')
    end
  end
end
