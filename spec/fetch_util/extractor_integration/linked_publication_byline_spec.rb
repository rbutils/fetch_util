# frozen_string_literal: true

RSpec.describe 'linked publication byline ownership' do
  include_context 'extractor integration helpers'

  def linked_record_paragraph(label)
    "The #{label} report documents the complete public evidence, its interpretation, " \
      'and the independently published methods.'
  end

  def linked_record(label, author, title_tag: 'h6', author_tag: 'p', title_class: '')
    <<~HTML
      <div>
        <#{title_tag} class="#{title_class}"><a href="/reports/#{label}">Complete #{label} research report</a></#{title_tag}>
        <#{author_tag} class="author">#{author}</#{author_tag}>
        <p>#{linked_record_paragraph(label)}</p>
      </div>
    HTML
  end

  def linked_publication_page(records, before: '', after: '', metadata: '')
    <<~HTML
      <html><head><title>Research bulletins</title>#{metadata}</head><body><main>
        <article class="type-page"><h1>Research bulletins</h1>
          <p>This publication presents independent research reports with their own titles, authors, and complete explanatory descriptions.</p>
          #{before}<section>#{records}</section>#{after}
        </article>
      </main></body></html>
    HTML
  end

  def inspect_linked_publication(html, expected_byline)
    with_url_page('https://journal.publication.example.test/bulletins/', html) do |page|
      inject_standalone_extractor(page)
      before = page.evaluate('document.documentElement.outerHTML')
      payload = page.evaluate('window.FetchUtilExtract.extract({reader_mode: true})')
      expect(page.evaluate('document.documentElement.outerHTML')).to eq(before)
      expect(payload['byline']).to eq(expected_byline)
      yield payload if block_given?
    end
  end

  it 'keeps a linked H6 record author out of page metadata' do
    records = linked_record('alpha', 'Ari Reader') + linked_record('beta', 'Bo Editor')
    inspect_linked_publication(linked_publication_page(records), nil) do |payload|
      expect(payload['markdown']).to include('Ari Reader', 'Bo Editor', 'Complete alpha research report', 'Complete beta research report')
      expect(payload['markdown']).to include(linked_record_paragraph('alpha'), linked_record_paragraph('beta'))
    end
  end

  it 'recognizes a linked title field without a semantic heading' do
    records = linked_record('alpha', 'Ari Reader', title_tag: 'div', title_class: 'publication-title') +
              linked_record('beta', 'Bo Editor', title_tag: 'div', title_class: 'publication-title')
    inspect_linked_publication(linked_publication_page(records), nil) do |payload|
      expect(payload['markdown']).to include('Ari Reader', 'Bo Editor', '/reports/alpha', '/reports/beta')
    end
  end

  it 'keeps a prefixed address author attached to its foreign H3' do
    records = linked_record('alpha', 'By Ari Reader', title_tag: 'h3', author_tag: 'address') +
              linked_record('beta', 'By Bo Editor', title_tag: 'h3', author_tag: 'address')
    inspect_linked_publication(linked_publication_page(records), nil) do |payload|
      expect(payload['markdown']).to include('Ari Reader', 'Bo Editor')
    end
  end

  it 'preserves a separately declared page author with the same name' do
    records = linked_record('alpha', 'Ari Reader') + linked_record('beta', 'Bo Editor')
    html = linked_publication_page(records, metadata: '<meta name="author" content="Ari Reader">')
    inspect_linked_publication(html, 'Ari Reader')
  end

  it 'preserves a global byline before an independently bounded child record' do
    record = linked_record('alpha', 'Ari Reader').sub('<div>', '<div role="listitem">')
    html = linked_publication_page("<div><span class=\"byline\">Editorial Group</span>#{record}</div>")
    inspect_linked_publication(html, 'Editorial Group')
  end

  it 'preserves a global byline after an independently bounded child record' do
    record = linked_record('alpha', 'Ari Reader').sub('<div>', '<div role="listitem">')
    html = linked_publication_page("<div>#{record}<span class=\"byline\">Editorial Group</span></div>")
    inspect_linked_publication(html, 'Editorial Group')
  end

  it 'does not interpret the current page title link as a foreign record' do
    html = linked_publication_page('<p class="author">Ari Reader</p><p>The current publication explains all of its research methods.</p>')
           .sub('<h1>Research bulletins</h1>', '<h1><a href="/bulletins/#top">Research bulletins</a></h1>')
    inspect_linked_publication(html, 'Ari Reader')
  end
end
