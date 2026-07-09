# frozen_string_literal: true

RSpec.describe 'FetchUtil commerce product-card extraction' do
  include_context 'extractor integration helpers'

  it "classifies JSON-LD product detail pages and extracts offer price" do
    html = <<~HTML
      <html>
        <head>
          <title>Contoso Surface Dock | Microsoft Store</title>
          <meta property="og:type" content="product">
          <script type="application/ld+json">
            {
              "@context":"https://schema.org",
              "@type":"Product",
              "name":"Contoso Surface Dock",
              "description":"Connect monitors, accessories, and power with one compact dock for hybrid desks.",
              "sku":"SURFACE-DOCK-2",
              "offers":{"@type":"Offer","price":"199.99","priceCurrency":"USD","availability":"https://schema.org/InStock"}
            }
          </script>
        </head>
        <body>
          <main>
            <h1>Contoso Surface Dock</h1>
            <p>Connect monitors, accessories, and power with one compact dock for hybrid desks.</p>
            <section>
              <h2>Product details</h2>
              <p>Designed for modern workstations with fast charging, dual monitor output, and simple cable management.</p>
            </section>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://www.microsoft.com/en-us/d/contoso-surface-dock/abc123", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["contentType"]).to eq("product")
      expect(payload["price"]).to eq("$199.99")
      expect(payload["markdown"]).to include("- Price: $199.99")
      expect(payload["markdown"]).to include("- SKU: SURFACE-DOCK-2")
      expect(payload["suspect"]).to be(false)
    end
  end

  it "classifies DOM product detail pages and extracts visible price" do
    html = <<~HTML
      <html>
        <head><title>PlayBox Wireless Controller | Example Store</title></head>
        <body>
          <main itemscope itemtype="https://schema.org/Product">
            <h1 itemprop="name">PlayBox Wireless Controller</h1>
            <p itemprop="description">A responsive wireless controller with adaptive triggers, textured grips, and long battery life.</p>
            <span class="sku">SKU: PB-WIRELESS-BLUE</span>
            <div class="product-price" aria-label="Price $74.99">$74.99</div>
            <button type="button" data-testid="add-to-cart">Add to cart</button>
            <section>
              <h2>Features</h2>
              <p>Pairs quickly with consoles and PCs, includes USB-C charging, and supports low-latency gameplay.</p>
            </section>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://store.example.test/product/playbox-wireless-controller", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["contentType"]).to eq("product")
      expect(payload["price"]).to eq("$74.99")
      expect(payload["markdown"]).to include("- Price: $74.99")
      expect(payload["markdown"]).to include("PlayBox Wireless Controller")
      expect(payload["suspect"]).to be(false)
    end
  end

  it "surfaces JSON-LD product offer, rating, and availability details on category cards" do
    html = <<~HTML
      <html>
        <head>
          <title>Ruby Tools | Example Shop</title>
          <script type="application/ld+json">
            {
              "@context": "https://schema.org",
              "@type": "ItemList",
              "itemListElement": [
                {"@type":"ListItem","item":{"@type":"Product","name":"Ruby Parser Toolkit","url":"https://shop.example.test/product/ruby-parser-toolkit","offers":{"@type":"Offer","price":"49.95","priceCurrency":"USD","availability":"https://schema.org/InStock"},"aggregateRating":{"@type":"AggregateRating","ratingValue":"4.8","reviewCount":"128"}}},
                {"@type":"ListItem","item":{"@type":"Product","name":"Ruby Refactoring Cards","url":"https://shop.example.test/product/ruby-refactoring-cards","offers":{"@type":"Offer","price":"29.00","priceCurrency":"USD","availability":"https://schema.org/OutOfStock"},"aggregateRating":{"@type":"AggregateRating","ratingValue":"4.6","ratingCount":"42"}}},
                {"@type":"ListItem","item":{"@type":"Product","name":"Ruby Testing Notebook","url":"https://shop.example.test/product/ruby-testing-notebook","offers":{"@type":"Offer","price":"18.50","priceCurrency":"USD","availability":"https://schema.org/PreOrder"}}},
                {"@type":"ListItem","item":{"@type":"Product","name":"Ruby Deployment Checklist","url":"https://shop.example.test/product/ruby-deployment-checklist","offers":{"@type":"Offer","price":"12.00","priceCurrency":"USD","availability":"https://schema.org/InStock"}}}
              ]
            }
          </script>
        </head>
        <body>
          <main>
            <section class="product-grid">
              <article class="product-card"><a href="/product/ruby-parser-toolkit">Ruby Parser Toolkit</a></article>
              <article class="product-card"><a href="/product/ruby-refactoring-cards">Ruby Refactoring Cards</a></article>
              <article class="product-card"><a href="/product/ruby-testing-notebook">Ruby Testing Notebook</a></article>
              <article class="product-card"><a href="/product/ruby-deployment-checklist">Ruby Deployment Checklist</a></article>
            </section>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://shop.example.test/category/ruby-tools", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["contentType"]).to eq("list")
      expect(payload["markdown"]).to include(
        "- [Ruby Parser Toolkit](https://shop.example.test/product/ruby-parser-toolkit) - " \
        "$49.95 - Rating: 4.8/5 from 128 reviews - In Stock"
      )
      expect(payload["markdown"]).to include(
        "- [Ruby Refactoring Cards](https://shop.example.test/product/ruby-refactoring-cards) - " \
        "$29.00 - Rating: 4.6/5 from 42 reviews - Out Of Stock"
      )
    end
  end

  it "surfaces DOM-only price, rating, review count, and stock details on product cards" do
    html = <<~HTML
      <html>
        <head><title>Ruby Workbench Sale | Example Store</title></head>
        <body>
          <main>
            <div class="product-list">
              <article class="product-card">
                <a href="/product/ruby-workbench-starter">Ruby Workbench Starter</a>
                <span class="price">$19.99</span>
                <span class="rating" aria-label="4.4 out of 5 stars">4.4</span>
                <span class="review-count">86 reviews</span>
                <span class="stock">In stock</span>
              </article>
              <article class="product-card">
                <a href="/product/ruby-workbench-pro">Ruby Workbench Pro</a>
                <span itemprop="price" content="59.00"></span>
                <meta itemprop="priceCurrency" content="USD">
                <span itemprop="ratingValue">4.9</span>
                <span itemprop="reviewCount">211</span>
                <link itemprop="availability" href="https://schema.org/InStock">
              </article>
              <article class="product-card">
                <a href="/product/ruby-workbench-field-guide">Ruby Workbench Field Guide</a>
                <span class="price">$24.50</span>
                <span class="availability">Sold out</span>
              </article>
              <article class="product-card">
                <a href="/product/ruby-workbench-pocket-pack">Ruby Workbench Pocket Pack</a>
                <span class="price">$9.95</span>
                <span>Free shipping</span>
              </article>
            </div>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://store.example.test/category/ruby-workbench", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["contentType"]).to eq("list")
      expect(payload["markdown"]).to include(
        "- [Ruby Workbench Starter](https://store.example.test/product/ruby-workbench-starter) - " \
        "$19.99 - Rating: 4.4/5 from 86 reviews - In stock"
      )
      expect(payload["markdown"]).to include(
        "- [Ruby Workbench Pro](https://store.example.test/product/ruby-workbench-pro) - " \
        "$59.00 - Rating: 4.9/5 from 211 reviews - In Stock"
      )
      expect(payload["markdown"]).to include("- [Ruby Workbench Field Guide](https://store.example.test/product/ruby-workbench-field-guide) - $24.50 - Sold out")
    end
  end

  it "extracts compact marketplace cards from image and aria-label product links" do
    html = <<~HTML
      <html>
        <head><title>Desks | Office Furniture &amp; Home Desk</title></head>
        <body>
          <main>
            <section data-hb-id="BrowseProductGrid">
              <div data-hb-id="ProductCard">
                <a href="/furniture/pdp/inbox-zero-l-shaped-standing-desk-adjustable-height-electric-desk-with-memory-controller-w113542819.html" aria-label="L-shaped Standing Desk Adjustable Height Electric Desk Memory Controller">
                  <span>July 4th Deal</span>
                  <img alt="L-shaped Standing Desk Adjustable Height Electric Desk Memory Controller">
                </a>
                <p>The L-shaped standing desk is perfect for home offices, gaming, and multi-device setups. Its spacious design maximizes workspace efficiency while reviews and buying-guide copy make generic article extraction noisy.</p>
                <span>$179.99</span>
              </div>
              <div data-hb-id="ProductCard">
                <a href="/furniture/pdp/latitude-run-fort-myers-reversible-multi-functional-desk-with-storage-drawers-and-open-shelving-w006001447.html" aria-label="Fort Myers Reversible Multi-Functional Desk Storage Drawers Open Shelving"></a>
                <p>This multi-functional desk features a clean-lined silhouette with a multi-level design that is ideal for gaming or a productive workspace.</p>
                <span>$149.99 was $173.99</span>
              </div>
              <div data-hb-id="ProductCard">
                <a href="/furniture/pdp/martha-stewart-hutton-shaker-style-home-office-desk-with-storage-mstt5903.html">
                  <img alt="Martha Stewart Hutton Shaker Style Home Office Desk with Storage">
                </a>
                <p>The Martha Stewart Hutton Home Office Desk adds timeless elegance and functional storage to any workspace.</p>
                <span>$299.00</span>
              </div>
              <div data-hb-id="ProductCard">
                <a href="/furniture/pdp/ebern-designs-jasine-desk-w111204350.html" aria-label="Office Desk"></a>
                <p>This computer desk provides a comfortable workspace with a clean, modern design, ideal for a home office or study area.</p>
                <span>Rated 4.7 out of 5 stars. 871 total votes</span>
                <span>$219.99</span>
              </div>
            </section>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://www.wayfair.com/furniture/sb0/desks-c1780384.html?redir=desk", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["contentType"]).to eq("list")
      expect(payload["markdown"]).to include(
        "- [Fort Myers Reversible Multi-Functional Desk Storage Drawers Open Shelving]" \
        "(https://www.wayfair.com/furniture/pdp/" \
        "latitude-run-fort-myers-reversible-multi-functional-desk-with-storage-drawers-and-open-shelving-w006001447.html) - $149.99"
      )
      expect(payload["markdown"]).to include(
        "- [Martha Stewart Hutton Shaker Style Home Office Desk with Storage]" \
        "(https://www.wayfair.com/furniture/pdp/martha-stewart-hutton-shaker-style-home-office-desk-with-storage-mstt5903.html) - $299.00"
      )
      expect(payload["markdown"]).not_to include("reviews and buying-guide copy")
    end
  end

  it "prefers compact product cards over promo-heavy marketplace list output" do
    html = <<~HTML
      <html>
        <head><title>ssd - Search Results | Example Marketplace</title></head>
        <body>
          <main>
            <p>+ $50 off w/ promo code JSF583, limited offer</p>
            <p>By clicking Submit above, you consent to allow Example Marketplace to store and process personal information.</p>
            <div class="item-cells-wrap items-list-view is-list">
              <div class="item-cell">
                <div class="item-container">
                  <a href="/samsung-2tb-990-pro-nvme-2-0/p/N82E16820147861" class="item-img"><img alt="SAMSUNG 990 PRO 2TB SSD"></a>
                  <div class="item-info"><a href="/samsung-2tb-990-pro-nvme-2-0/p/N82E16820147861" class="item-title">SAMSUNG 990 PRO 2TB SSD, PCIe Gen4 M.2 2280</a></div>
                  <div class="item-action"><ul class="price"><li class="price-current">$<strong>369</strong><sup>.99</sup></li></ul></div>
                </div>
              </div>
              <div class="item-cell"><a href="/crucial-2tb-p310-nvme/p/N82E16820156413" class="item-title">Crucial P310 M.2 2280 2TB PCI-Express 4.0 x4 NVMe SSD</a><span class="price-current">$290.95</span></div>
              <div class="item-cell"><a href="/western-digital-2tb-sn7100-nvme/p/N82E16820250275" class="item-title">WD_BLACK SN7100 M.2 2280 2TB PCI-Express 4.0 x4 SSD</a><span class="price-current">$275.49</span></div>
              <div class="item-cell"><a href="/samsung-4tb-990-pro-nvme-2-0/p/N82E16820147879" class="item-title">SAMSUNG 990 PRO SSD 4TB</a><span class="price-current">$779.95</span></div>
            </div>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://www.newegg.com/p/pl?d=ssd", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["contentType"]).to eq("list")
      expect(payload["markdown"]).to include(
        "- [SAMSUNG 990 PRO 2TB SSD, PCIe Gen4 M.2 2280]" \
        "(https://www.newegg.com/samsung-2tb-990-pro-nvme-2-0/p/N82E16820147861) - $369.99"
      )
      expect(payload["markdown"]).to include(
        "- [WD_BLACK SN7100 M.2 2280 2TB PCI-Express 4.0 x4 SSD]" \
        "(https://www.newegg.com/western-digital-2tb-sn7100-nvme/p/N82E16820250275) - $275.49"
      )
      expect(payload["markdown"]).not_to include("promo code")
      expect(payload["markdown"]).not_to include("By clicking Submit")
    end
  end

  it "does not fabricate commerce details on non-commerce list pages" do
    html = <<~HTML
      <html>
        <head><title>Ruby Blog Index</title></head>
        <body>
          <main>
            <article><h2><a href="/posts/parser-combinators">Parser combinators for Ruby agents</a></h2><p>Notes from a recent implementation.</p></article>
            <article><h2><a href="/posts/refactoring-small-objects">Refactoring small Ruby objects</a></h2><p>How we split responsibilities.</p></article>
            <article><h2><a href="/posts/testing-browser-flows">Testing browser-backed extraction flows</a></h2><p>Fixture patterns and tradeoffs.</p></article>
            <article><h2><a href="/posts/markdown-cleanup">Markdown cleanup for agent readers</a></h2><p>Keeping output compact.</p></article>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://blog.example.test/posts", html) do |page|
      payload = FetchUtil::Extractor.new(reader_mode: false).extract(page)

      expect(payload["contentType"]).to eq("list")
      expect(payload["markdown"]).to include("- [Parser combinators for Ruby agents](https://blog.example.test/posts/parser-combinators)")
      expect(payload["markdown"]).not_to include("Rating:")
      expect(payload["markdown"]).not_to include("In Stock")
      expect(payload["markdown"]).not_to match(/\$\d/)
    end
  end
end
