RSpec.describe 'Unlinked publication titles and attribution ownership' do
  include_context 'extractor integration helpers'

  let(:url) { 'https://journal.publication.example.test/bulletins' }

  def publication_paragraph(number)
    "Report #{number} describes the complete local observations, the reporting method and the independently verified " \
      'publication context. Every authored sentence and reference belongs to its physical record and remains available.'
  end

  def publication_record(number, navigation: :overlay, destination: nil, link_class: 'post-link', competing: false)
    destination ||= "/reports/report-#{number}"
    title = "Report #{number}: Independent observations"
    paragraph = publication_paragraph(number)
    heading = "<h1>#{title}</h1>"
    heading += '<h1>Another independent publication</h1>' if competing
    credit = "<div class='post-authors'><span>Ari Reader</span></div>"
    content = <<~HTML
      <div class='content-wrap'>
        <img src='/covers/report-#{number}.jpg' alt='Report #{number} cover'>
        #{heading}<p>#{paragraph}</p>#{credit}
        <p><a href='/references/report-#{number}'>Complete reference #{number}</a></p>
      </div>
    HTML
    if navigation == :overlay
      "<div class='post-wrap'><a class='#{link_class}' href='#{destination}'></a>#{content}</div>"
    else
      assignment = navigation == :mismatch ? '/reports/another-report' : destination
      <<~HTML
        <div class='slide' onclick='location.href="#{assignment}"'>
          #{content}<div><a href='#{destination}'>Read the report</a></div>
        </div>
      HTML
    end
  end

  def publication_page(body, author: nil)
    meta = author ? "<meta name='author' content='#{author}'>" : ''
    "<html><head><title>Publication index</title>#{meta}</head><body><main>#{body}</main></body></html>"
  end

  def inspect_publication(html, expected_byline, records: 4)
    with_url_page(url, html) do |page|
      inject_standalone_extractor(page)
      before = page.evaluate('document.documentElement.outerHTML')
      payload = page.evaluate('window.FetchUtilExtract.extract({reader_mode: true})')
      expect(payload['byline']).to eq(expected_byline)
      (1..records).each do |number|
        paragraph = publication_paragraph(number)
        destination = "https://journal.publication.example.test/references/report-#{number}"
        expect(payload['html']).to include(paragraph, destination)
        expect(payload['markdown']).to include(paragraph, destination)
      end
      expect(page.evaluate('document.documentElement.outerHTML')).to eq(before)
    end
  end

  it 'keeps credits with publications declared by direct empty covering links' do
    records = (1..4).map { |number| publication_record(number) }.join
    inspect_publication(publication_page(records), nil)
  end

  it 'keeps credits with a literal navigation owner confirmed by its own readable link' do
    records = (1..4).map { |number| publication_record(number, navigation: :literal) }.join
    inspect_publication(publication_page(records), nil)
  end

  it 'preserves a global author outside an independently bounded publication' do
    records = (1..4).map { |number| publication_record(number) }.join
    inspect_publication(publication_page("#{records}<p class='byline'>Editorial Group</p>"), 'Editorial Group')
  end

  it 'preserves a declared page author independently of the child credits' do
    records = (1..4).map { |number| publication_record(number, navigation: :literal) }.join
    inspect_publication(publication_page(records, author: 'Editorial Group'), 'Editorial Group')
  end

  it 'does not assign a current-page link to a foreign publication' do
    inspect_publication(publication_page(publication_record(1, destination: '/bulletins')), 'Ari Reader', records: 1)
  end

  it 'does not turn an author-profile destination into publication ownership' do
    record = publication_record(1, destination: '/author/ari-reader')
    inspect_publication(publication_page(record), 'Ari Reader', records: 1)
  end

  it 'does not use an unrelated empty interface link as a covering declaration' do
    record = publication_record(1, link_class: 'share-link')
    inspect_publication(publication_page(record), 'Ari Reader', records: 1)
  end

  it 'keeps attribution when the literal navigation and readable destination disagree' do
    record = publication_record(1, navigation: :mismatch)
    inspect_publication(publication_page(record), 'Ari Reader', records: 1)
  end

  it 'does not infer a principal publication from equally ranked competing titles' do
    inspect_publication(publication_page(publication_record(1, competing: true)), 'Ari Reader', records: 1)
  end

  def anchorless_publication(number)
    <<~HTML
      <div onclick='location.href="/reports/report-#{number}"'>
        <div class='selected_author'><h6>Ari Reader</h6></div>
        <div><h2>Independent report #{number}</h2>
          <p>Report #{number} preserves the full observations and the independently documented reporting method.
          The publication owns this credit, its complete prose and its explicitly declared navigation destination.</p>
        </div>
      </div>
    HTML
  end

  def inspect_anchorless_publications(count, expected_byline)
    body = (1..count).map { |number| anchorless_publication(number) }.join
    html = "<html><head><title>Publication index</title></head><body><main><div>#{body}</div></main></body></html>"
    with_url_page('https://journal.publication.example.test/bulletins', html) do |page|
      inject_standalone_extractor(page)
      before = page.evaluate('document.documentElement.outerHTML')
      payload = page.evaluate('window.FetchUtilExtract.extract({reader_mode: true})')
      expect(payload['byline']).to eq(expected_byline)
      (1..count).each do |number|
        sentence = "Report #{number} preserves the full observations and the independently documented reporting method."
        expect(payload['html']).to include(sentence)
        expect(payload['markdown']).to include(sentence)
      end
      expect(page.evaluate('document.documentElement.outerHTML')).to eq(before)
    end
  end

  it 'keeps attribution with independently navigating sibling publications' do
    inspect_anchorless_publications(3, nil)
  end

  it 'retains attribution for a lone unresolved literal navigation owner' do
    inspect_anchorless_publications(1, 'Ari Reader')
  end

  it 'does not parse a compound script as a literal publication declaration' do
    record = publication_record(1, navigation: :literal).sub('location.href=', 'recordVisit(); location.href=')
    inspect_publication(publication_page(record), 'Ari Reader', records: 1)
  end
end
