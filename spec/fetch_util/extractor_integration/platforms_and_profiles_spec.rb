# frozen_string_literal: true

RSpec.describe 'FetchUtil extractor integration' do
  include_context 'extractor integration helpers'

  it "prefers project summary and readme content on generic gitlab instances" do
    html = <<~HTML
      <html>
        <head>
          <title>Group / Project · GitLab</title>
          <meta name="application-name" content="GitLab">
          <meta name="description" content="Collaborative project description.">
        </head>
        <body>
          <header class="project-home-panel">
            <p>Collaborative project description.</p>
            <p>Project ID: 12345</p>
          </header>
          <article class="file-holder readme-holder">
            <div class="md">
              <h2>Getting started</h2>
              <p>Clone the repository and run the setup script.</p>
              <ul>
                <li>Install dependencies</li>
                <li>Run tests</li>
              </ul>
            </div>
          </article>
        </body>
      </html>
    HTML

    with_page(html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["markdown"]).to include("# Group / Project")
      expect(payload["markdown"]).to include("Collaborative project description.")
      expect(payload["markdown"]).to include("## Getting started")
      expect(payload["markdown"]).to include("Install dependencies")
      expect(payload["markdown"]).not_to include("Project ID: 12345")
    end
  end

  it "prefers package registry descriptions over release history chrome" do
    html = <<~HTML
      <html>
        <head>
          <title>pandas · PyPI</title>
          <meta name="description" content="Powerful data structures for data analysis.">
        </head>
        <body>
          <main>
            <div class="sidebar-section">
              <h3>Navigation</h3>
              <a href="#history">Release history</a>
            </div>
            <section id="history" class="vertical-tabs__content">
              <h2 class="page-title split-layout">Release history</h2>
              <div class="release-timeline">
                <a class="card release__card" href="/project/pandas/3.0.4/">3.0.4 yanked Jun 28, 2026</a>
                <a class="card release__card" href="/project/pandas/3.0.0rc2/">3.0.0rc2 pre-release Jan 14, 2026</a>
              </div>
            </section>
            <section id="description" class="vertical-tabs__content">
              <h2 class="page-title">Project description</h2>
              <div class="project-description">
                <h1>pandas: A Powerful Python Data Analysis Toolkit</h1>
                <p>pandas is a Python package providing fast, flexible, and expressive data structures.</p>
                <p>It aims to be the fundamental high-level building block for practical data analysis.</p>
              </div>
            </section>
          </main>
        </body>
      </html>
    HTML

    extract_from_url("https://pypi.org/project/pandas/", html) do |payload|
      expect(payload["contentType"]).to eq("article")
      expect(payload["markdown"]).to include("pandas: A Powerful Python Data Analysis Toolkit")
      expect(payload["markdown"]).to include("fast, flexible, and expressive data structures")
      expect(payload["markdown"]).not_to include("3.0.4 yanked")
      expect(payload["warnings"]).not_to include("multi_topic_page")
    end
  end

  it "does not flag single package pages as multi-topic compilations" do
    html = <<~HTML
      <html>
        <head>
          <title>rails | RubyGems.org | your community gem host</title>
          <meta name="description" content="Ruby on Rails is a full-stack web framework.">
        </head>
        <body>
          <main>
            <div id="markup" class="gem__desc">
              <p>Ruby on Rails is a full-stack web framework optimized for programmer happiness and sustainable productivity.</p>
              <h2>Required Ruby Version</h2>
              <time datetime="2026-01-01">Jan 1, 2026</time>
              <h2>Required Rubygems Version</h2>
              <time datetime="2026-02-01">Feb 1, 2026</time>
              <h2>Authors</h2>
              <time datetime="2026-03-01">Mar 1, 2026</time>
              <h2>Links</h2>
              <time datetime="2026-04-01">Apr 1, 2026</time>
              <h2>Versions</h2>
              <time datetime="2026-05-01">May 1, 2026</time>
              <h2>Dependencies</h2>
              <time datetime="2026-06-01">Jun 1, 2026</time>
            </div>
          </main>
        </body>
      </html>
    HTML

    extract_from_url("https://rubygems.org/gems/rails", html) do |payload|
      expect(payload["contentType"]).to eq("article")
      expect(payload["markdown"]).to include("Ruby on Rails is a full-stack web framework")
      expect(payload["warnings"]).not_to include("multi_topic_page")
      expect(payload["suspect"]).to be(false)
    end
  end

  it "extracts Atlassian Statuspage components and incident updates" do
    html = <<~HTML
      <html>
        <head>
          <title>Example Status</title>
          <meta property="og:site_name" content="Example Status">
          <meta name="description" content="Real-time status for Example services.">
        </head>
        <body class="status index status-none">
          <div class="layout-content status status-index">
            <div class="page-status status-none"><span class="status font-large">All Systems Operational</span></div>
            <div class="text-section">Real-time status for Example services.</div>
            <div class="components-section font-regular">
              <div class="components-container one-column">
                <div class="component-container border-color">
                  <div data-component-id="api" class="component-inner-container status-green" data-component-status="operational">
                    <span class="name">API</span>
                    <button class="tooltip-base" data-original-title="Primary API requests">?</button>
                    <span class="component-status">Operational</span>
                    <span id="uptime-percent-api">99.99</span> % uptime
                  </div>
                </div>
                <div class="component-container border-color">
                  <div data-component-id="webhooks" class="component-inner-container status-yellow" data-component-status="degraded_performance">
                    <span class="name">Webhooks</span>
                    <button class="tooltip-base" data-original-title="Event delivery callbacks">?</button>
                    <span class="component-status">Degraded Performance</span>
                  </div>
                </div>
                <div class="component-container border-color" style="display: none;">
                  <div data-component-status="operational"><span class="name">Visit www.example-status.com</span></div>
                </div>
              </div>
            </div>
            <div class="incidents-list">
              <div class="status-day font-regular">
                <div class="date border-color font-large">Jul <var data-var="date">4</var>, <var data-var="year">2026</var></div>
                <div class="incident-container">
                  <div class="incident-title impact-minor font-large"><a class="whitespace-pre-wrap" href="/incidents/abc">Webhook delivery delays</a></div>
                  <div class="updates-container">
                    <div class="update font-regular resolved"><strong>Resolved</strong> - <span class="whitespace-pre-wrap">The backlog has cleared.</span><br><small>Jul <var data-var="date">4</var>, <var data-var="time">13:24</var> UTC</small></div>
                    <div class="update font-regular investigating"><strong>Investigating</strong> - <span class="whitespace-pre-wrap">We are investigating delayed deliveries.</span><br><small>Jul <var data-var="date">4</var>, <var data-var="time">12:01</var> UTC</small></div>
                  </div>
                </div>
              </div>
            </div>
            <a class="powered-by" href="https://www.atlassian.com/software/statuspage">Powered by Atlassian Statuspage</a>
          </div>
        </body>
      </html>
    HTML

    extract_from_url("https://status.example.com/", html) do |payload|
      expect(payload["contentType"]).to eq("list")
      expect(payload["markdown"]).to include("- Overall status: All Systems Operational")
      expect(payload["markdown"]).to include("- API - operational")
      expect(payload["markdown"]).to include("Primary API requests")
      expect(payload["markdown"]).to include("- Webhooks - degraded performance")
      expect(payload["markdown"]).to include("Event delivery callbacks")
      expect(payload["markdown"]).to include("## Recent Incidents")
      expect(payload["markdown"]).to include("Webhook delivery delays")
      expect(payload["markdown"]).to include("Resolved - The backlog has cleared. - Jul 4, 13:24 UTC")
      expect(payload["warnings"]).not_to include("homepage_index_page")
    end
  end

  it "preserves Drupal institutional body paragraphs" do
    html = <<~HTML
      <html>
        <head>
          <title>International Covenant | Example UN</title>
          <meta name="Generator" content="Drupal 10">
        </head>
        <body class="path-instruments node-123">
          <header><a href="/donate">Donate</a><a href="/topics">Topics</a></header>
          <main>
            <article class="node node--type-instrument">
              <h1>International Covenant on Example Rights</h1>
              <div class="field field--name-body field--type-text-long">
                <h2>Preamble</h2>
                <p>The States Parties to the present Covenant,</p>
                <p>Considering that recognition of inherent dignity is the foundation of freedom, justice and peace.</p>
                <h3>Article 1</h3>
                <p>1. All peoples have the right of self-determination.</p>
                <p>2. All peoples may freely pursue their economic, social and cultural development.</p>
              </div>
            </article>
          </main>
        </body>
      </html>
    HTML

    extract_from_url("https://institution.example/en/instruments/example-covenant", html) do |payload|
      expect(payload["contentType"]).to eq("article")
      expect(payload["markdown"]).to include("# International Covenant on Example Rights")
      expect(payload["markdown"]).to include("## Preamble\n\nThe States Parties to the present Covenant,")
      expect(payload["markdown"]).to include("### Article 1")
      expect(payload["markdown"]).to include("All peoples have the right of self-determination.")
      expect(payload["markdown"]).not_to include("Donate")
    end
  end

  it "extracts Drupal institutional view, tab, and card components" do
    html = <<~HTML
      <html>
        <head>
          <title>Treaty Bodies | Example UN</title>
          <meta name="Generator" content="Drupal 10">
        </head>
        <body class="path-treaty-bodies node-731">
          <header><a href="/en/search">Search</a><a href="/en/donate">Donate</a></header>
          <main>
            <article about="/en/treaty-bodies" class="overview-page-template">
              <div class="field field--name-body field--type-text-long">
                <p>Our Work boilerplate that is too short to represent the page.</p>
              </div>
              <div class="overview-inner-container">
                <aside class="side-navigation"><a href="/en/treaty-bodies">Overview</a><a href="/en/treaty-bodies/sessions">Sessions</a></aside>
                <section class="field field--name-field-view-block">
                  <h1>Treaty Bodies</h1>
                  <div class="paragraph paragraph--type--view-component">
                    <div class="field--name-field-tab-content-block">
                      <ul role="list" class="blocktab--tablist unstyled">
                        <li><a href="#treaty-bodies-list">Treaty bodies</a></li>
                        <li><a href="#countries-list">Countries</a></li>
                      </ul>
                      <div id="treaty-bodies-list" class="card-listing-component-container">
                        <h2 class="card-heading-list__heading">Treaty bodies</h2>
                        <article class="card-headline-vertical-list-wrapper">
                          <h3 class="card-headline-list"><a href="/en/treaty-bodies/cerd">Committee on the Elimination of Racial Discrimination (CERD)</a></h3>
                          <div class="field field--name-field-body"><p>Monitors implementation of the International Convention on the Elimination of All Forms of Racial Discrimination.</p></div>
                        </article>
                        <article class="card-headline-vertical-list-wrapper">
                          <h3 class="card-headline-list"><a href="/en/treaty-bodies/cescr">Committee on Economic, Social and Cultural Rights (CESCR)</a></h3>
                          <div class="field field--name-field-body"><p>Monitors implementation of the International Covenant on Economic, Social and Cultural Rights.</p></div>
                        </article>
                      </div>
                      <div id="countries-list" class="card-listing-component-container">
                        <h2 class="card-heading-list__heading">Africa Region</h2>
                        <article about="/en/countries/angola"><h3 class="card-headline-list"><a href="/en/countries/angola">Angola</a></h3></article>
                        <article about="/en/countries/benin"><h3 class="card-headline-list"><a href="/en/countries/benin">Benin</a></h3></article>
                      </div>
                    </div>
                  </div>
                </section>
              </div>
            </article>
          </main>
        </body>
      </html>
    HTML

    extract_from_url("https://institution.example/en/treaty-bodies", html) do |payload|
      expect(payload["contentType"]).to eq("article")
      expect(payload["markdown"]).to include("# Treaty Bodies")
      expect(payload["markdown"]).to include("Committee on the Elimination of Racial Discrimination")
      expect(payload["markdown"]).to include("Monitors implementation of the International Convention")
      expect(payload["markdown"]).to include("Africa Region")
      expect(payload["markdown"]).to include("[Angola](https://institution.example/en/countries/angola)")
      expect(payload["markdown"]).not_to include("Sessions")
      expect(payload["markdown"]).not_to include("Donate")
    end
  end

  it "extracts institutional topic cards as clean list items" do
    topic_cards = Array.new(9) do |index|
      topic = ["Abortion", "Abuse of older people", "Addictive behaviour", "Adolescent health", "Ageing", "Air pollution", "Alcohol", "Anaemia", "Cancer"][index]
      category = index.even? ? "Conditions" : "Health interventions"
      slug = topic.downcase.gsub(/[^a-z0-9]+/, "-").sub(/-\z/, "")

      <<~CARD
        <div><a href="https://institution.example/health-topics/#{slug}" aria-label="#{topic}" role="link">
          <div><p><span>#{category}</span></p><p>#{topic}</p></div>
        </a></div>
      CARD
    end.join

    html = <<~HTML
      <html>
        <head><title>Health topics</title></head>
        <body>
          <main>
            <h1>Health topics</h1>
            <div id="listView-healthtopics" data-sf-element="Row">
              #{topic_cards}
            </div>
          </main>
        </body>
      </html>
    HTML

    extract_from_url("https://institution.example/health-topics", html) do |payload|
      expect(payload["contentType"]).to eq("list")
      expect(payload["markdown"]).to include("- [Abortion](https://institution.example/health-topics/abortion)")
      expect(payload["markdown"]).to include("- [Cancer](https://institution.example/health-topics/cancer)")
      expect(payload["markdown"]).not_to include("[\n\nHealth interventions")
      expect(payload["markdown"]).not_to include("\n\n](")
    end
  end

  it "extracts AEM custom-element service tiles from attributes" do
    html = <<~HTML
      <html>
        <head><title>Find government payments and services</title></head>
        <body>
          <main id="main" class="cmp-container root responsivegrid" role="main">
            <div class="aem-Grid aem-Grid--12 aem-Grid--default--12">
              <div class="page-title title aem-GridColumn aem-GridColumn--default--8">
                <div data-cmp-data-layer='{"page-title":{"@type":"example/components/structure/page-title","dc:title":"Find government payments and services"}}'>
                  <h1>Find government payments and services</h1>
                </div>
              </div>
              <div class="list aem-GridColumn aem-GridColumn--default--8">
                <gui-tile-list class="cmp-list-gui hydrated" role="list" variant="3up">
                  <gui-tile class="example-tile hydrated" data-cmp-data-layer='{"tile-raising-kids":{"@type":"example/components/content/list/item","dc:title":"Raising kids","xdm:linkURL":"/en/services/raising-kids"}}'>
                    <gui-tile-heading heading-text="Raising kids" heading-level="2" class="hydrated"></gui-tile-heading>
                    <gui-tile-content content-text="Help when having a baby, as kids go through school and when parents separate." class="hydrated"></gui-tile-content>
                  </gui-tile>
                  <gui-tile class="example-tile hydrated" data-cmp-data-layer='{"tile-living-arrangements":{"@type":"example/components/content/list/item","dc:title":"Living arrangements","xdm:linkURL":"/en/services/living-arrangements"}}'>
                    <gui-tile-heading heading-text="Living arrangements" heading-level="2" class="hydrated"></gui-tile-heading>
                    <gui-tile-content content-text="Information to help with housing, natural disasters, family and domestic violence, online crime and travelling." class="hydrated"></gui-tile-content>
                  </gui-tile>
                  <gui-tile class="example-tile hydrated" data-cmp-data-layer='{"tile-ageing":{"@type":"example/components/content/list/item","dc:title":"Ageing","xdm:linkURL":"/en/services/ageing"}}'>
                    <gui-tile-heading heading-text="Ageing" heading-level="2" class="hydrated"></gui-tile-heading>
                    <gui-tile-content content-text="Help when retiring, getting older and accessing aged care services." class="hydrated"></gui-tile-content>
                  </gui-tile>
                </gui-tile-list>
              </div>
            </div>
          </main>
        </body>
      </html>
    HTML

    extract_from_url("https://institution.example/en/services", html) do |payload|
      expect(payload["contentType"]).to eq("list")
      expect(payload["markdown"]).to include("- [Raising kids](https://institution.example/en/services/raising-kids) - Help when having a baby")
      expect(payload["markdown"]).to include("- [Living arrangements](https://institution.example/en/services/living-arrangements) - Information to help with housing")
      expect(payload["markdown"]).to include("- [Ageing](https://institution.example/en/services/ageing) - Help when retiring")
      expect(payload["markdown"]).not_to include("gui-tile")
    end
  end

  it "extracts legal encyclopedia article bodies without duplicated related snippets" do
    html = <<~HTML
      <html>
        <head>
          <title>res judicata | Legal Encyclopedia</title>
          <meta property="og:site_name" content="Example Legal Information Institute">
          <meta name="description" content="A legal reference definition for res judicata.">
        </head>
        <body>
          <header><a href="/search">Search</a><a href="/topics">Topics</a></header>
          <main id="main">
            <div id="extracted-content">
              <div id="main-content">
                <h1 class="title" id="page-title">res judicata</h1>
                <p><em>Res judicata</em> is a Latin phrase that translates to a matter judged.</p>
                <p>Res judicata is also called claim preclusion, and the terms are used interchangeably.</p>
                <h4>Bar and Merger</h4>
                <p>Claim preclusion has two main applications:</p>
                <ol>
                  <li>Bar: A losing plaintiff cannot sue the same defendant again on the same cause of action.</li>
                  <li>Merger: A winning plaintiff cannot sue the same defendant again to obtain additional recovery.</li>
                </ol>
                <h4>Public Policy</h4>
                <p>Courts uphold claim preclusion to promote judicial economy and consistent judgments.</p>
                <section class="related-entries">
                  <h2>Related Wex entries</h2>
                  <a href="/wex/collateral_estoppel">collateral estoppel</a>
                  <p>res judicata Res judicata is a Latin phrase that translates to a matter judged. Res judicata is also called claim preclusion.</p>
                </section>
              </div>
            </div>
          </main>
        </body>
      </html>
    HTML

    extract_from_url("https://legal.example/wex/res_judicata", html) do |payload|
      expect(payload["contentType"]).to eq("article")
      expect(payload["markdown"]).to include("# res judicata")
      expect(payload["markdown"]).to include("#### Bar and Merger")
      expect(payload["markdown"]).to include("1.  Bar: A losing plaintiff cannot sue the same defendant again")
      expect(payload["markdown"]).to include("#### Public Policy")
      expect(payload["markdown"]).not_to include("Related Wex entries")
      expect(payload["markdown"].delete("*_").scan("Res judicata is a Latin phrase").length).to eq(1)
      expect(payload["suspect"]).to be(false)
    end
  end

  it "extracts EUR-Lex document text without search and language chrome" do
    html = <<~HTML
      <html>
        <head><title>EUR-Lex - 120120 - EN - EUR-Lex</title></head>
        <body>
          <header id="op-header">
            <a href="/homepage.html">EUR-Lex home</a>
            <a href="#language-list-overlay">Change language</a>
            <p>Use quotation marks to search for an exact phrase. Need more search options?</p>
          </header>
          <div id="MainContent">
            <div class="PageShare"><a class="PSHelp" href="/content/help.html">Help</a></div>
            <div class="EurlexContent">
              <div id="PP1Contents">
                <p id="englishTitle" class="hidden">Consolidated version of the Treaty on the Functioning of the European Union - PART ONE#PRINCIPLES - Article 1</p>
                <p id="title" class="title-bold">Consolidated version of the Treaty on the Functioning of the European Union - PART ONE<br>PRINCIPLES - Article 1</p>
                <p>OJ C 326, 26.10.2012, p. 50-50</p>
              </div>
              <div id="PP4Contents">
                <div id="text">
                  <div id="textTabContent">
                    <div id="document1" class="tabContent">
                      <p class="doc-ti">CONSOLIDATED VERSION OF THE TREATY ON THE FUNCTIONING OF THE EUROPEAN UNION</p>
                      <p class="ti-section-1">PART ONE</p>
                      <p class="ti-section-2">PRINCIPLES</p>
                      <p class="ti-art">Article 1</p>
                      <p class="normal">1. This Treaty organises the functioning of the Union and determines the areas of, delimitation of, and arrangements for exercising its competences.</p>
                      <p class="normal">2. This Treaty and the Treaty on European Union constitute the Treaties on which the Union is founded.</p>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </body>
      </html>
    HTML

    extract_from_url("https://eur-lex.europa.eu/legal-content/EN/TXT/?uri=CELEX:12012E001", html) do |payload|
      expect(payload["contentType"]).to eq("article")
      expect(payload["markdown"]).to include("Consolidated version of the Treaty on the Functioning of the European Union")
      expect(payload["markdown"]).to include("This Treaty organises the functioning of the Union")
      expect(payload["markdown"]).not_to include("Use quotation marks")
      expect(payload["markdown"]).not_to include("Change language")
      expect(payload["markdown"]).not_to include("Help")
      expect(payload["warnings"]).not_to include("truncated_content")
    end
  end

  it "extracts government program microsite content instead of mega-menu links" do
    html = <<~HTML
      <html>
        <head><title>Landslide Hazards Program</title></head>
        <body>
          <div class="usa-banner">Official websites use .gov</div>
          <nav class="usa-nav">
            <div id="extended-mega-nav-section-products-desktop" class="usa-nav__submenu usa-megamenu">
              <a href="/products/data-and-tools/data-management">Data Management</a>
              <a href="/products/data/data-releases">Data Releases</a>
              <a href="/products/maps/map-releases">Map Releases</a>
              <a href="/products/multimedia-gallery/videos">Videos</a>
            </div>
          </nav>
          <main class="main-content usa-layout-docs usa-section" role="main" id="main-content">
            <div class="group group--full group--microsite group--type--microsite microsite--type--programs group--view-mode--full">
              <ul class="menu group-menu"><li>Home</li><li>Science</li></ul>
              <div class="node-intro">
                <h1 class="microsite-title">Landslide Hazards Program</h1>
                <div class="field field--name--field-intro field--type--text-long field--label--hidden">
                  <p>The primary objective of the National Landslide Hazards Program is to reduce long-term losses from landslide hazards by improving our understanding of ground failure and supporting public safety decisions.</p>
                </div>
              </div>
              <div class="tablet:grid-col-4 field-info-links">
                <h3>Landslide Basics</h3>
                <p>What is a landslide? Where do they happen and what causes them? Learn all about the basics of landslides here.</p>
                <a href="/programs/landslide-hazards/science/landslide-basics">Learn About Landslides</a>
              </div>
              <div class="tablet:grid-col-4 field-info-links">
                <h3>U.S. and Puerto Rico Landslide Hazard Map</h3>
                <p>New high-resolution map of landslide susceptibility for the entire U.S. and Puerto Rico.</p>
                <a href="/programs/landslide-hazards/science/landslide-inventory-and-susceptibility-map">Learn More</a>
              </div>
            </div>
          </main>
        </body>
      </html>
    HTML

    extract_from_url("https://www.usgs.gov/programs/landslide-hazards", html) do |payload|
      expect(payload["contentType"]).to eq("article")
      expect(payload["markdown"]).to include("# Landslide Hazards Program")
      expect(payload["markdown"]).to include("The primary objective of the National Landslide Hazards Program")
      expect(payload["markdown"]).to include("Landslide Basics")
      expect(payload["markdown"]).not_to include("Data Management")
      expect(payload["markdown"]).not_to include("Map Releases")
      expect(payload["markdown"]).not_to include("Home\n\nScience")
    end
  end

  it "extracts standards record details instead of product navigation links" do
    nav_links = <<~HTML
      <nav>
        <a href="/products-programs/icap/">IEEE Conformity Assessment Program (ICAP)</a>
        <a href="/products-programs/regauth/">Registration Authority</a>
        <a href="/products-programs/ieee-get-program/">IEEE GET Program</a>
      </nav>
    HTML
    html = <<~HTML
      <html>
        <head>
          <title>IEEE SA - IEEE 1541-2021</title>
          <meta name="type" content="Standard">
          <meta name="designation" content="IEEE 1541-2021">
        </head>
        <body>
          #{nav_links}
          <main>
            <section id="page-title" class="standard">
              <div class="stnd-status">Active Standard</div>
              <h1 id="stnd-designation">IEEE 1541-2021</h1>
              <h2 id="stnd-title">IEEE Standard for Prefixes for Binary Multiples</h2>
              <div id="purchase-options"><a id="stnd-buy-url" href="https://store.example/6867">Purchase</a></div>
            </section>
            <section id="content" class="standard">
              <div id="main-content">
                <div id="stnd-description">
                  <p>Names and letter symbols for prefixes that denote multiplication of a unit by the binary multiplier 2 10n, where n = 1, 2, 3, 4, 5, 6, 7, or 8 are defined.</p>
                </div>
                <div id="standard-details">
                  <dl>
                    <dt>Standard Committee</dt><dd id="stnd-committee">BOG/QUSCom - Quantities, Units, and Symbols Standards Committee</dd>
                    <dt>Status</dt><dd id="stnd-status">Active Standard</dd>
                    <dt>Board Approval</dt><dd id="stnd-approval-date">2021-12-08</dd>
                    <dt>Published</dt><dd id="stnd-published-date">2022-02-18</dd>
                  </dl>
                </div>
                <div id="working-group-details">
                  <dl><dt>Working Group Chair</dt><dd>Randall Curey</dd></dl>
                  <div id="working-group-projects-standards"><a href="/ieee/260.1/6864">Other working group standard</a></div>
                </div>
              </div>
            </section>
          </main>
        </body>
      </html>
    HTML

    extract_from_url("https://standards.example.org/standard/1541-2021/", html) do |payload|
      expect(payload["contentType"]).to eq("article")
      expect(payload["markdown"]).to include("IEEE 1541-2021")
      expect(payload["markdown"]).to include("IEEE Standard for Prefixes for Binary Multiples")
      expect(payload["markdown"]).to include("Names and letter symbols for prefixes")
      expect(payload["markdown"]).to include("Active Standard")
      expect(payload["markdown"]).to include("2022-02-18")
      expect(payload["markdown"]).not_to include("IEEE Conformity Assessment Program")
      expect(payload["markdown"]).not_to include("Other working group standard")
    end
  end

  it "extracts Your Europe landing content instead of the feedback form" do
    html = <<~HTML
      <html>
        <head><title>Help and advice for EU nationals and family - Your Europe</title></head>
        <body>
          <main id="main-content" class="container">
            <h1>Help and advice for EU nationals and their family</h1>
            <div id="main-article">
              <nav class="contents">
                <ul>
                  <li><h2><a href="/youreurope/citizens/travel/index_en.htm">Travel</a></h2>
                    <ul><li><a href="/youreurope/citizens/travel/entry-exit/index_en.htm">Documents you need for travel in Europe</a></li><li><a href="/youreurope/citizens/travel/passenger-rights/index_en.htm">Passenger rights</a></li></ul>
                  </li>
                  <li><h2><a href="/youreurope/citizens/work/index_en.htm">Work and retirement</a></h2>
                    <ul><li><a href="/youreurope/citizens/work/working-abroad/index_en.htm">Working abroad</a></li><li><a href="/youreurope/citizens/work/retire-abroad/index_en.htm">Retiring abroad</a></li></ul>
                  </li>
                  <li><h2><a href="/youreurope/citizens/consumers/index_en.htm">Consumers</a></h2>
                    <ul><li><a href="/youreurope/citizens/consumers/shopping/index_en.htm">Shopping</a></li><li><a href="/youreurope/citizens/consumers/internet-telecoms/index_en.htm">Internet and telecoms</a></li></ul>
                  </li>
                </ul>
              </nav>
            </div>
          </main>
          <form id="feedback-form" class="toggle-content">
            <p class="success">Thank you for your feedback. If you are willing to give us more details, please fill in this survey.</p>
            <label for="name">Name</label><input id="name">
            <label for="suggestions">Help us improve</label><textarea id="suggestions"></textarea>
          </form>
        </body>
      </html>
    HTML

    extract_from_url("https://europa.eu/youreurope/citizens/index_en.htm", html) do |payload|
      expect(payload["contentType"]).to eq("article")
      expect(payload["markdown"]).to include("# Help and advice for EU nationals and their family")
      expect(payload["markdown"]).to include("Travel")
      expect(payload["markdown"]).to include("Documents you need for travel in Europe")
      expect(payload["markdown"]).to include("Work and retirement")
      expect(payload["markdown"]).not_to include("Thank you for your feedback")
      expect(payload["markdown"]).not_to include("Help us improve")
    end
  end

  it "extracts pinterest search pages into compact pin bullets" do
    html = <<~HTML
      <html>
        <head>
          <title>Pinterest</title>
          <meta name="description" content="Discover recipes, home ideas, style inspiration and other ideas to try.">
        </head>
        <body>
          <main>
            <h1>Search</h1>
            <h2>Showing more search results for ruby programming</h2>
            <a href="/pin/1" aria-label="ruby programming logo with the words ruby programming written in red on a white background"></a>
            <a href="/pin/2"><img alt="the ruby programming poster shows how ruby programs are used for learning and developing computer skills"></a>
            <a href="/pin/3" aria-label="the six reasons why you should learn ruby today"></a>
            <a href="/pin/4" aria-label="a red poster with instructions on how to use ruby"></a>
          </main>
        </body>
      </html>
    HTML

    with_page(html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["contentType"]).to eq("list")
      expect(payload["markdown"]).to include("- [ruby programming logo with the words ruby programming written in red on a white background](/pin/1)")
      expect(payload["markdown"]).to include("- [the six reasons why you should learn ruby today](/pin/3)")
      expect(payload["warnings"]).not_to include("url_content_mismatch")
    end
  end

  it "summarizes TikTok tag pages while still flagging verification prompts" do
    html = <<~HTML
      <html>
        <head>
          <title>TikTok - Make Your Day</title>
          <meta name="description" content="Watch popular Ruby videos on TikTok.">
        </head>
        <body>
          <main>
            <h1>#ruby</h1>
            <h2>1.2M posts</h2>
            <p>Drag the slider to fit the puzzle</p>
          </main>
        </body>
      </html>
    HTML

    with_page(html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["markdown"]).to include("# #ruby")
      expect(payload["markdown"]).to include("- 1.2M posts")
      expect(payload["warnings"]).to include("human_verification_interstitial")
    end
  end

  it "summarizes eBay cookie prompts from metadata instead of cookie copy" do
    html = <<~HTML
      <html>
        <head>
          <title>Ruby Programming for sale | eBay</title>
          <meta name="description" content="Get the best deals for Ruby Programming at eBay.com. We have a great online selection at the lowest prices with Fast &amp; Free shipping on many items!">
        </head>
        <body>
          <main>
            <p>We use cookies and other technologies that are essential to provide you our services and site functionality.</p>
            <p>Accept all</p>
          </main>
        </body>
      </html>
    HTML

    with_page(html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["markdown"]).to include("# Ruby Programming for sale | eBay")
      expect(payload["markdown"]).to include("Get the best deals for Ruby Programming at eBay.com.")
      expect(payload["markdown"]).not_to include("We use cookies and other technologies")
      expect(payload["warnings"]).to include("consent_interstitial")
    end
  end

  it "extracts Stack Exchange questions together with top answers" do
    html = <<~HTML
      <html>
        <head>
          <title>How likely is it that any non-Celtic language was spoken in the British Isles when the Romans invaded? - History Stack Exchange</title>
        </head>
        <body>
          <main>
            <div class="question" id="question">
              <div class="question-header">
                <h1>How likely is it that any non-Celtic language was spoken in the British Isles when the Romans invaded?</h1>
              </div>
              <div class="user-details"><a href="/users/1/timothy">Timothy</a></div>
              <div class="js-post-body">We know from Roman writers the names of many ancient British tribes, but not much about their language boundaries.</div>
            </div>
            <div id="answers">
              <div class="answer accepted-answer">
                <span class="js-vote-count">33</span>
                <div class="user-details"><a href="/users/2/example">Example User</a></div>
                <div class="js-post-body">The answer appears to be that we do not know with certainty. Earlier languages likely existed before Celtic spread, but the evidence is fragmentary.</div>
              </div>
            </div>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://history.stackexchange.com/questions/68200/example", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["markdown"]).to include("## Top Answers")
      expect(payload["markdown"]).to include("### Example User (accepted) - score 33")
      expect(payload["markdown"]).to include("Earlier languages likely existed before Celtic spread")
    end
  end

  it "extracts Substack post bodies instead of related links and comments" do
    html = <<~HTML
      <html>
        <head>
          <title>The end of the vibecession? - Example Stack</title>
          <meta property="og:image" content="https://substackcdn.com/image/fetch/example.jpg">
        </head>
        <body>
          <article class="typography newsletter-post post">
            <div class="post-header">
              <h1 class="post-title published">The end of the vibecession?</h1>
              <div class="byline-names">Example Writer</div>
            </div>
            <div class="available-content">
              <div dir="auto" class="body markup">
                <p>One constant source of frustration for econ writers and economists is that the connection between public perceptions of the economy and the actual state of the economy is not clear.</p>
                <p>That does not mean the connection does not exist, or that people's perceptions are simply random noise.</p>
                <p>The more useful question is whether wages, prices, and employment are moving in ways that match what people say they feel.</p>
                <p>Those facts make the vibecession debate a real article body rather than a list of recommended posts.</p>
              </div>
            </div>
          </article>
          <section class="related-posts">
            <a href="/p/yes-were-probably-in-a-recession">have a recession</a>
            <a href="/p/another-post">Another related post</a>
          </section>
          <div class="comment-list post-page-root-comment-list">
            <a href="/p/the-end/comment/1">Jun 28, 2023</a>
            <a href="/p/the-end/comments">102 more comments...</a>
          </div>
        </body>
      </html>
    HTML

    extract_from_url("https://example.substack.com/p/the-end-of-the-vibecession", html) do |payload|
      expect(payload["contentType"]).to eq("article")
      expect(payload["markdown"]).to include("# The end of the vibecession?")
      expect(payload["markdown"]).to include("One constant source of frustration")
      expect(payload["markdown"]).to include("vibecession debate a real article body")
      expect(payload["markdown"]).not_to include("102 more comments")
      expect(payload["markdown"]).not_to include("have a recession")
    end
  end

  it "does not misclassify non-meta pages that mention facebook in share chrome" do
    html = <<~HTML
      <html>
        <head>
          <title>The New Yorker</title>
          <meta name="description" content="Reporting, Profiles, breaking news, cultural coverage, podcasts, videos, and cartoons from The New Yorker.">
        </head>
        <body>
          <main>
            <h1>The New Yorker</h1>
            <p>Reporting, Profiles, breaking news, cultural coverage, podcasts, videos, and cartoons from The New Yorker.</p>
            <a href="https://facebook.com/sharer">Share on Facebook</a>
          </main>
        </body>
      </html>
    HTML

    with_page(html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["warnings"]).not_to include("meta_login_wall")
    end
  end

  it "prefers legal provision text over legislation navigation chrome" do
    html = <<~HTML
      <html>
        <head><title>Example Rights Act 1998</title></head>
        <body>
          <div id="layout2" class="legContent">
            <h1 id="pageTitle">Example Rights Act 1998</h1>
            <div id="breadCrumb"><h2>You are here:</h2><a href="/acts">Acts</a><span>Section 1</span></div>
            <div id="legNav">
              <ul><li>Table of Contents</li><li>Content</li><li>More Resources</li></ul>
              <section><h2>What Version</h2><p>Legislation is available in different versions.</p></section>
              <section><h2>Opening Options</h2><p>Open whole Act, schedules, or this section only.</p></section>
            </div>
            <div id="changesOverTime"><h2>Changes over time for: Section 1</h2><p>Timeline of Changes help text.</p></div>
            <div id="content">
              <div id="viewLegContents">
                <div class="LegislationSection">
                  <h3>1 The Protected Rights</h3>
                  <p>(1) In this Act the protected rights mean the rights and fundamental freedoms set out in the Convention.</p>
                  <p>(2) Those rights have effect subject to any designated derogation or reservation.</p>
                  <p>(3) The Articles are set out in Schedule 1.</p>
                </div>
              </div>
            </div>
          </div>
        </body>
      </html>
    HTML

    extract_from_url("https://www.legislation.example/ukpga/1998/42/section/1", html) do |payload|
      expect(payload["contentType"]).to eq("article")
      expect(payload["markdown"]).to include("1 The Protected Rights")
      expect(payload["markdown"]).to include("(1) In this Act the protected rights")
      expect(payload["markdown"]).not_to include("What Version")
      expect(payload["markdown"]).not_to include("Timeline of Changes help text")
      expect(payload["markdown"]).not_to include("More Resources")
    end
  end
end
