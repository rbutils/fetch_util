# frozen_string_literal: true

RSpec.describe 'FetchUtil commerce product-card extraction' do
  include_context 'extractor integration helpers'

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
