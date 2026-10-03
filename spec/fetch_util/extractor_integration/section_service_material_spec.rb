# frozen_string_literal: true

RSpec.describe 'source-owned service material versus product navigation' do
  include_context 'extractor integration helpers'

  let(:fixture) { fixture_contents(File.expand_path('../../fixtures/derived_section_internal_016_service.html', __dir__)) }
  let(:url) { 'https://www.yna.co.kr/product/premium?site=footer_product_premium' }

  def section_loss_probe_source
    root = File.expand_path('../../..', __dir__)
    sources = File.readlines(File.join(root, 'websieve/manifest.txt'), chomp: true)
                  .reject { |line| line.empty? || line.start_with?('#') }
                  .map { |path| File.read(File.join(root, 'websieve', path)) }.join("\n")
    sources.sub('})(window);', 'window.checkCompleteSectionLoss = listCandidateLosesCompleteOwnedSections; })(window);')
  end

  it 'keeps the original section 016 service components instead of its four product tabs' do
    with_url_page(url, fixture) do |page|
      before = page.evaluate('document.body.innerHTML')
      source = page.evaluate <<~JS
        (() => {
          const owner = document.querySelector('#container');
          const text = selector => Array.from(owner.querySelectorAll(selector), node => node.textContent.trim().replace(/\\s+/g, ' '));
          return { paragraphs: text('p'), headings: text('h1, h2 > strong'), items: text('li'),
            images: Array.from(owner.querySelectorAll('img'), image => image.src) };
        })()
      JS
      payload = extract_payload(page)

      expect(source.fetch('paragraphs').length).to eq(5)
      expect(source.fetch('headings').length).to eq(2)
      expect(source.fetch('items').length).to eq(14)
      expect(source.fetch('images').length).to eq(2)
      expect(payload['contentType']).to eq('article')
      expect(payload['readerMode']).to be(true)
      compact = ->(text) { text.gsub(/[[:space:]\u00a0]+/, '') }
      source.fetch('paragraphs').each do |paragraph|
        expect(compact.call(payload['textContent'])).to include(compact.call(paragraph))
      end
      source.fetch('headings').each { |heading| expect(payload['markdown']).to include(heading) }
      source.fetch('items').each { |item| expect(compact.call(payload['textContent'])).to include(compact.call(item)) }
      source.fetch('images').each do |image|
        expect(payload['html']).to include(image)
        expect(payload['markdown']).to include(image)
      end
      expect(compact.call(payload['excerpt'])).to include(compact.call(source.fetch('paragraphs').first))
      expect(payload['markdown']).not_to include('Foreign publisher prose')
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end

  it 'keeps a query directory of independently described records despite foreign and hidden narrative' do
    records = (1..6).map do |index|
      <<~HTML
        <article class="result"><h2><a href="/product/results/#{index}">Product result #{index} for newsroom teams</a></h2>
          <p>Record #{index} describes its own separate newsroom subscription and price.</p></article>
      HTML
    end.join
    html = <<~HTML
      <html><head><title>Product search results</title></head><body><main>
        <h1>Product search results</h1><section class="results">#{records}</section>
      </main><aside><h2>Unrelated publisher story</h2>
        <p>Other publishers offer substantial background about unrelated news products.</p>
        <p>This independent paragraph must not become the directory's primary article.</p>
        <img src="https://example.org/foreign-one.png"><img src="https://example.org/foreign-two.png">
      </aside><div hidden><h2>Hidden narrative</h2><p>Invisible service prose.</p></div></body></html>
    HTML

    with_url_page('https://directory.example/product/search?q=newsroom', html) do |page|
      before = page.evaluate('document.body.innerHTML')
      payload = extract_payload(page)

      expect(payload['contentType']).to eq('list')
      (1..6).each do |index|
        expect(payload['markdown']).to include("Product result #{index} for newsroom teams")
        expect(payload['markdown']).to include("Record #{index} describes its own separate newsroom subscription and price")
      end
      expect(payload['markdown']).not_to include('Unrelated publisher story', 'Invisible service prose')
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end

  it 'requires a unique source ID and distinguishes encoded media from independently owned cards' do
    with_url_page(url, fixture) do |page|
      page.add_script_tag(content: section_loss_probe_source)
      result = page.evaluate <<~JS
        (() => {
          const owner = document.querySelector('#container');
          const before = document.body.innerHTML;
          const rendered = () => {
            const root = document.createElement('div');
            root.innerHTML = owner.outerHTML;
            return root;
          };
          const tabs = owner.querySelector('.tab-type71').innerHTML;
          const candidate = {html: tabs, markdown: tabs, textContent: tabs};
          const positive = checkCompleteSectionLoss({readerMode: true}, candidate, rendered());

          const duplicate = document.createElement('div');
          duplicate.id = owner.id;
          owner.parentNode.insertBefore(duplicate, owner);
          const ambiguous = checkCompleteSectionLoss({readerMode: true}, candidate, rendered());
          duplicate.remove();

          const image = owner.querySelector('img');
          const originalImage = image.getAttribute('src');
          image.setAttribute('src', 'https://example.org/service.png?edition=en&format=full');
          const complete = {html: owner.outerHTML, markdown: owner.textContent, textContent: owner.textContent};
          const encodedImage = complete.html.includes('edition=en&amp;format=full');
          const completeCandidate = checkCompleteSectionLoss({readerMode: true}, complete, rendered());
          image.setAttribute('src', originalImage);

          const record = document.createElement('li');
          record.innerHTML = '<article><h3><a href="/product/results/independent">Independent product record</a></h3>' +
            '<p>Its own separately described subscription and independently priced newsroom access.</p>' +
            '<img src="https://example.org/record.png" alt="Independent record"></article>';
          owner.querySelector('.tab-type71 ul').appendChild(record);
          const independent = checkCompleteSectionLoss({readerMode: true},
            {html: record.outerHTML, markdown: record.textContent, textContent: record.textContent}, rendered());
          record.remove();

          return {positive, ambiguous, encodedImage, completeCandidate, independent,
            sourceUnchanged: document.body.innerHTML === before};
        })()
      JS

      expect(result).to eq('positive' => true, 'ambiguous' => false, 'encodedImage' => true,
                           'completeCandidate' => false, 'independent' => false, 'sourceUnchanged' => true)
    end
  end
end
