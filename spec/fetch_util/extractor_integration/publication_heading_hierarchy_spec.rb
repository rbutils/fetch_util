RSpec.describe 'Publication heading hierarchy and attribution' do
  include_context 'extractor integration helpers'

  let(:url) { 'https://journal.publication.example.test/bulletins' }

  def hierarchy_paragraphs
    (1..4).map do |number|
      "Report #{number} describes the complete local observations, the reporting method and the independently verified " \
        'publication context. Every authored sentence and reference belongs to its physical record and remains available.'
    end
  end

  def hierarchy_records(credits: true)
    hierarchy_paragraphs.each_with_index.map do |paragraph, index|
      number = index + 1
      credit = credits ? "<h6>By <a rel='author' href='/author/writer-#{number}'>Writer #{number}</a></h6>" : ''
      <<~HTML
        <div>
          <a href='/reports/report-#{number}'><img src='/covers/report-#{number}.jpg' alt='Report #{number} cover'></a>
          <div class='author_block'>
            <h4><a href='/collections/reporting'>Reporting</a></h4>
            <h3><a href='/reports/report-#{number}'>Report #{number}: Independent observations</a></h3>
            <p>#{paragraph}</p>
            #{credit}
          </div>
        </div>
      HTML
    end.join
  end

  def hierarchy_page(body, author: nil)
    meta = author ? "<meta name='author' content='#{author}'>" : ''
    <<~HTML
      <html><head><title>Publication index</title>#{meta}</head><body>
        <main><h1>Publication index</h1>#{body}</main>
      </body></html>
    HTML
  end

  def inspect_hierarchy(html, expected_byline, records: true)
    with_url_page(url, html) do |page|
      inject_standalone_extractor(page)
      before = page.evaluate('document.documentElement.outerHTML')
      payload = page.evaluate('window.FetchUtilExtract.extract({reader_mode: true})')
      expect(payload['byline']).to eq(expected_byline)
      paragraphs = records ? hierarchy_paragraphs : [hierarchy_paragraphs.first]
      paragraphs.each do |paragraph|
        expect(payload['html']).to include(paragraph)
        expect(payload['markdown']).to include(paragraph)
      end
      if records
        (1..4).each do |number|
          destination = "https://journal.publication.example.test/reports/report-#{number}"
          expect(payload['html']).to include(destination, "Report #{number}: Independent observations")
          expect(payload['markdown']).to include(destination, "Report #{number}: Independent observations")
        end
      end
      expect(page.evaluate('document.documentElement.outerHTML')).to eq(before)
      yield payload if block_given?
    end
  end

  it 'does not treat mixed-rank publication headings and their credits as a page author' do
    inspect_hierarchy(hierarchy_page(hierarchy_records), nil) do |payload|
      (1..4).each do |number|
        expect(payload['html']).to include("Writer #{number}")
        expect(payload['markdown']).to include("Writer #{number}")
      end
    end
  end

  it 'does not treat an attribution-marked category and publication group as a person' do
    inspect_hierarchy(hierarchy_page(hierarchy_records(credits: false)), nil)
  end

  it 'retains an independent page byline after bounded records with subordinate headings' do
    body = "#{hierarchy_records}<p class='byline'>Editorial Group</p>"
    inspect_hierarchy(hierarchy_page(body), 'Editorial Group')
  end

  it 'retains an explicitly linked author heading above an independent affiliation heading' do
    body = <<~HTML
      <div class='author_block'>
        <h3><a rel='author' href='/author/ari-reader'>Ari Reader</a></h3>
        <h4><a href='https://institute.publication.example.test/'>Research Institute</a></h4>
      </div>
      <p>#{hierarchy_paragraphs.first}</p>
    HTML
    inspect_hierarchy(hierarchy_page(body), 'Ari Reader', records: false)
  end

  it 'retains the explicitly declared page author independently of every publication credit' do
    inspect_hierarchy(hierarchy_page(hierarchy_records, author: 'Ari Reader'), 'Ari Reader')
  end

  it 'retains both equal-rank names in an attribution group' do
    paragraph = 'The jointly authored report retains every observation and reference in its physical publication context. ' \
      'Both contributors are independently presented at the same heading rank, and neither is an affiliation or section title.'
    html = <<~HTML
      <html><head><title>Publication index</title></head><body><main><h1>Publication index</h1>
        <div class='author_block'>
          <h3><a rel='author' href='/author/ari-reader'>Ari Reader</a></h3>
          <h3>Bo Editor</h3>
        </div><p>#{paragraph}</p>
      </main></body></html>
    HTML
    with_url_page('https://journal.publication.example.test/bulletins', html) do |page|
      inject_standalone_extractor(page)
      before = page.evaluate('document.documentElement.outerHTML')
      payload = page.evaluate('window.FetchUtilExtract.extract({reader_mode: true})')
      expect(payload['byline']).to eq('Ari Reader Bo Editor')
      expect(payload['html']).to include(paragraph)
      expect(payload['markdown']).to include(paragraph)
      expect(page.evaluate('document.documentElement.outerHTML')).to eq(before)
    end
  end
end
