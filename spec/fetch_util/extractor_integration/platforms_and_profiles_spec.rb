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

  it "extracts Drupal paragraph component hubs beyond the intro paragraph" do
    html = <<~HTML
      <html>
        <head>
          <title>Legal Affairs | UNESCO</title>
          <meta name="Generator" content="Drupal 10">
        </head>
        <body class="path-legal-affairs node-66535">
          <header><a href="/en/search">Search</a><a href="/en/donate">Donate</a></header>
          <article class="node--view-mode-full node node--type-structured-data-hub node--promoted">
            <h1>Legal Affairs</h1>
            <nav class="hub-menu"><a href="/en/legal-affairs/oisla">Our team</a></nav>
            <div class="field field--name-field-paragraphs field--type-entity-reference-revisions field--label-hidden field__items">
              <div class="field__item fadein">
                <div data-trk="{&quot;block&quot;:{&quot;name&quot;:&quot;Legal Affairs &gt; Paragraphs&quot;,&quot;format&quot;:&quot;rich_text&quot;}}" class="paragraph paragraph--type--rich-text paragraph--view-mode--default">
                  <div class="rich-text field field--name-field-text field--type-text-long field__item">
                    <p>The Office of International Standards and Legal Affairs provides centralized and independent legal advice to the General Conference, the Executive Board and other intergovernmental bodies.</p>
                  </div>
                </div>
              </div>
              <div class="field__item fadein">
                <div id="highlights" data-trk="{&quot;block&quot;:{&quot;name&quot;:&quot;Highlights&quot;,&quot;format&quot;:&quot;cards_landing&quot;}}" class="paragraph paragraph--type--cards-landing paragraph--view-mode--default">
                  <div class="field field--name-field-title field__item"><h2>Highlights</h2></div>
                  <div class="card-list row">
                    <article class="card"><h3><a href="/en/legal-affairs/monitoring">New one-stop-shop for monitoring the implementation of standard-setting instruments</a></h3><p>Discover monitoring and assessment tools.</p></article>
                    <article class="card"><h3><a href="/en/legal-affairs/calendar">Calendar of major meetings in 2026</a></h3><p>Governing bodies, conventions and other meetings.</p></article>
                    <article class="card"><h3><a href="/en/legal-affairs/legal-texts">Legal texts on UNESCO Conventions</a></h3><p>Rules of procedure, operational guidelines, decisions and documents.</p></article>
                  </div>
                </div>
              </div>
              <div class="field__item fadein">
                <div data-trk="{&quot;block&quot;:{&quot;name&quot;:&quot;Priorities&quot;,&quot;format&quot;:&quot;cards_landing&quot;}}" class="paragraph paragraph--type--cards-landing paragraph--view-mode--default">
                  <h2>UNESCO Constitution</h2>
                  <div class="card-list"><article class="card"><h3><a href="/en/legal-affairs/constitution">Constitution and basic texts</a></h3><p>Constitutional instruments of the Organization.</p></article></div>
                </div>
              </div>
            </div>
          </article>
        </body>
      </html>
    HTML

    extract_from_url("https://www.unesco.org/en/legal-affairs", html) do |payload|
      expect(payload["contentType"]).to eq("article")
      expect(payload["markdown"]).to include("# Legal Affairs")
      expect(payload["markdown"]).to include("The Office of International Standards and Legal Affairs")
      expect(payload["markdown"]).to include("## Highlights")
      expect(payload["markdown"]).to include("New one-stop-shop for monitoring")
      expect(payload["markdown"]).to include("Legal texts on UNESCO Conventions")
      expect(payload["markdown"]).to include("## UNESCO Constitution")
      expect(payload["warnings"]).not_to include("truncated_content")
      expect(payload["markdown"]).not_to include("Donate")
    end
  end

  it "extracts Drupal entity-block research hubs beyond the intro paragraph" do
    html = <<~HTML
      <html>
        <head><title>Our research | CNRS</title></head>
        <body class="path-node node-8005">
          <main role="main">
            <section class="node node--type-page article top node--view-mode-full">
              <div class="left-column"><div class="sharing"><a href="/share">Share this content</a></div></div>
              <div class="main-column">
                <h1><span class="field field--name-title">Our research</span></h1>
                <div class="introduction">
                  <div class="field field--name-body field--type-text-with-summary field__item">
                    <p>Research must deliver benefit. It must benefit society and help humanity to progress.</p>
                  </div>
                </div>
                <div class="field field--name-field-entity-block field--type-entity-reference field__items">
                  <div class="field__item"><div class="entity-block content-data">
                    <div class="section-elements"><div class="field field--name-field-key-figures-paragraphs field__items">
                      <div class="field__item"><div class="data-bloc"><div class="data"><span>1100</span> laboratories across France</div></div></div>
                      <div class="field__item"><div class="data-bloc"><div class="data"><span>28,000</span> scientists of 90 different nationalities</div></div></div>
                    </div></div>
                  </div></div>
                  <div class="field__item"><div class="block-description"><div class="field field--name-field-descriptive field__item"><h2>Research at the CNRS</h2></div></div></div>
                  <div class="field__item"><article class="entity-block content-link">
                    <div class="content-desc"><h3><a href="/en/disciplines">Disciplines</a></h3>
                    <div class="field field--name-field-desc field__item">Since it explores all fields of science, research at the CNRS is intrinsically multidisciplinary.</div>
                    <a href="/en/disciplines">/en/disciplines</a></div>
                  </article></div>
                  <div class="field__item"><article class="entity-block content-link">
                    <div class="content-desc"><h3><a href="/en/partnerships">Partnerships</a></h3>
                    <div class="field field--name-field-desc field__item">Bringing stakeholders together and fostering long-lasting collaboration.</div></div>
                  </article></div>
                  <div class="field__item"><div class="block-description"><div class="field field--name-field-descriptive field__item"><h2>Research for the benefit of society</h2></div></div></div>
                  <div class="field__item"><article class="entity-block content-link">
                    <div class="content-desc"><h3><a href="/en/our-innovations">Research driving innovation</a></h3>
                    <div class="field field--name-field-desc field__item">Innovative inventions, technologies and businesses begin in laboratories conducting basic research.</div></div>
                  </article></div>
                  <div class="field__item"><div class="section-elements entity-block block-toggle">
                    <div class="field field--name-field-toggle-paragraph field__items">
                      <div class="field__item"><h3>The Higgs boson</h3><div class="field field--name-field-toggle-desc field__item">The existence of this particle was predicted in 1964 and observed in 2012.</div></div>
                      <div class="field__item"><h3>Artificial brain</h3><div class="field field--name-field-toggle-desc field__item">Electronic synapses capable of independent learning have been developed by researchers.</div></div>
                    </div>
                  </div></div>
                </div>
              </div>
            </section>
          </main>
        </body>
      </html>
    HTML

    extract_from_url("https://www.cnrs.fr/en/our-research", html) do |payload|
      expect(payload["contentType"]).to eq("article")
      expect(payload["markdown"]).to include("# Our research")
      expect(payload["markdown"]).to include("1100 laboratories across France")
      expect(payload["markdown"]).to include("## Research at the CNRS")
      expect(payload["markdown"]).to include("Disciplines")
      expect(payload["markdown"]).to include("Research driving innovation")
      expect(payload["markdown"]).to include("The Higgs boson")
      expect(payload["warnings"]).not_to include("truncated_content")
      expect(payload["markdown"]).not_to include("Share this content")
      expect(payload["markdown"]).not_to include("/en/disciplines\n")
    end
  end

  it "extracts legal convention index lists from institutional page content" do
    html = <<~HTML
      <html>
        <head><title>HCCH | Conventions and other Instruments</title></head>
        <body class="templ23 sectie49">
          <nav class="navbar"><a href="/en/members">Members</a><a href="/en/instruments">Instruments</a></nav>
          <div class="page-content">
            <div class="container">
              <div class="textblock"><div class="block-content">
                <h2 class="text-center">Conventions and other Instruments</h2>
                <p>Since its inception, over 40 Conventions and instruments have been adopted under the auspices of the organisation.</p>
              </div></div>
              <div class="textblock"><div class="block-content"><h2>Core Conventions and Instruments</h2></div></div>
              <ul class="arrows">
                <li><a href="/en/instruments/conventions/specialised-sections/apostille">1961 Apostille Convention</a> [12]</li>
                <li><a href="/en/instruments/conventions/specialised-sections/service">1965 Service Convention</a> [14]</li>
                <li><a href="/en/instruments/conventions/specialised-sections/evidence">1970 Evidence Convention</a> [20]</li>
                <li><a href="/en/instruments/conventions/specialised-sections/child-abduction">1980 Child Abduction Convention</a> [28]</li>
              </ul>
              <div class="textblock"><div class="block-content"><h2>Other Conventions and Instruments</h2></div></div>
              <ul class="arrows">
                <li><a href="/en/instruments/conventions/full-text/?cid=33">Convention of 1 March 1954 on civil procedure</a> [02]</li>
                <li><a href="/en/instruments/conventions/full-text/?cid=31">Convention of 15 June 1955 on the law applicable to international sales of goods</a> [03]</li>
                <li><a href="/en/instruments/conventions/full-text/?cid=32">Convention of 15 April 1958 on the law governing transfer of title in international sales of goods</a> [04]</li>
                <li><a href="/en/instruments/conventions/full-text/?cid=34">Convention of 15 April 1958 on the jurisdiction of the selected forum in international sales of goods</a> [05]</li>
              </ul>
            </div>
          </div>
        </body>
      </html>
    HTML

    extract_from_url("https://www.legal-institution.example/en/instruments/conventions", html) do |payload|
      expect(payload["contentType"]).to eq("article")
      expect(payload["markdown"]).to include("# HCCH | Conventions and other Instruments")
      expect(payload["markdown"]).to include("## Core Conventions and Instruments")
      expect(payload["markdown"]).to include("[1961 Apostille Convention](https://www.legal-institution.example/en/instruments/conventions/specialised-sections/apostille)")
      expect(payload["markdown"]).to include("[Convention of 1 March 1954 on civil procedure](https://www.legal-institution.example/en/instruments/conventions/full-text/?cid=33)")
      expect(payload["markdown"]).not_to include("Members")
      expect(payload["warnings"]).not_to include("truncated_content")
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

  it "extracts institutional subsection card hubs as full page content" do
    html = <<~HTML
      <html>
        <head>
          <title>Research | CSIRO</title>
          <meta name="description" content="Our research focuses on the biggest challenges facing the nation.">
        </head>
        <body>
          <header><a href="/en/search">Search</a><a href="/en/research">Research</a></header>
          <section class="banner"><h1>Research</h1><p>Our research focuses on the biggest challenges facing the nation.</p></section>
          <main>
            <div class="page-content no-wrap">
              <div class="page__section"><div class="standard-container">
                <div class="grid grid--large-horizontal-gap grid--no-wrap grid--1-2">
                  <div class="grid__item grid__item--primary">
                    <h2>Australia's national science agency</h2>
                    <p>We imagine. We collaborate. We innovate. We're Australia's national science research agency.</p>
                    <p>We are one of the largest and most diverse scientific research organisations in the world.</p>
                  </div>
                  <div class="grid__item"><div class="embed"><p>Copy embed code</p></div></div>
                </div>
              </div></div>
              <div class="page__section bg--grey featured-item">
                <div class="teaser teaser--full-width"><div class="teaser__content">
                  <h2 class="teaser__component-title">Medical research</h2>
                  <h3 class="teaser__item-title">Understanding the virus that causes COVID-19</h3>
                  <p class="teaser__text">Our first challenge has been to understand this new virus and how it impacts the respiratory system.</p>
                  <a href="/en/research/health-medical/diseases/COVID-19-research">More about COVID-19</a>
                </div></div>
              </div>
              <div class="page__section"><div class="standard-container">
                <h2 class="text--remove-margin">Browse our research</h2>
                <div class="grid grid--3 card--with-subsections">
                  <div class="grid__item"><div class="card"><a href="/en/research/natural-environment"><div class="card__content card__content--reduced"><h3 class="card__title">Natural environments</h3><p class="card__summary">Our research helps maintain environments and ensure natural resources are used sustainably.</p></div></a><div class="card__content"><h4>Subcategories</h4><ul><li><a href="/en/research/natural-environment/atmosphere">Atmosphere</a></li><li><a href="/en/research/natural-environment/water">Water</a></li></ul></div></div></div>
                  <div class="grid__item"><div class="card"><a href="/en/research/technology-space"><div class="card__content card__content--reduced"><h3 class="card__title">Technology and space</h3><p class="card__summary">Satellites, sensors and telescopes help secure Australia's digital future.</p></div></a><div class="card__content"><h4>Subcategories</h4><ul><li><a href="/en/research/technology-space/ai">Artificial Intelligence</a></li><li><a href="/en/research/technology-space/energy">Energy</a></li></ul></div></div></div>
                  <div class="grid__item"><div class="card"><a href="/en/research/production"><div class="card__content card__content--reduced"><h3 class="card__title">Production</h3><p class="card__summary">Production that is innovative, productive, competitive and sustainable is vital to prosperity.</p></div></a><div class="card__content"><h4>Subcategories</h4><ul><li><a href="/en/research/production/biotechnology">Biotechnology</a></li><li><a href="/en/research/production/materials">Materials</a></li></ul></div></div></div>
                  <div class="grid__item"><div class="card"><a href="/en/research/health-medical"><div class="card__content card__content--reduced"><h3 class="card__title">Health and medical</h3><p class="card__summary">We work to prevent illnesses and improve detection, treatment and recovery.</p></div></a><div class="card__content"><h4>Subcategories</h4><ul><li><a href="/en/research/health-medical/diagnostics">Diagnostics</a></li><li><a href="/en/research/health-medical/vaccines">Vaccines and drugs</a></li></ul></div></div></div>
                </div>
              </div></div>
            </div>
          </main>
        </body>
      </html>
    HTML

    extract_from_url("https://www.csiro.au/en/research", html) do |payload|
      expect(payload["contentType"]).to eq("article")
      expect(payload["markdown"]).to include("# Research")
      expect(payload["markdown"]).to include("Australia's national science agency")
      expect(payload["markdown"]).to include("Medical research")
      expect(payload["markdown"]).to include("Browse our research")
      expect(payload["markdown"]).to include("Natural environments")
      expect(payload["markdown"]).to include("Technology and space")
      expect(payload["markdown"]).to include("Production that is innovative")
      expect(payload["markdown"]).to include("Vaccines and drugs")
      expect(payload["warnings"]).not_to include("multi_topic_page")
      expect(payload["markdown"]).not_to include("Copy embed code")
    end
  end

  it "extracts institutional block teaser page-builder hubs beyond the intro teaser" do
    html = <<~HTML
      <html>
        <head>
          <title>Research and transfer | DLR</title>
          <meta name="description" content="DLR conducts research in aeronautics, space, energy, transport, digitalisation and security.">
        </head>
        <body>
          <header><a href="/en/about-us">About us</a><a href="/en/search">Search</a></header>
          <main>
            <div class="page-document ui container">
              <h1 id="documentFirstHeading">Research and transfer</h1>
              <div class="block __grid centered two has--backgroundColor--transparent has--headline">
                <h2 class="headline">DLR's research areas</h2>
                <div class="ui stackable stretched two column grid">
                  <div class="column grid-block-teaser"><div class="block teaser"><div class="grid-teaser-item default"><div class="content"><h2><a href="/en/research/aeronautics">Aeronautics</a></h2><p>DLR aeronautics research develops efficient aircraft, sustainable aviation systems and safe flight operations.</p></div></div></div></div>
                  <div class="column grid-block-teaser"><div class="block teaser"><div class="grid-teaser-item default"><div class="content"><h2><a href="/en/research/space">Space</a></h2><p>Space research explores Earth observation, robotic missions, satellite technology and astronaut training.</p></div></div></div></div>
                </div>
              </div>
              <div class="block __grid centered two has--backgroundColor--transparent has--headline">
                <h2 class="headline">Interdisciplinary and cross-divisional research</h2>
                <div class="ui stackable stretched two column grid">
                  <div class="column grid-block-teaser"><div class="block teaser"><div class="grid-teaser-item default"><div class="content"><h2><a href="/en/research/security">Security and defence</a></h2><p>Research for civil security and defence strengthens resilient infrastructure and operational capability.</p></div></div></div></div>
                  <div class="column grid-block-teaser"><div class="block teaser"><div class="grid-teaser-item default"><div class="content"><h2><a href="/en/research/digitalisation">Digitalisation</a></h2><p>Digitalisation research connects simulation, artificial intelligence and data platforms across all DLR fields.</p></div></div></div></div>
                </div>
              </div>
              <div class="block __grid centered one has--backgroundColor--grey has--headline">
                <h2 class="headline">From research to application</h2>
                <div class="ui stackable stretched one column grid">
                  <div class="column grid-block-teaser"><div class="block teaser"><div class="grid-teaser-item default"><div class="content"><h2>Innovation and transfer</h2><p>Germany is a progressive and innovative country, open to sustainable solutions for environmental, technological, economic and geopolitical challenges.</p></div></div></div></div>
                </div>
              </div>
              <div class="block heading"><h2 class="heading">Research infrastructure</h2></div>
              <div class="block teaser has--align--left"><div class="grid-teaser-item default"><div class="content"><h2>Airbus A320 Advanced Technology Research Aircraft (D-ATRA)</h2><p>The ATRA research aircraft supports flight experiments and new aviation technologies.</p></div></div></div>
              <div class="block teaser has--align--right"><div class="grid-teaser-item default"><div class="content"><h2>European Proximity Operations Simulator (EPOS 2.0)</h2><p>The simulator enables large-scale experiments for rendezvous and docking operations.</p></div></div></div>
            </div>
          </main>
          <footer><a href="/en/privacy">Privacy Policy</a></footer>
        </body>
      </html>
    HTML

    extract_from_url("https://www.dlr.de/en/research-and-transfer", html) do |payload|
      expect(payload["contentType"]).to eq("article")
      expect(payload["markdown"]).to include("# Research and transfer")
      expect(payload["markdown"]).to include("## DLR's research areas")
      expect(payload["markdown"]).to include("Aeronautics")
      expect(payload["markdown"]).to include("Interdisciplinary and cross-divisional research")
      expect(payload["markdown"]).to include("Security and defence")
      expect(payload["markdown"]).to include("## Research infrastructure")
      expect(payload["markdown"]).to include("European Proximity Operations Simulator")
      expect(payload["warnings"]).not_to include("truncated_content")
      expect(payload["markdown"]).not_to include("Privacy Policy")
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

  it "extracts public CSDN article bodies from the article container" do
    html = <<~HTML
      <html>
        <head>
          <title>Java即将放弃Intel Mac：JDK 27起不再续命-CSDN博客</title>
          <meta name="description" content="Intel 版 Mac 的退场又迎来一个标志性节点。">
        </head>
        <body>
          <header><a href="/download">下载</a><a href="/login">登录</a></header>
          <main>
            <div class="title-box"><h1 id="article-tit">Java即将放弃Intel Mac：JDK 27起不再续命</h1></div>
            <div class="article-bar-top"><span class="time">2026-07-06 11:16:42</span><a class="name" href="https://blog.csdn.net/csdnnews">csdnnews</a></div>
            <article>
              <div id="article_content" class="article_content clearfix">
                <div id="content_views" class="markdown_views prism-atom-one-dark">
                  <p>Intel 版 Mac 的退场又迎来一个标志性节点。</p>
                  <p>OpenJDK 社区正在讨论在 JDK 27 中移除 macOS x64 的构建支持。</p>
                  <h2>为什么是现在？</h2>
                  <p>苹果转向 Apple Silicon 已经多年，维护旧平台的成本不断上升。</p>
                  <p>开发者仍可继续使用较早版本的 JDK，但新的主线版本将聚焦现代硬件。</p>
                </div>
                <div class="readall_box">登录后阅读全文</div>
              </div>
            </article>
            <aside class="recommend-box">相关推荐</aside>
          </main>
        </body>
      </html>
    HTML

    extract_from_url("https://blog.csdn.net/csdnnews/article/details/162627987", html) do |payload|
      expect(payload["contentType"]).to eq("article")
      expect(payload["markdown"]).to include("# Java即将放弃Intel Mac：JDK 27起不再续命")
      expect(payload["markdown"]).to include("OpenJDK 社区正在讨论")
      expect(payload["markdown"]).to include("## 为什么是现在？")
      expect(payload["warnings"]).not_to include("empty_extraction")
      expect(payload["warnings"]).not_to include("url_content_mismatch")
      expect(payload["markdown"]).not_to include("登录后阅读全文")
      expect(payload["markdown"]).not_to include("相关推荐")
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

  it "extracts Xinhua weekly indexes as lists instead of footer copyright" do
    html = <<~HTML
      <html>
        <head>
          <title>Biz China Weekly | English.news.cn</title>
        </head>
        <body>
          <div id="categoryTitle" class="title">Biz China Weekly</div>
          <div id="list" class="list-cont">
            <div class="item">
              <div class="img"><a href="https://www.news.cn/english/bizweekly/883.htm"><img src="cover-883.jpg" alt="Jun. 29 - Jul. 05"></a></div>
              <div class="tit"><span><a href="https://www.news.cn/english/bizweekly/883.htm">Jun. 29 - Jul. 05</a></span></div>
            </div>
            <div class="item">
              <div class="img"><a href="https://www.news.cn/english/bizweekly/882.htm"><img src="cover-882.jpg" alt="Jun. 22 - Jun. 28"></a></div>
              <div class="tit"><span><a href="https://www.news.cn/english/bizweekly/882.htm">Jun. 22 - Jun. 28</a></span></div>
            </div>
            <div class="item">
              <div class="img"><a href="https://www.news.cn/english/bizweekly/881.htm"><img src="cover-881.jpg" alt="Jun. 15 - Jun. 21"></a></div>
              <div class="tit"><span><a href="https://www.news.cn/english/bizweekly/881.htm">Jun. 15 - Jun. 21</a></span></div>
            </div>
            <div class="item">
              <div class="img"><a href="https://www.news.cn/english/bizweekly/880.htm"><img src="cover-880.jpg" alt="Jun. 08 - Jun. 14"></a></div>
              <div class="tit"><span><a href="https://www.news.cn/english/bizweekly/880.htm">Jun. 08 - Jun. 14</a></span></div>
            </div>
          </div>
          <div id="foot">Copyright © 2000- 2026 XINHUANET.com All rights reserved.</div>
        </body>
      </html>
    HTML

    extract_from_url("https://english.news.cn/weekly.htm", html) do |payload|
      expect(payload["contentType"]).to eq("list")
      expect(payload["title"]).to eq("Biz China Weekly | English.news.cn")
      expect(payload["markdown"]).to include("- [Jun. 29 - Jul. 05](https://www.news.cn/english/bizweekly/883.htm)")
      expect(payload["markdown"]).to include("- [Jun. 08 - Jun. 14](https://www.news.cn/english/bizweekly/880.htm)")
      expect(payload["warnings"]).not_to include("short_extraction")
      expect(payload["markdown"]).not_to include("Copyright © 2000- 2026 XINHUANET.com All rights reserved.")
    end
  end
end
