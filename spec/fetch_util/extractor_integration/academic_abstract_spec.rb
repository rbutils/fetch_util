# frozen_string_literal: true

RSpec.describe 'FetchUtil academic abstract extraction' do
  include_context 'extractor integration helpers'

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
