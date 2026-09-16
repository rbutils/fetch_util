# frozen_string_literal: true

RSpec.describe 'FetchUtil Protothema extractor integration' do
  include_context 'extractor integration helpers'

  it 'extracts the complete article through the shared reader path without mutating the source' do
    fixture_path = File.expand_path('../../fixtures/protothema_article.html', __dir__)
    html = File.read(fixture_path)
    url = 'https://www.protothema.gr/greece/article/1847263/seismos-39-rihter-koda-stin-kissamo-hanion/'

    with_url_page(url, html) do |page|
      extractor_for(true).send(:inject_assets, page)
      before = page.evaluate('document.documentElement.outerHTML')
      payload = page.evaluate('window.FetchUtilExtract.extract({reader_mode: true})')
      markdown = payload.fetch('markdown')
      paragraphs = [
        'Σεισμική δόνηση μεγέθους 3,9 Ρίχτερ καταγράφηκε στην περιοχή της Κισσάμου Χανίων',
        'Ο σεισμός σημειώθηκε στις 01:18 μετά τα μεσάνυχτα της Τρίτης',
        'Η καταγραφή προέρχεται από την αυτόματη λύση του Γεωδυναμικού Ινστιτούτου'
      ]

      expect(payload).to include(
        'title' => 'Σεισμός 3,9 Ρίχτερ κοντά στην Κίσσαμο Χανίων',
        'siteName' => 'www.protothema.gr',
        'publishedTime' => '2026-07-08T01:25:00+03:00',
        'canonicalUrl' => url,
        'language' => 'el',
        'readerMode' => true,
        'contentType' => 'article',
        'hostAware' => false,
        'warnings' => [],
        'suspect' => false
      )
      expect(markdown).to include(
        'Η δόνηση σημειώθηκε το τα ξημερώματα της Τετάρτης, με εστιακό βάθος 5 χιλιομέτρων',
        '![Σεισμός 3,9 Ρίχτερ κοντά στην Κίσσαμο Χανίων](https://i1.prth.gr/images/1168x656/jpg/files/2026-07-08/mixcollage-08-jul-2026-01-25-am-3958.jpg)',
        '08.07.2026, 01:25',
        *paragraphs
      )
      paragraph_positions = paragraphs.map { |text| markdown.index(text) }
      expect(paragraph_positions).to all(be_a(Integer))
      expect(paragraph_positions).to eq(paragraph_positions.sort)
      expect(markdown).not_to include(
        'ΡΟΗ ΕΙΔΗΣΕΩΝ',
        'ΤΑ ΠΙΟ ΔΗΜΟΦΙΛΗ',
        'Games',
        'Άλλο άρθρο δοκιμής'
      )
      expect(payload.fetch('html')).not_to include('ΡΟΗ ΕΙΔΗΣΕΩΝ')
      expect(page.evaluate('document.documentElement.outerHTML')).to eq(before)
    end
  end

  it 'leaves the Protothema homepage to shared list extraction' do
    cards = (1..6).map do |index|
      <<~HTML
        <article>
          <a href="https://www.protothema.gr/greece/article/#{index}/story-#{index}/">
            <h2>Protothema homepage story #{index}</h2>
          </a>
        </article>
      HTML
    end.join

    with_url_page('https://www.protothema.gr/', "<main><h1>Protothema</h1>#{cards}</main>") do |page|
      payload = extract_payload(page, reader_mode: false)
      markdown = payload.fetch('markdown')

      expect(payload).to include('contentType' => 'list', 'hostAware' => false)
      story_positions = (1..6).map do |index|
        markdown.index(
          "[Protothema homepage story #{index}](https://www.protothema.gr/greece/article/#{index}/story-#{index}/)"
        )
      end
      expect(story_positions).to all(be_a(Integer))
      expect(story_positions).to eq(story_positions.sort)
    end
  end
end
