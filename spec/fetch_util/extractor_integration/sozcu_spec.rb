# frozen_string_literal: true

RSpec.describe 'FetchUtil extractor integration for Sozcu' do
  include_context 'extractor integration helpers'
  include_context 'fetcher spec helpers'

  it 'classifies the Sozcu homepage as a clean story list without homepage-index warnings' do
    html = <<~HTML
      <html lang="tr">
        <head>
          <title>Sözcü Gazetesi - Haberler, son dakika haberleri, güncel haber, köşe yazıları</title>
          <meta property="og:site_name" content="www.sozcu.com.tr">
        </head>
        <body>
          <div class="vjs-modal-dialog-content">
            Seek to live, currently behind liveLIVE Beginning of dialog window. Escape will cancel and close the window.
          </div>
          <div class="container position-relative mb-4">
            <div class="breaking-news mb-4 d-flex lh-sm">
              <a href="/son-dakika">SON DAKİKA</a>
              <a href="/chp-li-belediye-baskani-zafer-partisi-ne-katildi-p334463">CHP’li belediye başkanı Zafer Partisi’ne katıldı</a>
            </div>
            <div class="row">
              <div class="col-md-6 col-lg-3 mb-4 mb-lg-0">
                <div class="news-card"><a href="/basbakanin-nisanlisi-turkiye-ye-getirilmedi-p334476">Başbakanın nişanlısı Ankara'ya getirilmedi</a></div>
              </div>
              <div class="col-md-6 col-lg-3 mb-4 mb-lg-0">
                <div class="news-card"><a href="/trt-deki-abd-gondermesi-dunyada-gundem-oldu-p334439">TRT'deki ABD göndermesi dünyada gündem oldu</a></div>
              </div>
              <div class="col-md-6 col-lg-3 mb-4 mb-lg-0">
                <div class="news-card"><a href="/altin-alacaklar-ve-satacaklar-dikkat-carsamba-gunu-dananin-kuyrugu-kopacak-p334346">Altın alacaklar ve satacaklar dikkat! Yarın dananın kuyruğu kopacak</a></div>
              </div>
              <div class="col-md-6 col-lg-3 mb-4 mb-lg-0">
                <div class="news-card"><a href="/dogum-gunu-partisi-donusu-facia-p334202">Dere yatağından yükselen çığlık faciayı ortaya çıkardı</a></div>
              </div>
              <div class="col-md-6 col-lg-3 mb-4 _plus-content">
                <div class="li-con bik-ilan"><a href="/surmene-asliye-hukuk-mahkemesi-p334119">SÜRMENE ASLİYE HUKUK MAHKEMESİ</a></div>
              </div>
              <div class="col-md-6 col-lg-3 mb-4 _plus-content">
                <div class="li-con bik-ilan"><a href="/ankara-6-sulh-hukuk-mahkemesi-p334118">ANKARA 6. SULH HUKUK MAHKEMESİ</a></div>
              </div>
            </div>
          </div>
        </body>
      </html>
    HTML
    url = 'https://www.sozcu.com.tr/'
    profile_payload = nil

    extract_from_url(url, html) do |payload|
      profile_payload = payload

      expect_content_type(payload, 'list')
      expect(payload['markdown']).to include('Başbakanın nişanlısı Ankara')
      expect(payload['markdown']).to include('TRT\'deki ABD göndermesi')
      expect(payload['markdown']).not_to include('Seek to live')
      expect(payload['markdown']).not_to include('Beginning of dialog window')
      expect(payload['markdown']).not_to include('SÜRMENE ASLİYE HUKUK MAHKEMESİ')
      expect(payload['markdown']).not_to include('ANKARA 6. SULH HUKUK MAHKEMESİ')
      expect(payload['statusPage']).to be(true)
    end

    stub_browser_extraction(url, page: page_at(url), payload: profile_payload)
    result = fetcher_with_dependencies.fetch(url)

    expect(result.content_type).to eq('list')
    expect(result.warnings).not_to include('homepage_index_page')
  end

  it 'leaves fresh Sozcu article payloads classified as articles' do
    article_payload = payload_with(
      title: "Başbakanın nişanlısı Ankara'ya getirilmedi",
      siteName: 'www.sozcu.com.tr',
      canonicalUrl: 'https://www.sozcu.com.tr/basbakanin-nisanlisi-turkiye-ye-getirilmedi-p334476',
      markdown: <<~MARKDOWN,
        # Başbakanın nişanlısı Ankara'ya getirilmedi

        Dünya, bugün ve yarın Ankara'da düzenlenecek 36. Nato Zirvesine odaklanırken, liderlerin uçakları da peş peşe Ankara'ya iniş yapmaya başladı.

        ABD Başkanı Donald Trump'ın bugün saat 15.00'de Ankara'ya iniş yapması ve Cumhurbaşkanı Recep Tayyip Erdoğan ile görüşmesi bekleniyor.
      MARKDOWN
      contentType: 'article',
      warnings: []
    )
    url = 'https://www.sozcu.com.tr/basbakanin-nisanlisi-turkiye-ye-getirilmedi-p334476'

    stub_browser_extraction(url, page: page_at(url), payload: article_payload)
    result = fetcher_with_dependencies.fetch(url)

    expect(result.content_type).to eq('article')
    expect(result.markdown).to include("Başbakanın nişanlısı Ankara'ya getirilmedi")
    expect(result.warnings).to be_empty
  end

  def fetcher_with_dependencies
    FetchUtil::Fetcher.new(browser: browser, extractor: extractor, raw_docs_fallback: raw_docs_fallback)
  end
end
