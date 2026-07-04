# frozen_string_literal: true

RSpec.describe 'FetchUtil extractor integration' do
  include_context 'extractor integration helpers'

  it "removes badge and heading-anchor noise from markdown" do
    html = <<~HTML
      <html>
        <body>
          <main>
            <article>
              <p>
                <a href="https://ci.example.test"><img alt="build status" src="https://example.test/badge.svg"></a>
                <a href="https://coverage.example.test"><img alt="coverage badge" src="https://example.test/coverage.svg"></a>
              </p>
              <h2><a class="anchor" href="#what-is-ruby"></a>What is Ruby?</h2>
              <p>Ruby is a delightful programming language.</p>
            </article>
          </main>
        </body>
      </html>
    HTML

    with_page(html) do |page|
      payload = FetchUtil::Extractor.new(reader_mode: false).extract(page)

      expect(payload["markdown"]).to include("## What is Ruby?")
      expect(payload["markdown"]).to include("Ruby is a delightful programming language.")
      expect(payload["markdown"]).not_to include("badge")
      expect(payload["markdown"]).not_to include("[](#what-is-ruby)")
    end
  end

  it "extracts search results into compact bullets" do
    html = <<~HTML
      <html>
        <head><title>ruby language - Google Search</title></head>
        <body>
          <main>
            <div class="g">
              <a href="https://www.ruby-lang.org/en/"><h3>Ruby Programming Language</h3></a>
              <div>The official home of the Ruby programming language.</div>
            </div>
            <div class="g">
              <a href="https://en.wikipedia.org/wiki/Ruby_(programming_language)"><h3>Ruby - Wikipedia</h3></a>
              <div>Ruby is a general-purpose programming language.</div>
            </div>
            <div class="g">
              <a href="https://www.geeksforgeeks.org/ruby/ruby-programming-language/"><h3>Ruby Programming Language - GeeksForGeeks</h3></a>
              <div>Overview and examples for Ruby.</div>
            </div>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://www.google.com/search?q=ruby+language", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["contentType"]).to eq("search")
      expect(payload["markdown"]).to include("- [Ruby Programming Language](https://www.ruby-lang.org/en/)")
      expect(payload["warnings"]).not_to include("search_results_unusable")
    end
  end

  it "classifies legal search result pages with result cards as lists" do
    html = <<~HTML
      <html>
        <head><title>Search Results - EUR-Lex</title></head>
        <body>
          <main>
            <h1>Search Results</h1>
            <p>Results <strong>1</strong> - <strong>10</strong> of <strong>12089</strong></p>
            <section class="SearchResult">
              <h2><a href="/legal-content/AUTO/?uri=CELEX:32016R0679&amp;qid=123">Regulation (EU) 2016/679 on the protection of natural persons</a></h2>
              <p>OJ L 119, p. 1-88. In force. Languages: BG, ES, CS, DA, DE, EN, FR.</p>
            </section>
            <section class="SearchResult">
              <h2><a href="/legal-content/AUTO/?uri=CELEX:52020DC0264&amp;qid=123">Communication on data protection and privacy</a></h2>
              <p>European Commission document with privacy-related policy details.</p>
            </section>
            <section class="SearchResult">
              <h2><a href="/legal-content/AUTO/?uri=CELEX:32002L0058&amp;qid=123">Directive 2002/58/EC concerning privacy and electronic communications</a></h2>
              <p>Directive concerning the processing of personal data and privacy.</p>
            </section>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://eur-lex.example/search.html?type=quick&text=privacy", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["contentType"]).to eq("list")
      expect(payload["markdown"]).to include("Regulation (EU) 2016/679")
      expect(payload["warnings"]).not_to include("url_content_mismatch")
    end
  end

  it "keeps full search-result detail text in markdown bullets" do
    long_detail = [
      "Ruby keeps the full search detail text visible to downstream agents even when the snippet is long enough",
      "that older builds would have clipped it before the markdown payload was emitted."
    ].join(" ")
    html = <<~HTML
      <html>
        <head><title>ruby long result - Google Search</title></head>
        <body>
          <main>
            <div class="g">
              <a href="https://www.ruby-lang.org/en/long-result"><h3>Ruby long result</h3></a>
              <div>#{long_detail}</div>
            </div>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://www.google.com/search?q=ruby+long+result", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["contentType"]).to eq("search")
      expect(payload["markdown"]).to include("- [Ruby long result](https://www.ruby-lang.org/en/long-result) - #{long_detail}")
    end
  end

  it "extracts Amazon search pages into compact product bullets" do
    html = <<~HTML
      <html>
        <head><title>Amazon.com : ruby programming</title></head>
        <body>
          <main>
            <div data-component-type="s-search-result">
              <h2><a href="/dp/1"><span>Programming Ruby</span></a></h2>
              <span class="a-price"><span class="a-offscreen">$39.99</span></span>
              <span class="a-icon-alt">4.7 out of 5 stars</span>
            </div>
            <div data-component-type="s-search-result">
              <h2><a href="/dp/2"><span>Practical Object-Oriented Design in Ruby</span></a></h2>
              <span class="a-price"><span class="a-offscreen">$31.50</span></span>
            </div>
            <div data-component-type="s-search-result">
              <h2><a href="/dp/3"><span>Eloquent Ruby</span></a></h2>
              <span class="a-price"><span class="a-offscreen">$27.10</span></span>
            </div>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://www.amazon.com/s?k=ruby+programming", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["contentType"]).to eq("list")
      expect(payload["markdown"]).to include("- [Programming Ruby](https://www.amazon.com/dp/1) - $39.99 - 4.7 out of 5 stars")
      expect(payload["markdown"]).to include("- [Eloquent Ruby](https://www.amazon.com/dp/3) - $27.10")
    end
  end

  it "extracts Amazon product pages from description and bullets" do
    html = <<~HTML
      <html>
        <head>
          <title>Programming Ruby: A Pragmatic Programmer's Guide: Amazon.com: Books</title>
          <meta name="description" content="Programming Ruby: A Pragmatic Programmer's Guide on Amazon.com.">
          <script type="application/ld+json">
            {"@context":"https://schema.org","@type":"Product","name":"Programming Ruby","description":"A classic guide to the Ruby programming language.","offers":{"price":"39.99","priceCurrency":"USD","availability":"https://schema.org/InStock"},"aggregateRating":{"ratingValue":"4.8","reviewCount":"120"}}
          </script>
        </head>
        <body>
          <div id="productTitle">Programming Ruby</div>
          <a id="bylineInfo">Dave Thomas</a>
          <div id="feature-bullets">
            <ul>
              <li><span>Learn Ruby syntax and idioms.</span></li>
              <li><span>Includes practical examples and exercises.</span></li>
            </ul>
          </div>
          <div id="related-books">Other books by the Pragmatic Programmers</div>
        </body>
      </html>
    HTML

    with_url_page("https://www.amazon.com/Programming-Ruby/dp/0201710897", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["markdown"]).to include("# Programming Ruby")
      expect(payload["markdown"]).to include("A classic guide to the Ruby programming language.")
      expect(payload["markdown"]).to include("- Learn Ruby syntax and idioms.")
      expect(payload["markdown"]).to include("- Price: 39.99 USD")
      expect(payload["markdown"]).not_to include("Other books by the Pragmatic Programmers")
    end
  end

  it "extracts ebay search result pages into compact product bullets" do
    html = <<~HTML
      <html>
        <head>
          <title>Ruby Programming for sale | eBay</title>
          <meta name="description" content="Get the best deals for Ruby Programming at eBay.com.">
        </head>
        <body>
          <main>
            <ul class="srp-results">
              <li class="s-item">
                <a class="s-item__link" href="https://www.ebay.com/itm/1"><span>Programming Ruby</span></a>
                <span>$39.99</span>
                <span>Free shipping</span>
              </li>
              <li class="s-item">
                <a class="s-item__link" href="https://www.ebay.com/itm/2"><span>Practical Object-Oriented Design in Ruby</span></a>
                <span>$31.50</span>
              </li>
              <li class="s-item">
                <a class="s-item__link" href="https://www.ebay.com/itm/3"><span>Eloquent Ruby</span></a>
                <span>$27.10</span>
              </li>
              <li class="s-item">
                <a class="s-item__link" href="https://www.ebay.com/itm/4"><span>Metaprogramming Ruby</span></a>
                <span>$24.00</span>
              </li>
            </ul>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://www.ebay.com/robots.txt", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["contentType"]).to eq("list")
      expect(payload["markdown"]).to include("- [Programming Ruby](https://www.ebay.com/itm/1) - $39.99 Free shipping")
      expect(payload["markdown"]).to include("- [Metaprogramming Ruby](https://www.ebay.com/itm/4) - $24.00")
      expect(payload["warnings"]).not_to include("consent_interstitial")
    end
  end

  it "extracts generic catalog pages into compact product bullets when privacy chrome is present" do
    html = <<~HTML
      <html>
        <head>
          <title>Hayari Fragrances | Example Shop</title>
          <meta name="description" content="Shop the Hayari fragrance collection.">
        </head>
        <body>
          <section class="privacy-center">
            <h2>Protecting your Privacy Choices</h2>
            <p>We use cookies to provide a more personalized web experience.</p>
          </section>
          <main>
            <div class="product-grid">
              <article class="product-card">
                <a href="/perfume/hayari-goldy">Hayari Goldy</a>
                <span>$120.00</span>
              </article>
              <article class="product-card">
                <a href="/perfume/hayari-broderie">Hayari Broderie</a>
                <span>$118.00</span>
              </article>
              <article class="product-card">
                <a href="/perfume/hayari-amour-elegant">Hayari Amour Elegant</a>
                <span>Request it</span>
              </article>
              <article class="product-card">
                <a href="/perfume/hayari-joyeuse-no-3">Hayari Joyeuse No 3</a>
                <span>$125.00</span>
              </article>
            </div>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://example.com/fragrances/hayari-parfums", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["contentType"]).to eq("list")
      expect(payload["markdown"]).to include("- [Hayari Goldy](https://example.com/perfume/hayari-goldy) - $120.00")
      expect(payload["markdown"]).to include("- [Hayari Amour Elegant](https://example.com/perfume/hayari-amour-elegant) - Request it")
      expect(payload["markdown"]).not_to include("Protecting your Privacy Choices")
    end
  end

  it "summarizes Quora security pages with a question heading and warning" do
    html = <<~HTML
      <html>
        <head>
          <title>Just a moment...</title>
        </head>
        <body>
          <main>
            <h1>www.quora.com</h1>
            <p>Performing security verification</p>
            <p>This website uses a security service to protect against malicious bots.</p>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://www.quora.com/What-are-the-advantages-of-using-Proc-Lambda-in-Ruby?share=1", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["markdown"]).to include("# What are the advantages of using Proc Lambda in Ruby")
      expect(payload["warnings"]).to include("bot_or_access_interstitial")
    end
  end
end
