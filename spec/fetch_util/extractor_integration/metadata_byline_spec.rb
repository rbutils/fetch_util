# frozen_string_literal: true

RSpec.describe 'metadata byline ownership' do
  include_context 'extractor integration helpers'

  def list_page(global_byline: nil)
    metadata = global_byline ? %(<meta name="author" content="#{global_byline}">) : ''
    <<~HTML
      <html><head><title>Regional reports</title>#{metadata}</head><body><main>
        <h1>Regional reports</h1>
        <section class="report-grid">
          <article>
            <h2><a href="/reports/one">Regional employers publish their annual outlook</a></h2>
            <p class="author">Alice Brown</p>
            <p>The first report explains employment changes across several industries and the plans organizations announced for the coming year.</p>
          </article>
          <article>
            <h2><a href="/reports/two">Community groups expand the public events calendar</a></h2>
            <p class="author">Carol Davis</p>
            <p>The second report describes new public events, workshops, and partnerships planned by community organizations throughout the region.</p>
          </article>
          <article>
            <h2><a href="/reports/three">Schools coordinate a regional science program</a></h2>
            <p class="author">Daniel Evans</p>
            <p>The third report covers a shared science program that will connect schools, libraries, and local research institutions.</p>
          </article>
          <article>
            <h2><a href="/reports/four">Libraries extend access to regional archives</a></h2>
            <p class="author">Evelyn Flores</p>
            <p>The fourth report describes a coordinated archive project that will improve public access to local historical collections.</p>
          </article>
        </section>
      </main></body></html>
    HTML
  end

  def extract_without_source_mutation(page)
    inject_standalone_extractor(page)
    before = page.evaluate('document.documentElement.outerHTML')
    payload = page.evaluate('window.FetchUtilExtract.extract({reader_mode: true})')
    expect(page.evaluate('document.documentElement.outerHTML')).to eq(before)
    payload
  end

  it 'does not promote one record author to a page-level list byline' do
    html = list_page

    with_url_page('https://example.test/reports/', html) do |page|
      payload = extract_without_source_mutation(page)

      expect(payload).to include('contentType' => 'list', 'byline' => nil)
      expect(payload['markdown']).to include('Alice Brown', 'Carol Davis', 'Daniel Evans', 'Evelyn Flores')
    end
  end

  it 'does not promote an author shared by several records to a page-level list byline' do
    html = list_page.gsub('Carol Davis', 'Alice Brown').gsub('Daniel Evans', 'Alice Brown')

    with_url_page('https://example.test/reports/', html) do |page|
      payload = extract_without_source_mutation(page)

      expect(payload).to include('contentType' => 'list', 'byline' => nil)
      expect(payload['markdown'].scan('Alice Brown').length).to eq(3)
      expect(payload['markdown']).to include('Evelyn Flores')
    end
  end

  it 'does not mistake an author inside an unsemantic div card for a global byline' do
    html = list_page.gsub('<article>', '<div class="card">').gsub('</article>', '</div>')

    extract_from_url('https://example.test/reports/', html) do |payload|
      expect(payload).to include('contentType' => 'list', 'byline' => nil)
      expect(payload['markdown']).to include('Alice Brown', 'Carol Davis', 'Daniel Evans', 'Evelyn Flores')
    end
  end

  it 'preserves a byline independently declared by page metadata' do
    extract_from_url('https://example.test/reports/', list_page(global_byline: 'Alice Brown')) do |payload|
      expect(payload).to include('contentType' => 'list', 'byline' => 'Alice Brown')
    end
  end

  it 'prefers either article-specific author metadata form over generic site authorship' do
    ['name', 'property'].each do |attribute|
      html = list_page(global_byline: 'Reports Journal').sub(
        '<meta name="author" content="Reports Journal">',
        %(<meta name="author" content="Reports Journal"><meta #{attribute}="article:author" content="Alice Brown">)
      )

      extract_from_url('https://example.test/reports/', html) do |payload|
        expect(payload).to include('contentType' => 'list', 'byline' => 'Alice Brown')
      end
    end
  end

  it 'preserves a byline independently rendered for the whole list page' do
    html = list_page.sub('Alice Brown', 'Regional Desk').sub(
      '<h1>Regional reports</h1>',
      '<h1>Regional reports</h1><span class="byline">Regional Desk</span>'
    )

    with_url_page('https://example.test/reports/', html) do |page|
      payload = extract_without_source_mutation(page)
      expect(payload).to include('contentType' => 'list', 'byline' => 'Regional Desk')
      expect(payload['markdown']).to include('Regional Desk')
    end
  end

  it 'preserves a global byline inside a page wrapper around multiple records' do
    html = list_page.gsub('<article>', '<div class="card">').gsub('</article>', '</div>')
    html = html.sub('Alice Brown', 'Regional Desk')
    html = html.sub('<main>', '<main><article class="page-wrapper"><span class="byline">Regional Desk</span>')
    html = html.sub('</main>', '</article></main>')

    with_url_page('https://example.test/reports/', html) do |page|
      payload = extract_without_source_mutation(page)
      expect(payload).to include('contentType' => 'list', 'byline' => 'Regional Desk')
      expect(payload['markdown']).to include('Regional Desk')
    end
  end

  it 'preserves a global byline in a wrapper that contains one of several records' do
    html = list_page.gsub('<article>', '<div class="card" role="listitem">').gsub('</article>', '</div>')
    html = html.sub('Alice Brown', 'Regional Desk')
    html = html.sub(
      '<section class="report-grid">',
      '<section class="report-grid" role="list"><div class="page-wrapper"><span class="byline">Regional Desk</span>'
    )
    html = html.sub(%r{</div>(?=\s*<div class="card" role="listitem">)}, '</div></div>')

    with_url_page('https://example.test/reports/', html) do |page|
      expect(page.evaluate("document.querySelector('a[href=\"/reports/one\"]').closest('.page-wrapper') !== null")).to be(true)
      expect(page.evaluate("document.querySelector('a[href=\"/reports/two\"]').closest('.page-wrapper') === null")).to be(true)
      expect(page.evaluate("document.querySelector('.page-wrapper').querySelectorAll(':scope > [role=\"listitem\"]').length")).to eq(1)
      payload = extract_without_source_mutation(page)
      expect(payload).to include('contentType' => 'list', 'byline' => 'Regional Desk')
    end
  end

  it 'does not change article bylines' do
    html = <<~HTML
      <html><head><title>Regional report</title></head><body><main><article>
        <h1>Regional report</h1>
        <p class="author">Alice Brown</p>
        <p>This article contains a substantial opening paragraph about regional institutions and their plans for the coming year.</p>
        <p>A second substantial paragraph provides further context and confirms that this page is one article rather than a collection.</p>
      </article></main></body></html>
    HTML

    extract_from_url('https://example.test/reports/one', html) do |payload|
      expect(payload).to include('contentType' => 'article', 'byline' => 'Alice Brown')
    end
  end
end
