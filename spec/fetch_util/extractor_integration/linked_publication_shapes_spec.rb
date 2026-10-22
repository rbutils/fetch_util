# frozen_string_literal: true

RSpec.describe 'linked publication attribution shapes' do
  include_context 'extractor integration helpers'

  def publication_shape_record(label, author, kind:, profile: false)
    title = "Complete #{label} research report"
    prose = "The #{label} report preserves the complete evidence, the independent analysis, " \
            'and every published methodological qualification.'
    href = profile ? "/authors/#{label}" : "/reports/#{label}"
    case kind
    when :whole_link
      %(<a href="#{href}"><img src="/covers/#{label}.png" alt="Cover for #{label} report">) +
        %(<h3>#{title}</h3><p class="author">#{author}</p><p>#{prose}</p></a>)
    when :author_pair
      %(<div><a href="#{href}"><h2><address class="author">#{author}</address></h2></a>) +
        %(<h3><a href="#{href}">#{title}</a></h3><p>#{prose}</p></div>)
    when :unlinked_subtitle
      %(<div><a href="#{href}"><h2><address class="author">#{author}</address></h2></a>) +
        %(<h3>#{title}</h3><p>#{prose}</p></div>)
    when :linked_title
      %(<div><h6><a href="#{href}">#{title}</a></h6><p class="date-and-author">#{author}</p><p>#{prose}</p></div>)
    else
      raise "Unknown record kind: #{kind}"
    end
  end

  def publication_shape_page(records, cms: false)
    generator = cms ? '<meta name="generator" content="WordPress 6.8">' : ''
    heading_class = cms ? 'entry-title' : 'publication-heading'
    content_class = cms ? 'entry-content' : 'publication-content'
    <<~HTML
      <html><head><title>Research bulletins</title>#{generator}</head><body><main>
        <article id="post-42" class="type-page"><h1 class="#{heading_class}">Research bulletins</h1>
          <div class="#{content_class}">
            <p>This publication presents independently authored research, complete reports, and their public methodological evidence.</p>
            <section>#{records}</section>
          </div>
        </article>
      </main></body></html>
    HTML
  end

  def inspect_publication_shape(records, expected_byline, cms: false)
    with_url_page('https://journal.publication.example.test/bulletins/', publication_shape_page(records, cms: cms)) do |page|
      inject_standalone_extractor(page)
      before = page.evaluate('document.documentElement.outerHTML')
      payload = page.evaluate('window.FetchUtilExtract.extract({reader_mode: true})')
      expect(page.evaluate('document.documentElement.outerHTML')).to eq(before)
      expect(payload['byline']).to eq(expected_byline)
      expect(payload['markdown']).to include('Complete alpha research report')
      expect(payload['markdown']).to include('Ari Reader') if expected_byline.nil?
      expect(payload['markdown']).to include('The alpha report preserves the complete evidence, the independent analysis,')
      yield payload if block_given?
    end
  end

  it 'keeps a whole linked card author attached to its own title' do
    records = publication_shape_record('alpha', 'Ari Reader', kind: :whole_link) +
              publication_shape_record('beta', 'Bo Editor', kind: :whole_link) +
              publication_shape_record('gamma', 'Cy Writer', kind: :whole_link) +
              publication_shape_record('delta', 'Dee Reporter', kind: :whole_link)
    inspect_publication_shape(records, nil) do |payload|
      expect(payload['markdown']).to include('Bo Editor', 'Complete beta research report', '/reports/alpha', '/reports/beta')
      expect(payload['markdown']).to include('Cy Writer', 'Dee Reporter', '/reports/gamma', '/reports/delta')
    end
  end

  it 'associates a preceding author link with a title declaring the same publication' do
    records = publication_shape_record('alpha', 'Ari Reader', kind: :author_pair) +
              publication_shape_record('beta', 'Bo Editor', kind: :author_pair)
    inspect_publication_shape(records, nil) do |payload|
      expect(payload['markdown']).to include('Bo Editor', 'Complete beta research report', '/reports/alpha', '/reports/beta')
    end
  end

  it 'does not infer foreign ownership from one ambiguous author link and subtitle' do
    records = publication_shape_record('alpha', 'Ari Reader', kind: :unlinked_subtitle) +
              publication_shape_record('beta', 'Bo Editor', kind: :unlinked_subtitle)
    inspect_publication_shape(records, 'Ari Reader')
  end

  it 'preserves author profile attribution in otherwise parallel layouts' do
    records = publication_shape_record('alpha', 'Ari Reader', kind: :author_pair, profile: true) +
              publication_shape_record('beta', 'Bo Editor', kind: :author_pair, profile: true)
    inspect_publication_shape(records, 'Ari Reader')
  end

  it 'does not let a CMS fallback reborrow a rejected record author' do
    records = publication_shape_record('alpha', 'Ari Reader', kind: :linked_title) +
              publication_shape_record('beta', 'Bo Editor', kind: :linked_title)
    inspect_publication_shape(records, nil, cms: true) do |payload|
      expect(payload['markdown']).to include('/reports/alpha', '/reports/beta', 'Bo Editor')
    end
  end

  it 'does not mistake a title and navigation group for an author field' do
    records = '<div class="publication_writers_title"><h2>Recorded interviews</h2><a href="/interviews/">Browse interviews</a></div>'
    records += publication_shape_record('alpha', 'Ari Reader', kind: :linked_title)
    records += publication_shape_record('beta', 'Bo Editor', kind: :linked_title)
    inspect_publication_shape(records, nil) do |payload|
      expect(payload['markdown']).to include('Recorded interviews', 'Browse interviews')
    end
  end

  it 'preserves a genuinely linked author heading within a title-marked attribution group' do
    records = '<div class="publication_author_title"><h2><a rel="author" href="/authors/editorial/">Editorial Group</a></h2></div>'
    records += publication_shape_record('alpha', 'Ari Reader', kind: :linked_title)
    records += publication_shape_record('beta', 'Bo Editor', kind: :linked_title)
    inspect_publication_shape(records, 'Editorial Group')
  end

  it 'does not promote a publication-section heading to a page author' do
    records = '<div class="publication_writers_title"><h2>Selected reports</h2></div>'
    records += publication_shape_record('alpha', 'Ari Reader', kind: :linked_title)
    records += publication_shape_record('beta', 'Bo Editor', kind: :linked_title)
    inspect_publication_shape(records, nil) { |payload| expect(payload['markdown']).to include('Selected reports') }
  end

  it 'preserves an explicitly named author within a title-marked attribution group' do
    records = '<div class="publication_author_title"><h2 itemprop="name">Editorial Group</h2></div>'
    records += publication_shape_record('alpha', 'Ari Reader', kind: :linked_title)
    records += publication_shape_record('beta', 'Bo Editor', kind: :linked_title)
    inspect_publication_shape(records, 'Editorial Group')
  end
end
