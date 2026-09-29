# frozen_string_literal: true

RSpec.describe 'FetchUtil inert custom UI cleanup' do
  include_context 'extractor integration helpers'

  it 'removes inert controls on an unknown host while retaining material and contextual labels' do
    html = <<~HTML
      <main>
        <article>
          <h1>Harbor council approves river plan</h1>
          <p>The council approved a restoration plan after a year of public review.</p>
          <demo-share>Share</demo-share>
          <x-related-article>أخبار ذات صلة</x-related-article>
          <custom-share>Share the full interview with the planning team, including its history and detailed review.</custom-share>
          <stock-share>Save</stock-share>
          <demo-share id="comment-control">Share<!-- keep article comment --></demo-share>
          <p>Officials described <q><quote-related-article>أخبار ذات صلة</quote-related-article></q> as an archive label, not a control.</p>
          <p><prose-related-article>أخبار ذات صلة</prose-related-article></p>
          <h2><heading-related-article>أخبار ذات صلة</heading-related-article></h2>
          <blockquote><quote-related-article>أخبار ذات صلة</quote-related-article></blockquote>
          <ul><li><demo-related-article>أخبار ذات صلة</demo-related-article></li></ul>
          <table><tbody><tr><td><demo-related-article>أخبار ذات صلة</demo-related-article></td></tr></tbody></table>
          <figure><figcaption><demo-related-article>أخبار ذات صلة</demo-related-article></figcaption></figure>
          <demo-related-article role="heading">أخبار ذات صلة</demo-related-article>
          <demo-related-article><a href="https://records.example.test/plan">Plan record</a></demo-related-article>
          <demo-related-article><img src="https://records.example.test/diagram.png" alt="Plan diagram"></demo-related-article>
        </article>
      </main>
    HTML

    with_url_page('https://unknown-host.example.test/article', html) do |page|
      source_body = page.evaluate('document.body.innerHTML')
      install_custom_ui_removal_counter(page)
      payload = extract_payload(page)
      output = payload.fetch('html')

      expect(payload['contentType']).to eq('article')
      expect(output).not_to include('x-related-article', 'شارك الخبر')
      expect(output.scan('Share the full interview').length).to eq(1)
      expect(output.scan('أخبار ذات صلة').length).to be >= 8
      expect(output).to include('Share the full interview', 'https://records.example.test/plan', 'https://records.example.test/diagram.png')
      expect(page.evaluate('document.body.innerHTML')).to eq(source_body)
      expect(custom_ui_removals(page).map { |entry| entry.fetch('name') }.uniq).to include('demo-share', 'x-related-article')
      expect(custom_ui_removals(page).map { |entry| entry.fetch('id') }).not_to include('comment-control')
      expect(custom_ui_removals(page).map { |entry| entry.fetch('name') }).not_to include(
        'stock-share', 'quote-related-article', 'prose-related-article', 'heading-related-article'
      )
    end
  end

  it 'preserves inert-looking custom hosts with open shadow content' do
    html = '<main><article><h1>Embedded report</h1><p>The report describes a detailed observation.</p><demo-share id="shadow-control">Share</demo-share></article></main>'

    with_url_page('https://another-unknown-host.example.test/report', html) do |page|
      source_body = page.evaluate('document.body.innerHTML')
      page.evaluate("document.querySelector('#shadow-control').attachShadow({mode: 'open'}).innerHTML = '<p>Share this embedded data visualization</p>'")
      payload = extract_payload(page)

      expect(payload.fetch('html')).to include('Share this embedded data visualization')
      expect(page.evaluate('document.body.innerHTML')).to eq(source_body)
    end
  end

  it 'cleans the unchanged article fixture on an unknown host through shared extraction' do
    fixture_path = File.expand_path('../../fixtures/skynewsarabia_article.html', __dir__)
    html = fixture_contents(fixture_path)

    with_url_page('https://unknown-host.example.test/middle-east/1879607-', html) do |page|
      source_body = page.evaluate('document.body.innerHTML')
      source_metadata = page.evaluate("JSON.stringify(Array.from(document.querySelectorAll('title, meta')).map(function(node) { return node.outerHTML; }))")
      inject_standalone_extractor(page)
      install_custom_ui_removal_counter(page)
      payload = page.evaluate('window.FetchUtilExtract.extract({reader_mode: true})')
      output = payload.fetch('html')

      expect(payload['hostAware']).to eq(false)
      expect(payload['contentType']).to eq('article')
      expect(payload['markdown']).not_to include('شارك الخبر', 'أخبار ذات صلة')
      expect(output).not_to include('sna-share', 'sna-related-article')
      expect(custom_ui_removals(page).map { |entry| entry.fetch('name') }.uniq).to contain_exactly('sna-share', 'sna-related-article')
      expect(page.evaluate('document.body.innerHTML')).to eq(source_body)
      expect(page.evaluate("JSON.stringify(Array.from(document.querySelectorAll('title, meta')).map(function(node) { return node.outerHTML; }))")).to eq(source_metadata)
    end
  end

  def install_custom_ui_removal_counter(page)
    page.evaluate(<<~JAVASCRIPT)
      (function() {
        window.__removedCustomUiRoles = [];
        var originalRemove = Element.prototype.remove;
        Element.prototype.remove = function() {
          if (/(?:^|-)(?:share|related(?:-article)?)$/i.test(this.localName || '')) {
            window.__removedCustomUiRoles.push({ name: this.localName, id: this.id, text: this.textContent });
          }
          return originalRemove.call(this);
        };
      })()
    JAVASCRIPT
  end

  def custom_ui_removals(page)
    page.evaluate('window.__removedCustomUiRoles')
  end
end
