# frozen_string_literal: true

RSpec.describe 'FetchUtil extractor integration' do
  include_context 'extractor integration helpers'

  it 'extracts Tempo article bodies without leading related-link clusters' do
    html = <<~HTML
      <html>
        <head>
          <title>Seberapa Berat Memenuhi Aturan Antideforestasi Eropa | tempo.co</title>
          <meta property="og:site_name" content="tempo.co">
          <meta name="description" content="Industri makanan dan minuman belum siap mengadopsi aturan antideforestasi Eropa.">
        </head>
        <body>
          <main>
            <section class="related-news">
              <a href="/ekonomi/purbaya-prediksi-defisit-apbn-2026-melebar-2274131">Purbaya Prediksi Defisit APBN 2026 Melebar</a>
              <a href="/ekonomi/maxim-indonesia-tanggapi-status-ojol-sebagai-umkm-2274116">Maxim Indonesia Tanggapi Status Ojol Sebagai UMKM</a>
              <a href="/ekonomi/msci-ubah-bobot-saham-2274000">MSCI Ubah Bobot Saham Indonesia</a>
            </section>
            <p>Scroll ke bawah untuk membaca berita</p>
            <h1 class="title-article">Seberapa Berat Memenuhi Aturan Antideforestasi Eropa</h1>
            <article class="grow space-y-6 overflow-x-clip z-10 w-full">
              <p>Produk minuman berpemanis di kawasan Pasar Minggu, Jakarta, 19 Januari 2025. Tempo/M Taufan Rengganis</p>
              <p>Tampilkan Ringkasan Artikel</p>
              <p>PRODUSEN makanan dan minuman masih menunggu kepastian langkah pemerintah menjelang pemberlakuan European Union Deforestation Regulation atau regulasi antideforestasi Eropa pada akhir 2026.</p>
              <p>Mereka belum mendapatkan kepastian agar produk-produknya bisa masuk ke pasar Eropa dengan syarat baru berdasarkan aturan tersebut.</p>
              <p>Ketentuan itu mengharuskan pelaku usaha membuktikan komoditas tidak berasal dari lahan hasil deforestasi setelah tenggat yang ditetapkan.</p>
              <p>Kalangan industri menyatakan penelusuran asal-usul bahan baku masih menjadi tantangan karena rantai pasok melibatkan banyak petani kecil.</p>
              <div class="related-article"><a href="/ekonomi/berita-lain">Baca juga berita ekonomi lainnya</a></div>
              <p>Pemerintah diminta mempercepat sistem pendataan agar eksportir mempunyai dokumen yang seragam saat aturan tersebut mulai berlaku.</p>
              <p>Dengarkan artikel</p>
              <p>Bagikan</p>
            </article>
          </main>
        </body>
      </html>
    HTML

    url = 'https://www.tempo.co/ekonomi/aturan-anti-deforestasi-eropa-eudr-ekspor-indonesia-2273962'

    extract_from_url(url, html) do |payload|
      expect(payload['contentType']).to eq('article')
      expect(payload['markdown']).to include('PRODUSEN makanan dan minuman masih menunggu kepastian')
      expect(payload['markdown']).to include('Pemerintah diminta mempercepat sistem pendataan')
      expect(payload['markdown']).not_to include('Purbaya Prediksi Defisit APBN')
      expect(payload['markdown']).not_to include('Maxim Indonesia')
      expect(payload['markdown']).not_to include('MSCI Ubah Bobot')
      expect(payload['markdown']).not_to include('Baca juga berita ekonomi lainnya')
      expect(payload['markdown']).not_to include('Dengarkan artikel')
      expect(payload['markdown']).not_to include('Bagikan')
      expect(payload['warnings']).not_to include('empty_extraction')
      expect(payload['warnings']).not_to include('short_extraction')
      expect(payload['warnings']).not_to include('url_content_mismatch')
      expect(payload['warnings']).not_to include('consent_interstitial')
    end
  end
end
