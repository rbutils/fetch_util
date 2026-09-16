# frozen_string_literal: true

RSpec.describe 'FetchUtil Kurir article extraction' do
  include_context 'extractor integration helpers'

  it 'extracts the visible article through the shared reader path without tracking feed noise' do
    fixture_path = File.expand_path('../../fixtures/kurir_article.html', __dir__)
    html = File.read(fixture_path)
    url = 'https://www.kurir.rs/techvision/vesti/10040514/kako-prepoznati-i-ukloniti-laznu-ekstenziju-iz-chrome-a'

    with_url_page(url, html) do |page|
      page.evaluate(<<~'JS')
        document.body.insertAdjacentHTML(
          "beforeend",
          '<script type="application/json">{"tracking":"kurir-script-noise"}</script>' +
            '<style>.kurir-style-noise { display: none; }</style>'
        );
      JS
      extractor_for(true).send(:inject_assets, page)
      before = page.evaluate('document.documentElement.outerHTML')
      payload = page.evaluate('window.FetchUtilExtract.extract({reader_mode: true})')
      markdown = payload.fetch('markdown')
      paragraphs = [
        'Zvanična prodavnica dodataka za brauzer, Chrome Web Store',
        'Prevaru su otkrili bezbednosni stručnjaci iz Majkrosoftovog tima za pretnje',
        'Na kraju su korisnici bili upućeni da provere potpis i izdavača'
      ]

      expect(payload).to include(
        'contentType' => 'article',
        'title' => 'Hitno je obrišite! Google propustio lažnu aplikaciju, krala sve što ukucate!',
        'readerMode' => true,
        'hostAware' => false,
        'warnings' => [],
        'suspect' => false
      )
      expect(markdown).to include(
        'SKANDAL NA CHROME WEB PRODAVNICI',
        '![Kurir ilustracija](https://kurir.rs/example.jpg)',
        'U slučaju da imate instaliranu Perplexity AI ekstenziju',
        *paragraphs
      )
      expect(paragraphs.map { |text| markdown.index(text) }).to eq(paragraphs.map { |text| markdown.index(text) }.sort)
      expect(markdown).not_to include(
        'cdn2.midas-network.com/api/click/article',
        'Slušaj vest',
        'Komentariši',
        'kurir-script-noise',
        'kurir-style-noise'
      )
      expect(payload.fetch('html')).not_to include('kurir-script-noise', 'kurir-style-noise')
      expect(page.evaluate('document.documentElement.outerHTML')).to eq(before)
    end
  end

  it 'leaves the Kurir homepage to shared list extraction' do
    cards = (1..6).map do |index|
      <<~HTML
        <article>
          <a href="https://www.kurir.rs/vesti/story-#{index}">
            <h2>Kurir homepage story #{index}</h2>
          </a>
        </article>
      HTML
    end.join
    html = "<main><h1>Kurir</h1>#{cards}</main>"

    with_url_page('https://www.kurir.rs/', html) do |page|
      payload = extract_payload(page)

      expect(payload).to include('contentType' => 'list', 'hostAware' => false)
      (1..6).each do |index|
        expect(payload.fetch('markdown')).to include(
          "[Kurir homepage story #{index}](https://www.kurir.rs/vesti/story-#{index})"
        )
      end
    end
  end
end
