# frozen_string_literal: true

RSpec.describe 'FetchUtil extractor integration - physical product family ownership' do
  include_context 'extractor integration helpers'

  def product_owner_source
    root = File.expand_path('../../..', __dir__)
    paths = File.readlines(File.join(root, 'websieve/manifest.txt'), chomp: true)
                .reject { |line| line.empty? || line.start_with?('#') }
    source = paths.map { |path| File.read(File.join(root, 'websieve', path)) }.join("\n")
    source.sub('})(window);', <<~JAVASCRIPT)
      global.productOwner = sourceOwnedProductContext;
      global.productResourcesAfterCleanup = function() {
        var root = document.createElement("article");
        productPhysicalResources(root, sourceOwnedProductContext({title: document.title}));
        return root.innerHTML;
      };
      })(window);
    JAVASCRIPT
  end

  def product_family_document(count, split: false)
    variants = (1..count).map do |index|
      { '@type' => 'Product', 'name' => "Atlas R100 variant #{index}", 'vehicleConfiguration' => "Variant #{index}" }
    end
    url = 'https://publication.example.test/products/r100'
    family = { '@type' => 'ProductGroup', '@id' => "#{url}#family", 'name' => 'Atlas R100', 'model' => 'R100', 'hasVariant' => variants }
    page = { '@type' => 'WebPage', '@id' => url, 'mainEntity' => { '@id' => family['@id'] } }
    questions = (1..count).map { |index| { '@type' => 'Question', 'name' => "What is specification #{index}?" } }
    faq = { '@type' => 'FAQPage', 'mainEntity' => questions }
    sections = (1..count).map do |index|
      <<~HTML
        <section><h2>Variant #{index}</h2><p>Published specification #{index} retains every measured figure and its qualification.
        The physical range is #{index + 300} miles and the displayed price is $#{index + 40_000}.</p>
        <a href="/specification/#{index}">Specification resource #{index}</a>
        <table><tr><th>Measure</th><th>Value</th></tr><tr><td>Range</td><td>#{index + 300} miles</td></tr></table></section>
      HTML
    end.join
    answers = (1..count).map do |index|
      "<section><h3>What is specification #{index}?</h3><p>Complete published answer #{index} explains the measured result and limitations.</p></section>"
    end.join
    heading = '<h1>R100</h1><p>The R100 family has complete published specifications and authored supporting documentation.</p>'
    content = if split
                "<main></main><div>#{heading}</div><div>#{sections}</div><div>#{answers}</div>"
              else
                "<main>#{heading}#{sections}#{answers}</main>"
              end
    <<~HTML
      <html><head><title>Atlas R100 product specifications</title>
      <script type="application/ld+json">#{[page, family, faq].to_json}</script></head>
      <body><nav><a href="/catalog">Unrelated catalogue</a></nav>#{content}
      <footer><p>Unrelated service directory</p></footer></body></html>
    HTML
  end

  it 'preserves every physically owned variant, price, table, resource and published answer' do
    html = product_family_document(160)
    with_url_page('https://publication.example.test/products/r100', html) do |page|
      page.add_script_tag(content: product_owner_source)
      expect(page.evaluate('productOwner({title: document.title}) !== null')).to be(true)
      payload = extract_payload(page)
      expect(payload['contentType']).to eq('product')
      expect(payload['publishedTime']).to be_nil
      (1..160).each do |index|
        expect(payload['html']).to include("Variant #{index}", "Complete published answer #{index}", "/specification/#{index}")
        expect(payload['markdown']).to include("$#{index + 40_000}", "#{index + 300} miles", "What is specification #{index}?")
      end
      expect(payload['html'].scan('<table').length).to eq(160)
      expect(payload['markdown']).not_to include('Unrelated catalogue', 'Unrelated service directory')
    end
  end

  it 'assembles the complete proved sibling interval without borrowing navigation or footer material' do
    html = product_family_document(3, split: true)
    extract_from_url('https://publication.example.test/products/r100', html) do |payload|
      (1..3).each { |index| expect(payload['markdown']).to include("Variant #{index}", "Complete published answer #{index}") }
      expect(payload['markdown']).not_to include('Unrelated catalogue', 'Unrelated service directory')
    end
  end

  it 'uses visible variant controls and untagged FAQ labels without materializing hidden answers' do
    html = product_family_document(2)
           .gsub(%r{<h2>(Variant \d+)</h2>}, '<button>\1</button>')
           .gsub(%r{<h3>(What is specification \d+\?)</h3>}, '<div>\1</div>')
           .sub('Complete published answer 2', '<span hidden>Undisclosed specification</span>Complete published answer 2')
           .sub('<body>', '<body><nav><div class="date">Model choices and build controls</div></nav>')
    extract_from_url('https://publication.example.test/products/r100', html) do |payload|
      expect(payload['markdown']).to include('Variant 1', 'Variant 2', 'What is specification 1?', 'What is specification 2?')
      expect(payload['markdown']).not_to include('Undisclosed specification')
      expect(payload['publishedTime']).to be_nil
    end
  end

  it 'retains a unique explicitly published date owned by the physical product body' do
    html = product_family_document(2)
           .sub('<h1>R100</h1>', '<h1>R100</h1><time itemprop="datePublished" datetime="2025-06-12">12 June 2025</time>')
    extract_from_url('https://publication.example.test/products/r100', html) do |payload|
      expect(payload['publishedTime']).to eq('2025-06-12')
      expect(payload['markdown']).to include('12 June 2025')
    end
  end

  it 'retains physically attributed product destinations removed with interface-shaped containers' do
    html = product_family_document(2).sub('</main>', <<~HTML)
      <svg aria-label="Hybrid Available" aria-hidden="true"><use href="#hybrid-symbol"></use></svg>
      <div class="newsletter-promo"><a href="/records/r100/one" aria-label="View R100 variant one details">View Details</a></div>
      <aside><a href="/unrelated" aria-label="View R100 unrelated service">Unrelated</a></aside>
      <div hidden><a href="/unmaterialized" aria-label="View R100 unmaterialized record">Unmaterialized</a></div>
      </main>
    HTML
    extract_from_url('https://publication.example.test/products/r100', html) do |payload|
      expect(payload['html']).to include('https://publication.example.test/records/r100/one')
      expect(payload['markdown']).to include('View R100 variant one details', '/records/r100/one')
      expect(payload['markdown']).to include('Hybrid Available')
      expect(payload['markdown']).not_to include('/unrelated', '/unmaterialized')
    end
  end

  it 'declines foreign identities, hidden witnesses and ambiguous physical owners' do
    html = product_family_document(2)
    variants = [
      html.sub('<h1>R100</h1>', '<h1>Foreign product</h1>'),
      html.sub('<main>', '<main hidden>'),
      html.sub('<h1>R100</h1>', '<h1>R100</h1><h1>R100</h1>'),
      html.sub('<h2>Variant 2</h2>', '<h2 hidden>Variant 2</h2>'),
      html.sub('<h3>What is specification 2?</h3>', '<h3 hidden>What is specification 2?</h3>'),
      html.sub('"model":"R100"', '"model":"Foreign"'),
      html.sub('"@type":"ProductGroup"', '"url":"https://foreign.example.test/product","@type":"ProductGroup"')
    ]
    variants.each do |source|
      with_url_page('https://publication.example.test/products/r100', source) do |page|
        page.add_script_tag(content: product_owner_source)
        expect(page.evaluate('productOwner({title: document.title}) === null')).to be(true)
      end
    end
  end

  it 'binds a source resource model across a printed year and an intervening declared brand' do
    html = product_family_document(2)
           .sub('"name":"Atlas R100"', '"name":"2026 R100"')
           .sub('<h1>R100</h1>', '<h1>2026 R100</h1>')
           .sub('</main>', <<~HTML)
             <div class="newsletter-promo">
             <a href="/configure/$(model=R100 R100)" aria-label="Build a 2026 Atlas R100">View Details</a></div>
             </main>
           HTML
    with_url_page('https://publication.example.test/products/r100', html) do |page|
      page.add_script_tag(content: product_owner_source)
      resources = page.evaluate('productResourcesAfterCleanup()')
      expect(resources).to include('Build a 2026 Atlas R100', '/configure/$%28model=R100%20R100%29')
    end
  end
end
