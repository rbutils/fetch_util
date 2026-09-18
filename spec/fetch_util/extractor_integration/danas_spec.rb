# frozen_string_literal: true

RSpec.describe 'FetchUtil Danas extraction' do
  include_context 'extractor integration helpers'

  let(:fixture) { fixture_contents(File.expand_path('../../fixtures/danas_article.html', __dir__)) }
  let(:url) { 'https://www.danas.rs/vesti/drustvo/vucic-rupe-na-pitevima-aplikacija' }

  def extract_without_reinjecting(page, reader_mode:)
    extractor = extractor_for(reader_mode)
    extractor.send(:register_cdp_closed_shadow_roots, page)
    extractor.send(:inject_vendor_assets, page)
    source = page.evaluate('document.documentElement.outerHTML')

    [page.evaluate(extractor.send(:extraction_call)), source]
  end

  it 'extracts the complete article through shared WordPress handling in both caller modes' do
    body_fragments = [
      'Predsednik Aleksandar Vučić ponovo',
      'Sad mi prave mašinu',
      'Saobraćajni inženjer Igor Velić',
      'To pokazuje da je stanje putne infrastrukture ozbiljan problem',
      'Inženjer geologije Zoran Đajić',
      'Kraljevo je još u avgustu 2022. godine dobilo aplikaciju'
    ]

    [true, false].each do |reader_mode|
      with_url_page(url, fixture) do |page|
        result, source = extract_without_reinjecting(page, reader_mode: reader_mode)
        positions = body_fragments.map { |fragment| result['markdown'].index(fragment) }

        expect(result).to include(
          'title' => 'Pakao za ministre i putare: Vučić će sve rupe imati "u džepu", ' \
                     'šta o tome kaže struka? - Društvo - Dnevni list Danas',
          'canonicalUrl' => url,
          'excerpt' => 'Predsednik Aleksandar Vučić ponovo „preti“ svojim ministrima, ovog puta ' \
                       'pokretanjem aplikacije putem koje će građani moći da prijavljuju rupe na ' \
                       'saobraćajnicama, a kojom će u svom „džepu“ imati pregled svih oštećenja ' \
                       'širom Srbije. Poručio je da će to biti „pakao“ za sve ministre ',
          'contentType' => 'article',
          'contentFormat' => nil,
          'hostAware' => true,
          'siteName' => 'Dnevni list Danas',
          'publishedTime' => '2026-07-06T21:02:14+02:00',
          'language' => 'sr',
          'readerMode' => false,
          'statusPage' => false,
          'paywallState' => nil,
          'warnings' => [],
          'suspect' => false
        )
        expect(positions).to all(be_a(Integer))
        expect(positions).to eq(positions.sort)
        expect(result['html']).to match(
          %r{<figure class="wp-caption aligncenter">\s*<img [^>]*src="https://www\.danas\.rs/wp-content/uploads/2026/03/11-6-e1774349681787\.jpg"[^>]*>\s*<figcaption class="wp-caption-text">Foto: Privatna arhiva</figcaption>\s*</figure>}
        )
        expect(result['html']).to include(
          '<blockquote class="wp-embedded-content"><p><a href="https://www.danas.rs/vesti/ekonomija/vucic-puetvi-rupe/">' \
          'Vučić: Na svom telefonu moći ću da vidim svaku rupu na putevima, to će biti „pakao“ za sve ministre i radnike</a></p></blockquote>',
          '<div class="tags"><a class="tag">Aleksandar Vučić</a><a class="tag">rupe</a></div>'
        )
        expect(result['markdown']).to include(
          '[Vučić: Na svom telefonu moći ću da vidim svaku rupu na putevima, to će biti „pakao“ za sve ministre i radnike]' \
          '(https://www.danas.rs/vesti/ekonomija/vucic-puetvi-rupe/)',
          'Aleksandar Vučić rupe'
        )
        expect(result['markdown']).not_to include(
          'Pratite nas na našoj Facebook i Instagram stranici',
          'Pretplatite se na PDF izdanje lista Danas',
          'Komentari',
          'Ostali komentari'
        )
        expect(page.evaluate('document.documentElement.outerHTML')).to eq(source)
      end
    end
  end
end
