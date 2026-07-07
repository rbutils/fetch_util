# frozen_string_literal: true

RSpec.describe 'FetchUtil extractor integration for Sabah articles' do
  include_context 'extractor integration helpers'

  it 'extracts Sabah article bodies without breadcrumb and promo chrome' do
    html = <<~HTML
      <html>
        <head>
          <title>AK Partili Belediye Başkanı Süleyman Çetinkaya'ya bıçaklı saldırı! Oğlu arbedede yaralandı - Sabah</title>
          <link rel="canonical" href="https://www.sabah.com.tr/yasam/suleyman-cetinkaya-saldiri">
          <meta property="og:site_name" content="Sabah">
          <meta property="og:url" content="https://www.sabah.com.tr/yasam/suleyman-cetinkaya-saldiri">
          <meta name="description" content="Afyonkarahisar'da belediye başkanına saldırı.">
        </head>
        <body>
          <main>
            <section class="contentFrame">
              <div class="breadcrumb">
                <a href="https://www.sabah.com.tr/">Haberler</a>
                <a href="https://www.sabah.com.tr/yasam">Yaşam Haberleri</a>
                <span>AK Partili Belediye Başkanı Süleyman Çetinkaya'ya bıçaklı saldırı! Oğlu arbedede yaralandı</span>
              </div>
              <div class="news-detail-info">Giriş Tarihi: 7.07.2026 10:48</div>
              <h1 class="pageTitle">AK Partili Belediye Başkanı Süleyman Çetinkaya'ya bıçaklı saldırı! Oğlu arbedede yaralandı</h1>
              <h2 class="spot">Afyonkarahisar'ın Dinar ilçesine bağlı Haydarlı beldesi Belediye Başkanı Süleyman Çetinkaya, evinin önünde bıçaklı saldırıya uğradı.</h2>
              <div class="newsDetailText">
                <p>Dinar'a bağlı Haydarlı Belediye Başkanı Süleyman Çetinkaya, 5 Temmuz günü saat 19.00 sıralarında evine girmek üzereyken bir kişinin bıçaklı saldırısına uğradı.</p>
                <p>Başkan Çetinkaya'nın yara almadan atlattığı olayda, yanında bulunan oğlu Yusuf Çetinkaya çıkan arbedede yaralandı.</p>
              </div>
              <div class="newsDetailText">
                <p><strong>'BU ALÇAK SALDIRI KABUL EDİLEMEZ'</strong></p>
                <p>Olayla ilgili AK Parti İl Başkanlığı'ndan yapılan açıklamada, saldırının şiddetle kınandığı belirtildi.</p>
                <p>Google Haberler'de tüm gelişmeleri tek kaynakta görmek için Sabah'ı takip edin.</p>
                <p>Sabah.com.tr Uygulamamızı İndirin</p>
              </div>
            </section>
          </main>
        </body>
      </html>
    HTML

    url = 'https://www.sabah.com.tr/yasam/suleyman-cetinkaya-saldiri'

    extract_from_url(url, html) do |payload|
      expect_content_type(payload, 'article')
      expect(payload['markdown']).to include('Dinar\'a bağlı Haydarlı Belediye Başkanı Süleyman Çetinkaya')
      expect(payload['markdown']).to include('saldırının şiddetle kınandığı belirtildi')
      expect(payload['markdown']).not_to include('Haberler](https://www.sabah.com.tr/')
      expect(payload['markdown']).not_to include('Yaşam Haberleri')
      expect(payload['markdown']).not_to include('Google Haberler')
      expect(payload['markdown']).not_to include('Uygulamamızı İndirin')
      expect_warnings(payload, exclude: %w[empty_extraction short_extraction url_content_mismatch consent_interstitial])
    end
  end
end
