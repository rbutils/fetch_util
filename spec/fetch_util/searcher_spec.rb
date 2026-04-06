# frozen_string_literal: true

RSpec.describe FetchUtil::Searcher do
  let(:request_log) { instance_double(FetchUtil::RequestLog, append: nil) }
  let(:fetcher) { instance_double(FetchUtil::ParallelFetcher) }

  it "logs a pseudo-url and aggregates compact interleaved results" do
    duck = instance_double(
      FetchUtil::Result,
      markdown: <<~MARKDOWN
        - [Ruby Programming Language](https://www.ruby-lang.org/en/) - ruby-lang.org
        - [Ruby (programming language) - Wikipedia](https://en.wikipedia.org/wiki/Ruby_(programming_language)) - en.wikipedia.org
        - [Introduction to Ruby](https://ruby-doc.org/docs/Tutorial/)
      MARKDOWN
    )
    brave = instance_double(
      FetchUtil::Result,
      markdown: <<~MARKDOWN
        - [Downloads](https://www.ruby-lang.org/en/downloads/) - Install Ruby on Windows, macOS, Linux, and more.
        - [Ruby Programming Language](https://www.ruby-lang.org/en/) - Official home page for Ruby.
        - [More on reddit.com](https://www.reddit.com/r/ruby/comments/1)
        - [Semantics and philosophy](https://en.wikipedia.org/wiki/Ruby_(programming_language)#Semantics_and_philosophy) - HistoryFeaturesSyntaxImplementations
        - [Libraries](https://www.ruby-lang.org/en/libraries/) - Ruby has a wide ecosystem of third-party libraries.
      MARKDOWN
    )

    expect(request_log).to receive(:append).with("search://duckduckgo,brave?q=ruby+language")
    expect(fetcher).to receive(:fetch).with([
                                              "https://duckduckgo.com/?q=ruby+language&ia=web&kl=us-en",
                                              "https://search.brave.com/search?q=ruby+language"
                                            ]).and_return([duck, brave])

    payload = described_class.new(
      fetcher: fetcher,
      request_log: request_log,
      sources: %w[duckduckgo brave]
    ).search("ruby language")

    expect(payload[:query]).to eq("ruby language")
    expect(payload[:results]).to eq([
                                      {
                                        title: "Ruby Programming Language",
                                        url: "https://www.ruby-lang.org/en",
                                        snippet: "Official home page for Ruby."
                                      },
                                      {
                                        title: "Downloads",
                                        url: "https://www.ruby-lang.org/en/downloads",
                                        snippet: "Install Ruby on Windows, macOS, Linux, and more."
                                      },
                                      {
                                        title: "Ruby (programming language) - Wikipedia",
                                        url: "https://en.wikipedia.org/wiki/Ruby_(programming_language)"
                                      },
                                      {
                                        title: "Introduction to Ruby",
                                        url: "https://ruby-doc.org/docs/Tutorial"
                                      },
                                      {
                                        title: "Libraries",
                                        url: "https://www.ruby-lang.org/en/libraries",
                                        snippet: "Ruby has a wide ecosystem of third-party libraries."
                                      }
                                    ])
  end

  it "can include source and rank provenance in verbose mode" do
    duck = instance_double(
      FetchUtil::Result,
      markdown: "- [Ruby](https://www.ruby-lang.org/) - Official home page\n"
    )
    google = instance_double(
      FetchUtil::Result,
      markdown: "- [Ruby](https://www.ruby-lang.org/) - Official Ruby language site\n"
    )

    expect(request_log).to receive(:append).with("search://duckduckgo,google?q=ruby")
    expect(fetcher).to receive(:fetch).with([
                                              "https://duckduckgo.com/?q=ruby&ia=web&kl=us-en",
                                              "https://www.google.com/search?hl=en&q=ruby"
                                            ]).and_return([duck, google])

    payload = described_class.new(
      fetcher: fetcher,
      request_log: request_log,
      sources: %w[duckduckgo google],
      verbose: true
    ).search("ruby")

    expect(payload[:results]).to eq([
                                      {
                                        title: "Ruby",
                                        url: "https://www.ruby-lang.org/",
                                        snippet: "Official Ruby language site",
                                        sources: %w[duckduckgo google],
                                        ranks: { "duckduckgo" => 1, "google" => 1 }
                                      }
                                    ])
  end

  it "drops metadata-only snippets from community sites" do
    result = instance_double(
      FetchUtil::Result,
      markdown: <<~MARKDOWN
        - [What's the difference between a proc and a lambda in Ruby?](https://stackoverflow.com/questions/1740046/whats-the-difference-between-a-proc-and-a-lambda-in-ruby) - Stack Overflow7 answers - 16 years ago
        - [The difference between procs and lambdas in Ruby](https://www.reddit.com/r/ruby/comments/wekrdu/the_difference_between_procs_and_lambdas_in_ruby) - Reddit - r/ruby80+ comments - 3 years ago
      MARKDOWN
    )

    expect(request_log).to receive(:append).with("search://duckduckgo?q=ruby+proc+lambda")
    expect(fetcher).to receive(:fetch).with([
                                              "https://duckduckgo.com/?q=ruby+proc+lambda&ia=web&kl=us-en"
                                            ]).and_return([result])

    payload = described_class.new(
      fetcher: fetcher,
      request_log: request_log,
      sources: ["duckduckgo"]
    ).search("ruby proc lambda")

    expect(payload[:results]).to eq([
                                      {
                                        title: "What's the difference between a proc and a lambda in Ruby?",
                                        url: "https://stackoverflow.com/questions/1740046/whats-the-difference-between-a-proc-and-a-lambda-in-ruby"
                                      },
                                      {
                                        title: "The difference between procs and lambdas in Ruby",
                                        url: "https://www.reddit.com/r/ruby/comments/wekrdu/the_difference_between_procs_and_lambdas_in_ruby"
                                      }
                                    ])
  end

  it "filters low-value social, image, and retail search targets" do
    result = instance_double(
      FetchUtil::Result,
      markdown: <<~MARKDOWN
        - [Ruby on Rails Developers](https://www.facebook.com/groups/rubyonrailsdevelopers/) - 12K members
        - [Ruby on Rails](https://www.facebook.com/rubyonrails) - 2.9K likes
        - [Ruby programming ideas](https://www.pinterest.com/pin/123456789/) - Ruby programming ideas - Pinterest
        - [Ruby tutorial](https://shop.tiktok.com/view/product/1729) - All Categories
        - [Ruby books](https://www.walmart.com/search?q=ruby+books) - Shop great deals
        - [Ruby on Rails](https://rubyonrails.org/) - Compress the complexity of modern web apps.
      MARKDOWN
    )

    expect(request_log).to receive(:append).with("search://duckduckgo?q=ruby+on+rails")
    expect(fetcher).to receive(:fetch).with([
                                              "https://duckduckgo.com/?q=ruby+on+rails&ia=web&kl=us-en"
                                            ]).and_return([result])

    payload = described_class.new(
      fetcher: fetcher,
      request_log: request_log,
      sources: ["duckduckgo"]
    ).search("ruby on rails")

    expect(payload[:results]).to eq([
                                      {
                                        title: "Ruby on Rails",
                                        url: "https://rubyonrails.org/",
                                        snippet: "Compress the complexity of modern web apps."
                                      }
                                    ])
  end

  it "preserves meaningful docs fragments as distinct results" do
    result = instance_double(
      FetchUtil::Result,
      markdown: <<~MARKDOWN
        - [type Client](https://pkg.go.dev/net/http#Client) - A Client is an HTTP client.
        - [type Transport](https://pkg.go.dev/net/http#Transport) - Transport is an implementation of RoundTripper.
      MARKDOWN
    )

    expect(request_log).to receive(:append).with("search://duckduckgo?q=net%2Fhttp+client")
    expect(fetcher).to receive(:fetch).with([
                                              "https://duckduckgo.com/?q=net%2Fhttp+client&ia=web&kl=us-en"
                                            ]).and_return([result])

    payload = described_class.new(
      fetcher: fetcher,
      request_log: request_log,
      sources: ["duckduckgo"]
    ).search("net/http client")

    expect(payload[:results]).to eq([
                                      {
                                        title: "type Client",
                                        url: "https://pkg.go.dev/net/http#Client",
                                        snippet: "A Client is an HTTP client."
                                      },
                                      {
                                        title: "type Transport",
                                        url: "https://pkg.go.dev/net/http#Transport",
                                        snippet: "Transport is an implementation of RoundTripper."
                                      }
                                    ])
  end

  it "drops noise fragments while normalizing docs urls" do
    result = instance_double(
      FetchUtil::Result,
      markdown: <<~MARKDOWN
        - [HTTP package](https://pkg.go.dev/net/http#top) - Short package overview.
        - [HTTP package](https://pkg.go.dev/net/http) - The net/http package provides HTTP client and server implementations.
      MARKDOWN
    )

    expect(request_log).to receive(:append).with("search://duckduckgo?q=net%2Fhttp")
    expect(fetcher).to receive(:fetch).with([
                                              "https://duckduckgo.com/?q=net%2Fhttp&ia=web&kl=us-en"
                                            ]).and_return([result])

    payload = described_class.new(
      fetcher: fetcher,
      request_log: request_log,
      sources: ["duckduckgo"]
    ).search("net/http")

    expect(payload[:results]).to eq([
                                      {
                                        title: "HTTP package",
                                        url: "https://pkg.go.dev/net/http",
                                        snippet: "The net/http package provides HTTP client and server implementations."
                                      }
                                    ])
  end

  it "preserves fragments for developer-hosted docs urls through the shared docs-like helper" do
    result = instance_double(
      FetchUtil::Result,
      markdown: <<~MARKDOWN
        - [terraform_data arguments reference](https://developer.hashicorp.com/terraform/language/resources/terraform-data#arguments-reference) - Optional arguments for terraform_data.
        - [terraform_data import](https://developer.hashicorp.com/terraform/language/resources/terraform-data#import) - Import existing terraform_data resources.
      MARKDOWN
    )

    expect(request_log).to receive(:append).with("search://duckduckgo?q=terraform_data")
    expect(fetcher).to receive(:fetch).with([
                                              "https://duckduckgo.com/?q=terraform_data&ia=web&kl=us-en"
                                            ]).and_return([result])

    payload = described_class.new(
      fetcher: fetcher,
      request_log: request_log,
      sources: ["duckduckgo"]
    ).search("terraform_data")

    expect(payload[:results]).to eq([
                                      {
                                        title: "terraform_data arguments reference",
                                        url: "https://developer.hashicorp.com/terraform/language/resources/terraform-data#arguments-reference",
                                        snippet: "Optional arguments for terraform_data."
                                      },
                                      {
                                        title: "terraform_data import",
                                        url: "https://developer.hashicorp.com/terraform/language/resources/terraform-data#import",
                                        snippet: "Import existing terraform_data resources."
                                      }
                                    ])
  end

  it "filters non-html document results such as pdfs" do
    result = instance_double(
      FetchUtil::Result,
      markdown: <<~MARKDOWN
        - [Clinical Study PDF](https://www.example.org/articles/1234/pdf) - Full article PDF
        - [HTML article](https://www.example.org/articles/1234) - Read the article online
      MARKDOWN
    )

    expect(request_log).to receive(:append).with("search://duckduckgo?q=clinical+study")
    expect(fetcher).to receive(:fetch).with([
                                              "https://duckduckgo.com/?q=clinical+study&ia=web&kl=us-en"
                                            ]).and_return([result])

    payload = described_class.new(
      fetcher: fetcher,
      request_log: request_log,
      sources: ["duckduckgo"]
    ).search("clinical study")

    expect(payload[:results]).to eq([
                                      {
                                        title: "HTML article",
                                        url: "https://www.example.org/articles/1234",
                                        snippet: "Read the article online"
                                      }
                                    ])
  end

  it "keeps legitimate lowercase brand prefixes in titles" do
    result = instance_double(
      FetchUtil::Result,
      markdown: <<~MARKDOWN
        - [rails Routing from the Outside In](https://guides.rubyonrails.org/routing.html) - Learn how Rails routes incoming requests.
      MARKDOWN
    )

    expect(request_log).to receive(:append).with("search://duckduckgo?q=rails+routing")
    expect(fetcher).to receive(:fetch).with([
                                              "https://duckduckgo.com/?q=rails+routing&ia=web&kl=us-en"
                                            ]).and_return([result])

    payload = described_class.new(
      fetcher: fetcher,
      request_log: request_log,
      sources: ["duckduckgo"]
    ).search("rails routing")

    expect(payload[:results]).to eq([
                                      {
                                        title: "rails Routing from the Outside In",
                                        url: "https://guides.rubyonrails.org/routing.html",
                                        snippet: "Learn how Rails routes incoming requests."
                                      }
                                    ])
  end

  it "normalizes non-breaking spaces in titles and snippets" do
    nbsp = "\u00A0"
    result = instance_double(
      FetchUtil::Result,
      markdown: "- [Ruby#{nbsp}Guides](https://guides.rubyonrails.org/) - Learn#{nbsp}Rails the productive way.\n"
    )

    expect(request_log).to receive(:append).with("search://duckduckgo?q=ruby+guides")
    expect(fetcher).to receive(:fetch).with([
                                              "https://duckduckgo.com/?q=ruby+guides&ia=web&kl=us-en"
                                            ]).and_return([result])

    payload = described_class.new(
      fetcher: fetcher,
      request_log: request_log,
      sources: ["duckduckgo"]
    ).search("ruby guides")

    expect(payload[:results]).to eq([
                                      {
                                        title: "Ruby Guides",
                                        url: "https://guides.rubyonrails.org/",
                                        snippet: "Learn Rails the productive way."
                                      }
                                    ])
  end

  it "parses markdown result urls with nested parentheses without clipping the link" do
    result = instance_double(
      FetchUtil::Result,
      markdown: <<~MARKDOWN
        - [Function docs](https://example.org/docs/Function_(alpha_(beta))/overview) - Full reference page.
      MARKDOWN
    )

    expect(request_log).to receive(:append).with("search://duckduckgo?q=function+docs")
    expect(fetcher).to receive(:fetch).with([
                                              "https://duckduckgo.com/?q=function+docs&ia=web&kl=us-en"
                                            ]).and_return([result])

    payload = described_class.new(
      fetcher: fetcher,
      request_log: request_log,
      sources: ["duckduckgo"]
    ).search("function docs")

    expect(payload[:results]).to eq([
                                      {
                                        title: "Function docs",
                                        url: "https://example.org/docs/Function_(alpha_(beta))/overview",
                                        snippet: "Full reference page."
                                      }
                                    ])
  end

  it "filters search engine self-links and result-management actions" do
    result = instance_double(
      FetchUtil::Result,
      markdown: <<~MARKDOWN
        - [DuckDuckGo](https://duckduckgo.com/) - Redo search without this site
        - [Redo search without this site](https://duckduckgo.com/html/?q=site%3Arubyapi.org+string) - DuckDuckGo
        - [Go to Google Home](https://www.google.com/) - Google Search
        - [Block this site from all results](https://www.google.com/search?hl=en&q=site%3Aapi.baselinker.com+shops_api) - Google Search
        - [String | Ruby API](https://rubyapi.org/3.4/o/string) - A String object has an arbitrary sequence of bytes.
        - [API documentation - Baselinker](https://api.baselinker.com/) - API documentation for Baselinker methods.
      MARKDOWN
    )

    expect(request_log).to receive(:append).with("search://duckduckgo?q=site%3Arubyapi.org+string")
    expect(fetcher).to receive(:fetch).with([
                                              "https://duckduckgo.com/?q=site%3Arubyapi.org+string&ia=web&kl=us-en"
                                            ]).and_return([result])

    payload = described_class.new(
      fetcher: fetcher,
      request_log: request_log,
      sources: ["duckduckgo"]
    ).search("site:rubyapi.org string")

    expect(payload[:results]).to eq([
                                      {
                                        title: "String | Ruby API",
                                        url: "https://rubyapi.org/3.4/o/string",
                                        snippet: "A String object has an arbitrary sequence of bytes."
                                      },
                                      {
                                        title: "API documentation - Baselinker",
                                        url: "https://api.baselinker.com/",
                                        snippet: "API documentation for Baselinker methods."
                                      }
                                    ])
  end

  it "filters search-engine shell and wrapper URLs before fetch" do
    result = instance_double(
      FetchUtil::Result,
      markdown: <<~MARKDOWN
        - [Before you continue to Google](https://www.google.com/webhp?hl=en) - Google offered in: polski
        - [Google apps](https://www.google.pl/intl/en/about/products?tab=wh) - Explore Google products
        - [Translated product page](https://translate.google.com/translate?u=https://shop.example.test/item/1&hl=en&sl=pl&tl=en&client=search) - Translation wrapper
        - [Ad redirect](https://duckduckgo.com/y.js?ad_domain=example.com) - Sponsored
        - [Useful article](https://www.example.org/articles/1) - Actual content
      MARKDOWN
    )

    expect(request_log).to receive(:append).with("search://duckduckgo?q=rare+word")
    expect(fetcher).to receive(:fetch).with([
                                              "https://duckduckgo.com/?q=rare+word&ia=web&kl=us-en"
                                            ]).and_return([result])

    payload = described_class.new(
      fetcher: fetcher,
      request_log: request_log,
      sources: ["duckduckgo"]
    ).search("rare word")

    expect(payload[:results]).to eq([
                                      {
                                        title: "Useful article",
                                        url: "https://www.example.org/articles/1",
                                        snippet: "Actual content"
                                      }
                                    ])
  end
end
