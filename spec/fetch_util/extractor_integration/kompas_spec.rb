# frozen_string_literal: true

RSpec.describe 'FetchUtil extractor integration' do
  include_context 'extractor integration helpers'

  it 'extracts Kompas article bodies through generic article detection' do
    html = <<~HTML
      <html>
        <head>
          <title>7 Mie Instan Terbaik di Dunia 2026 Versi Smarter Ranking, Nomor 2 dari Indonesia - Kompas.com</title>
          <meta property="og:site_name" content="Kompas.com">
          <meta name="description" content="Daftar mie instan terbaik di dunia 2026 versi Smarter Ranking.">
        </head>
        <body class="theme--tren page--read">
          <main>
            <h1 class="read__title">7 Mie Instan Terbaik di Dunia 2026 Versi Smarter Ranking, Nomor 2 dari Indonesia</h1>
            <div class="read__author">Aditya Priyatna Darmawan</div>
            <div data-modal-target="reaction-share"><p>Bagikan artikel ini melalui</p></div>
            <div data-modal-target="modal-gift-membership">
              <p>Kirimkan Apresiasi Spesial untuk mendukung Jurnalisme Jernih KOMPAS.com</p>
            </div>
            <div data-modal-target="modal-question">
              <p>Syarat dan ketentuan</p>
              <ol><li>Apresiasi Spesial adalah fitur dukungan dari pembaca kepada KOMPAS.com.</li></ol>
            </div>
            <div class="read__content">
              <p>KOMPAS.com - Mi instan menjadi salah satu menu darurat ketika seseorang ingin makan sewaktu-waktu karena praktis untuk dibuat.</p>
              <p>Menu penyelamat tersebut juga memiliki harga yang relatif terjangkau sehingga ramah untuk kantong siapa pun.</p>
              <p>Beberapa negara, khususnya Asia, memiliki varian mie instan masing-masing. Aneka mi tersebut kini tersebar dan dijual ke berbagai penjuru dunia.</p>
              <div class="komentar-bar">Komentar: 3</div>
              <p>Situs Smarter Ranking melakukan pemeringkatan terhadap berbagai mi instan di seluruh dunia pada 2026.</p>
              <p>Ranking tersebut disusun dengan mempertimbangkan rasa, aroma, tekstur mi, dan kualitas bumbu yang tersedia di dalam kemasan.</p>
              <p>Indomie Mi Goreng asal Indonesia menempati posisi kedua dalam daftar tersebut dan disebut memiliki rasa gurih yang khas.</p>
              <p>Daftar ini memperlihatkan bahwa produk mi instan Asia masih mendominasi selera pencinta kuliner praktis dunia.</p>
            </div>
          </main>
        </body>
      </html>
    HTML

    url = 'https://www.kompas.com/tren/read/2026/07/06/120000265/7-mie-instan-terbaik-di-dunia-2026-versi-smarter-ranking-nomor-2-dari'

    extract_from_url(url, html) do |payload|
      expect(payload['contentType']).to eq('article')
      expect(payload['markdown']).to include('Mi instan menjadi salah satu menu darurat')
      expect(payload['markdown']).to include('Indomie Mi Goreng asal Indonesia menempati posisi kedua')
      expect(payload['markdown']).not_to include('Kirimkan Apresiasi')
      expect(payload['markdown']).not_to include('Syarat dan ketentuan')
      expect(payload['markdown']).not_to include('Bagikan artikel ini')
      expect(payload['warnings']).not_to include('empty_extraction')
      expect(payload['warnings']).not_to include('short_extraction')
      expect(payload['warnings']).not_to include('url_content_mismatch')
      expect(payload['warnings']).not_to include('consent_interstitial')
    end
  end
end
