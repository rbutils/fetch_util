# frozen_string_literal: true

RSpec.describe 'FetchUtil academic abstract extraction' do
  include_context 'extractor integration helpers'

  def fetch_result_from_payload(url, payload, final_url: url)
    browser = instance_double(FetchUtil::Browser)
    extractor = instance_double(FetchUtil::Extractor)
    raw_docs_fallback = instance_double(FetchUtil::RawDocsFallback, fetch: nil)

    allow(browser).to receive(:with_page).with(url).and_yield(instance_double('FerrumPage', current_url: final_url))
    allow(extractor).to receive(:extract).and_return(payload)

    FetchUtil::Fetcher.new(browser: browser, extractor: extractor, raw_docs_fallback: raw_docs_fallback).fetch(url)
  end

  def scholarly_article_payload(title:, site_name:, byline:, published_time: nil)
    prose = Array.new(6) do |index|
      "This article paragraph #{index} reports experimental observations, explains methodological controls, " \
        "and compares results across conditions with enough continuous prose to distinguish a full " \
        "scholarly article body from an index of linked article cards."
    end.join("\n\n")
    references = Array.new(5) do |index|
      "- [Reference #{index} with linked scholarly citation](https://doi.org/10.1000/example#{index})"
    end.join("\n")

    {
      'title' => title,
      'siteName' => site_name,
      'byline' => byline,
      'publishedTime' => published_time,
      'contentType' => 'list',
      'markdown' => <<~MARKDOWN,
        # #{title}

        ## Abstract

        #{prose}

        ## Introduction

        #{prose}

        ## Methods

        #{prose}

        ## Results

        #{prose}

        ## Discussion

        #{prose}

        ## References

        #{references}
      MARKDOWN
      'warnings' => []
    }
  end

  it 'extracts PLOS style open-access article sections from the article text root' do
    html = <<~HTML
      <html>
        <head>
          <title>Microbial activity across coastal wetlands | PLOS One</title>
          <meta property="og:site_name" content="PLOS One">
          <meta name="citation_doi" content="10.1371/journal.pone.0999999">
          <meta name="citation_journal_title" content="PLOS One">
        </head>
        <body>
          <header><a href="/">plos.org</a><a href="/metrics">Article metrics</a></header>
          <main>
            <div class="article-header">
              <h1>Microbial activity across coastal wetlands</h1>
              <p>Open Access Peer-reviewed Research Article</p>
            </div>
            <div id="nav-article">
              <ul class="nav-page">
                <li><a href="#abstract0">Abstract</a></li>
                <li><a href="#s1">Introduction</a></li>
                <li><a href="#s2">Materials and methods</a></li>
                <li><a href="#s3">Results</a></li>
              </ul>
            </div>
            <div class="article-content">
              <div class="article-text" id="artText">
                <div class="abstract toc-section abstract-type-"><a id="abstract0" data-toc="abstract0" title="Abstract"></a><h2>Abstract</h2>
                  <div class="abstract-content"><p>Coastal wetland microbial activity was measured across restored marsh sites and reference habitats.</p></div>
                </div>
                <div id="figure-carousel-section"><h2>Figures</h2><div class="carousel-item">Figure chrome only</div></div>
                <div class="articleinfo"><p><strong>Citation:</strong> Example Authors (2026) Coastal wetlands.</p></div>
                <div id="section1" class="section toc-section"><a id="s1" name="s1" data-toc="s1" class="link-target" title="Introduction"></a><h2>Introduction</h2>
                  <p>Introduction prose explains why restoration gradients need complete microbial measurements across multiple wetland zones.</p>
                </div>
                <div id="section2" class="section toc-section"><a id="s2" name="s2" data-toc="s2" class="link-target" title="Materials and methods"></a><h2>Materials and methods</h2>
                  <p>Methods prose describes replicated sediment cores, porewater chemistry, sequencing, and enzyme assays collected by season.</p>
                </div>
                <div id="section3" class="section toc-section"><a id="s3" name="s3" data-toc="s3" class="link-target" title="Results"></a><h2>Results</h2>
                  <p>Results prose reports higher denitrification potential in restored marsh interiors than in unvegetated reference plots.</p>
                </div>
              </div>
            </div>
            <aside class="metrics-panel"><h2>Metrics</h2><p>Views Citations Saves</p></aside>
          </main>
        </body>
      </html>
    HTML

    extract_from_url('https://journals.plos.org/plosone/article?id=10.1371/journal.pone.0999999', html) do |payload|
      markdown = payload['markdown']

      expect(payload['contentType']).to eq('article')
      expect(payload['hostAware']).to eq(true)
      expect(markdown).to include('# Microbial activity across coastal wetlands')
      expect(markdown).to include('## Abstract')
      expect(markdown).to include('## Introduction')
      expect(markdown).to include('restoration gradients need complete microbial measurements')
      expect(markdown).to include('## Materials and methods')
      expect(markdown).to include('replicated sediment cores')
      expect(markdown).to include('## Results')
      expect(markdown).to include('higher denitrification potential')
      expect(markdown).not_to include('Article metrics')
      expect(markdown).not_to include('Figure chrome only')
      expect(markdown).not_to include('Views Citations Saves')
    end
  end

  it 'keeps eLife-style open access article sections as articles when citations look list-like' do
    payload = scholarly_article_payload(
      title: 'Pathogenic Huntingtin aggregates alter actin organization and cellular stiffness',
      site_name: 'eLife Sciences Publications, Ltd',
      byline: 'Surya Bansi Singh, Shatruhan Singh Rajput',
      published_time: '2024-10-09'
    )

    result = fetch_result_from_payload('https://elifesciences.org/articles/98363', payload)

    expect(result.content_type).to eq('article')
    expect(result.suspect).to eq(false)
    expect(result.markdown).to include('## Abstract')
    expect(result.markdown).to include('## Results')
  end

  it 'keeps PeerJ-style open access article bodies as articles when references look list-like' do
    payload = scholarly_article_payload(
      title: 'New agri-environmental measures have a direct effect on wildlife and economy',
      site_name: 'PeerJ',
      byline: 'Petr Marada, Jan Cukor, Michal Kubenka'
    )

    result = fetch_result_from_payload('https://peerj.com/articles/15000/', payload)

    expect(result.content_type).to eq('article')
    expect(result.suspect).to eq(false)
    expect(result.markdown).to include('## Introduction')
    expect(result.markdown).to include('## Discussion')
  end

  it 'extracts ACS abstracts without metrics and access chrome' do
    html = <<~HTML
      <html>
        <head>
          <title>Learning Chemical Equilibrium with Studio Activities - ACS Publications</title>
          <meta property="og:site_name" content="ACS Publications">
          <meta name="citation_doi" content="10.1021/acs.jchemeduc.4c00045">
          <meta name="citation_journal_title" content="Journal of Chemical Education">
          <meta name="citation_publisher" content="American Chemical Society">
        </head>
        <body>
          <header>
            <a href="/action/ssostart">Access through institution</a>
            <a href="/action/showLogin">Log In</a>
          </header>
          <main>
            <article>
              <h1 class="article_header-title">Learning Chemical Equilibrium with Studio Activities</h1>
              <div class="article_abstract">
                <h2>Abstract</h2>
                <p>Students in a general chemistry course completed studio activities that connected equilibrium constants, reaction quotients, and particulate-level models.</p>
                <p>Assessment responses showed improved explanations of dynamic equilibrium without relying on unrelated metrics widgets.</p>
              </div>
            </article>
            <aside class="articleMetrics"><h2>Metrics</h2><p>Article Views 12,431 Altmetric Citations</p></aside>
            <section class="access-options"><h2>Get Access</h2><p>Purchase short-term access or sign in through your institution.</p></section>
            <section class="recommended"><h2>Recommended Articles</h2><p>Recommended chemistry education article chrome.</p></section>
            <section class="references"><h2>References</h2><p>Google Scholar Crossref citation chrome.</p></section>
            <div class="advertisement">Advertisement</div>
          </main>
        </body>
      </html>
    HTML

    extract_from_url('https://pubs.acs.org/doi/10.1021/acs.jchemeduc.4c00045', html) do |payload|
      markdown = payload['markdown']

      expect(payload['contentType']).to eq('article')
      expect(payload['hostAware']).to eq(true)
      expect(markdown).to include('# Learning Chemical Equilibrium with Studio Activities')
      expect(markdown).to include('## Abstract')
      expect(markdown).to include('connected equilibrium constants, reaction quotients')
      expect(markdown).to include('improved explanations of dynamic equilibrium')
      expect(markdown).not_to include('Article Views')
      expect(markdown).not_to include('Purchase short-term access')
      expect(markdown).not_to include('Recommended chemistry education')
      expect(markdown).not_to include('Google Scholar Crossref')
      expect(markdown).not_to include('Advertisement')
    end
  end

  it 'extracts Elsevier article bodies instead of citation and supplementary chrome' do
    html = <<~HTML
      <html>
        <head>
          <title>Spatial immune interactions in regenerating tissue</title>
          <meta property="og:site_name" content="Cell Reports">
          <meta name="citation_pii" content="S2211-1247(26)00512-7">
          <link id="build-style-article" rel="stylesheet" href="/products/marlin/cell/releasedAssets/css/build-article.css">
        </head>
        <body>
          <main>
            <h1>Spatial immune interactions in regenerating tissue</h1>
            <div id="abstracts" data-extent="frontmatter">
              <section id="author-highlights-abstract" property="abstract" typeof="Text" role="doc-abstract">
                <h2 property="name">Highlights</h2>
                <div role="list">
                  <div role="listitem"><div class="label">&bull;</div><div class="content"><div role="paragraph">Macrophage and stromal niches coordinate tissue regeneration</div></div></div>
                </div>
              </section>
              <section id="author-abstract" property="abstract" typeof="Text" role="doc-abstract">
                <h2 property="name">Summary</h2>
                <div role="paragraph">Single-cell multi-omics identifies immune and stromal interactions that promote regeneration after injury.</div>
              </section>
              <section id="keywords" property="keywords">
                <h2>Keywords</h2>
                <ol><li><a href="/action/doSearch?AllField=regeneration">regeneration</a></li></ol>
              </section>
            </div>
            <section id="bodymatter" data-extent="bodymatter" property="articleBody" typeof="Text">
              <div class="core-container">
                <section id="sec1"><h2>Introduction</h2><div role="paragraph">The endometrium regenerates repeatedly, requiring coordinated immune, epithelial, and stromal programs across tissue regions.</div></section>
                <section id="sec2"><h2>Results</h2><div role="paragraph">Spatial transcriptomics revealed macrophage-SFRP4 positive stromal interactions near repair zones and persistent regenerative gradients.</div></section>
                <section id="sec3"><h2>Discussion</h2><div role="paragraph">These data show how local immune signaling can promote tissue repair without relying on unrelated citation widgets.</div></section>
              </div>
            </section>
            <section id="backmatter" data-extent="backmatter">
              <section id="references"><h2>References</h2><div class="citation-content"><a href="https://scholar.google.com/example">Google Scholar</a></div></section>
            </section>
            <section class="core-collateral-supplementary-materials"><a href="/cms/mmc1.pdf">PDF (171 KB)</a><div>Table S1. Supplementary material</div></section>
          </main>
        </body>
      </html>
    HTML

    extract_from_url('https://www.cell.com/cell-reports/fulltext/S2211-1247(26)00512-7', html) do |payload|
      markdown = payload['markdown']

      expect(payload['contentType']).to eq('article')
      expect(payload['hostAware']).to eq(true)
      expect(markdown).to include('# Spatial immune interactions in regenerating tissue')
      expect(markdown).to include('## Summary')
      expect(markdown).to include('## Introduction')
      expect(markdown).to include('macrophage-SFRP4 positive stromal interactions')
      expect(markdown).not_to include('Google Scholar')
      expect(markdown).not_to include('Table S1')
      expect(markdown).not_to include('regeneration](https://www.cell.com/action/doSearch')
    end
  end

  it 'extracts IEEE Xplore article abstracts without recommendations or account chrome' do
    html = <<~HTML
      <html>
        <head>
          <title>Real-time MTL with durations as SMT with applications to schedulability analysis | IEEE Conference Publication | IEEE Xplore</title>
          <meta property="og:site_name" content="ieeexplore.ieee.org">
        </head>
        <body>
          <main>
            <xpl-document-abstract>
              <section class="document-abstract document-tab">
                <div class="abstract-mobile-div hide-desktop">
                  <h2>Abstract:</h2>
                  <span class="abstract-text-content">This paper introduces a synthesis procedure for the satisfiability problem of RMTL- integral formulas as SAT solving modulo theories. RMTL-integral is a real-time version of metric temporal logic extended by a duration quantifier.</span>
                </div>
                <div class="u-pb-1"><span class="stats-document-abstract-publishedIn">Published in: 2020 International Symposium on Theoretical Aspects of Software Engineering (TASE)</span></div>
                <div class="u-pb-1"><span>DOI: 10.1109/TASE49443.2020.00016</span></div>
                <div class="abstract-desktop-div">
                  <h2>Abstract:</h2>
                  <span class="abstract-text-content">This paper introduces a synthesis procedure for the satisfiability problem of RMTL- integral formulas as SAT solving modulo theories. RMTL-integral is a real-time version of metric temporal logic extended by a duration quantifier allowing measurement of time durations. For any given formula, a SAT instance modulo theories is constructed and used to analyze schedulability for real-time systems.</span>
                </div>
              </section>
            </xpl-document-abstract>
            <section class="recommendations"><h2>Recommended Articles</h2><a href="/document/10992737">Application of Formal Methods in Design of Constrained Codes</a></section>
            <section class="account-menu"><a href="/articleSale/purchaseHistory.jsp">View Purchased Documents</a><a href="/profile/changeusrpwd/showChangeUsrPwdPage.html">Change username/password</a></section>
            <footer><a href="tel:+1-800-678-4333">US &amp; Canada: +1 800 678 4333</a></footer>
          </main>
        </body>
      </html>
    HTML

    extract_from_url('https://ieeexplore.ieee.org/document/9405311', html) do |payload|
      markdown = payload['markdown']

      expect(payload['contentType']).to eq('article')
      expect(payload['hostAware']).to eq(true)
      expect(markdown).to include('# Real-time MTL with durations as SMT with applications to schedulability analysis')
      expect(markdown).to include('## Abstract')
      expect(markdown).to include('quantifier allowing measurement of time durations')
      expect(markdown).to include('Published in: 2020 International Symposium')
      expect(markdown).to include('DOI: 10.1109/TASE49443.2020.00016')
      expect(markdown).not_to include('Recommended Articles')
      expect(markdown).not_to include('View Purchased Documents')
      expect(markdown).not_to include('username/password')
      expect(markdown).not_to include('US & Canada')
    end
  end

  it 'surfaces arXiv abstract details instead of sidebar tooling' do
    html = <<~HTML
      <html>
        <head>
          <title>[1706.03762] Attention Is All You Need</title>
          <meta property="og:site_name" content="arXiv.org">
        </head>
        <body>
          <main>
            <h1 class="title mathjax">Title: Attention Is All You Need</h1>
            <div class="authors"><span>Authors:</span> Ashish Vaswani, Noam Shazeer</div>
            <div class="dateline">Submitted on 12 Jun 2017</div>
            <blockquote class="abstract mathjax">
              <span class="descriptor">Abstract:</span>
              The dominant sequence transduction models are based on complex recurrent or convolutional neural networks.
            </blockquote>
          </main>
          <aside>
            <h1>Bibliographic and Citation Tools</h1>
            <h1>arXivLabs: experimental projects with community collaborators</h1>
            <p>arXivLabs is a framework that allows collaborators to develop and share new arXiv features.</p>
            <section class="cards">
              <h2><a href="/labs/a">Bibliographic Explorer</a></h2>
              <h2><a href="/labs/b">ScienceCast</a></h2>
              <h2><a href="/labs/c">Influence Flower</a></h2>
              <h2><a href="/labs/d">Smart Citations</a></h2>
              <h2><a href="/labs/e">Hugging Face</a></h2>
              <h2><a href="/labs/f">CatalyzeX Code Finder</a></h2>
            </section>
          </aside>
        </body>
      </html>
    HTML

    extract_from_url('https://arxiv.org/abs/1706.03762', html) do |payload|
      markdown = payload['markdown']

      expect(payload['contentType']).to eq('article')
      expect(markdown).to include('# Attention Is All You Need')
      expect(markdown).to include('Author: Ashish Vaswani, Noam Shazeer')
      expect(markdown).to include('The dominant sequence transduction models')
      expect(markdown).to include('Submitted on 12 Jun 2017')
      expect(markdown).not_to include('Bibliographic and Citation Tools')
      expect(markdown).not_to include('arXivLabs is a framework')
    end
  end
end
