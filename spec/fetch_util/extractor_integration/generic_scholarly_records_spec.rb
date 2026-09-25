# frozen_string_literal: true

RSpec.describe 'FetchUtil generic scholarly record extraction' do
  include_context 'extractor integration helpers'

  def generic_scholarly_probe_source
    root = File.expand_path('../../..', __dir__)
    source = File.readlines(File.join(root, 'websieve/manifest.txt'), chomp: true)
                 .reject { |line| line.empty? || line.start_with?('#') }
                 .map { |path| File.read(File.join(root, 'websieve', path)) }.join("\n")
    source.sub('})(window);', <<~JAVASCRIPT)
      global.probeGenericScholarlyRecord = function() {
        return genericScholarlyArticleContent(collectMetadata());
      };
      })(window);
    JAVASCRIPT
  end

  def extract_generic_record(html, url: 'https://journal.example.test/article')
    with_url_page(url, html) do |page|
      page.add_script_tag(content: generic_scholarly_probe_source)
      page.evaluate('probeGenericScholarlyRecord()')
    end
  end

  it 'extracts a neutral-host full article and retains owned bibliography links' do
    prose = 'The experiment compares repeated measurements across controlled conditions and reports the complete observed outcome. '
    html = <<~HTML
      <html><head><title>Measured outcomes</title>
        <meta name="citation_title" content="Measured outcomes">
        <meta name="citation_doi" content="10.5555/record.1">
      </head><body>
        <article itemscope itemtype="https://schema.org/ScholarlyArticle">
          <h1 itemprop="headline">Measured outcomes</h1>
          <div itemprop="author">Rae Author</div>
          <section role="doc-abstract"><h2>Abstract</h2><p>#{prose * 2}</p></section>
          <section itemprop="articleBody">
            <section id="sec-introduction"><h2>Introduction</h2><p>#{prose * 3}</p></section>
            <section id="sec-results"><h2>Results</h2><p>#{prose * 3}</p></section>
          </section>
          <section role="doc-bibliography"><h2>References</h2>
            <ol><li role="doc-biblioentry">Source record <a href="https://doi.org/10.5555/source">10.5555/source</a></li></ol>
          </section>
          <div class="citation-tools">Export citation</div>
        </article>
        <aside>Unrelated recommendation</aside>
      </body></html>
    HTML

    payload = extract_generic_record(html)
    extracted_html = payload.fetch('html')

    expect(payload.fetch('contentType')).to eq('article')
    expect(payload.fetch('hostAware')).to be(true)
    expect(payload.fetch('title')).to eq('Measured outcomes')
    expect(extracted_html).to include('Introduction', 'Results', '10.5555/source')
    expect(extracted_html).to include('href="https://doi.org/10.5555/source"')
    expect(extracted_html.scan('The experiment compares').length).to eq(8)
    expect(extracted_html.index('Introduction')).to be < extracted_html.index('Results')
    expect(extracted_html.index('Results')).to be < extracted_html.index('References')
    expect(extracted_html).not_to include('Export citation', 'Unrelated recommendation')
  end

  it 'extracts an abstract-only record with record-local authors and date without host cues' do
    prose = 'This research record reports a reproducible observation using a documented method and complete comparison. '
    html = <<~HTML
      <html><head><title>Abstract record</title></head><body>
        <main><h1>Title: Abstract record</h1>
          <div class="authors">Authors: Rae Author, Sam Researcher</div>
          <div class="dateline">Submitted on 12 June 2026</div>
          <blockquote class="abstract"><span>Abstract:</span> #{prose * 3}</blockquote>
          <div class="metatable"><dl><dt>Subjects</dt><dd>Computing; language</dd></dl>
            <a href="https://doi.org/10.5555/abstract">DOI</a>
          </div>
        </main>
        <aside><h2>Citation tools</h2><a href="/labs">Research labs</a></aside>
      </body></html>
    HTML

    payload = extract_generic_record(html)
    extracted_html = payload.fetch('html')

    expect(payload.fetch('contentType')).to eq('article')
    expect(payload.fetch('byline')).to eq('Rae Author, Sam Researcher')
    expect(payload.fetch('publishedTime')).to include('12 June 2026')
    expect(extracted_html).to include('Computing; language', 'https://doi.org/10.5555/abstract')
    expect(extracted_html).not_to include('Citation tools', 'Research labs')
  end

  it 'rejects generic prose and scholarly metadata detached from an owned abstract' do
    prose = 'This page describes public research resources and links to multiple unrelated project records. '
    html = <<~HTML
      <html><head><meta name="citation_doi" content="10.5555/detached"></head><body>
        <main><h1>Research directory</h1><section><p>#{prose * 4}</p>
          <a href="/one">Record one</a><a href="/two">Record two</a>
        </section></main>
      </body></html>
    HTML

    expect(extract_generic_record(html)).to be_nil
  end

  it 'does not promote a scholarly-looking abstract placed in recommendations' do
    prose = 'A lengthy research abstract is quoted here but does not belong to the linked scholarly article. '
    html = <<~HTML
      <html><head><meta name="citation_doi" content="10.5555/detached"></head><body>
        <main><h1>Article directory</h1><aside class="recommendations">
          <section role="doc-abstract"><h2>Abstract</h2><p>#{prose * 4}</p></section>
        </aside></main>
      </body></html>
    HTML

    expect(extract_generic_record(html)).to be_nil
  end

  it 'recognizes publisher-neutral abstract and section semantics across legacy markup shapes' do
    prose = 'The analysis reports measured outcomes, describes its controls and compares observations across the complete study. '
    plos = <<~HTML
      <html><head><title>Coastal measurements</title><meta name="citation_doi" content="10.5555/plos"></head><body>
        <main><h1>Coastal measurements</h1><div class="article-text">
          <div class="abstract toc-section"><h2>Abstract</h2><p>#{prose * 2}</p></div>
          <div id="section1" class="section toc-section"><h2>Introduction</h2><p>#{prose * 2}</p></div>
          <div id="section2" class="section toc-section"><h2>Results</h2><p>#{prose * 2}</p></div>
        </div></main></body></html>
    HTML
    plos_payload = extract_generic_record(plos)
    expect(plos_payload.fetch('html')).to include('Introduction', 'Results')

    elsevier = <<~HTML
      <html><head><title>Cellular recovery</title><meta name="citation_doi" content="10.5555/cell"></head><body>
        <article><h1>Cellular recovery</h1>
          <div id="abstracts" data-extent="frontmatter">
            <section id="author-highlights-abstract" property="abstract"><h2 property="name">Highlights</h2><p>#{prose * 2}</p></section>
            <section id="author-abstract" property="abstract"><h2 property="name">Summary</h2><p>#{prose * 3}</p></section>
          </div>
          <section id="bodymatter" property="articleBody"><section id="sec1"><h2>Discussion</h2><p>#{prose * 3}</p></section></section>
        </article></body></html>
    HTML
    elsevier_payload = extract_generic_record(elsevier)
    expect(elsevier_payload.fetch('html')).to include('Highlights', 'measured outcomes', 'Summary', 'Discussion')

    acs = <<~HTML
      <html><head><meta name="citation_title" content="Equilibrium observations">
        <meta name="citation_doi" content="10.5555/chemistry">
        <meta name="citation_journal_title" content="Methods Journal"></head><body>
        <article><h1>Equilibrium observations</h1>
          <div class="article_abstract"><h2>Abstract</h2><p>#{prose * 3}</p></div>
          <aside class="metrics">Views and recommendations</aside>
        </article></body></html>
    HTML
    acs_payload = extract_generic_record(acs)
    expect(acs_payload.fetch('html')).to include('Equilibrium observations', 'measured outcomes')
    expect(acs_payload.fetch('html')).not_to include('recommendations')
  end

  it 'extracts an abstract with local IEEE-style date and DOI evidence on a neutral host' do
    prose = 'This paper introduces a procedure and evaluates its behavior against repeated comparison cases. '
    html = <<~HTML
      <html><head><title>Temporal methods | Conference Publication | Example Archive</title>
        <meta property="og:site_name" content="example archive"></head><body>
        <main><xpl-document-abstract><section class="document-abstract">
          <div class="abstract-desktop-div"><span class="abstract-text-content">#{prose * 3}</span></div>
          <div class="stats-document-abstract-publishedIn">Published in: Example Methods Conference</div>
          <div>DOI: 10.5555/temporal</div>
        </section></xpl-document-abstract></main>
      </body></html>
    HTML

    payload = extract_generic_record(html)
    expect(payload.fetch('title')).to eq('Temporal methods')
    expect(payload.fetch('html')).to include('Published in: Example Methods Conference', 'DOI: 10.5555/temporal')
  end

  it 'keeps articleBody when it is nested in a semantic scholarly article' do
    prose = 'The analysis reports measured outcomes and compares them across complete study conditions. '
    html = <<~HTML
      <html><head><title>Nested article record</title></head><body>
        <article typeof="ScholarlyArticle"><h1>Nested article record</h1>
          <section property="abstract"><h2>Abstract</h2><p>#{prose * 2}</p></section>
          <section property="articleBody"><section id="sec-introduction"><h2>Introduction</h2><p>#{prose * 3}</p></section>
            <section id="sec-results"><h2>Results</h2><p>#{prose * 3}</p></section></section>
        </article>
      </body></html>
    HTML
    payload = extract_generic_record(html)
    expect(payload.fetch('html')).to include('Introduction', 'Results')
    expect(payload.fetch('html').scan('The analysis reports').length).to eq(8)
  end

  it 'rejects competing scholarly records rather than joining their fields' do
    prose = 'This separate scholarly abstract describes a method and reports complete experimental outcomes. '
    html = <<~HTML
      <html><head><meta name="citation_doi" content="10.5555/competing"></head><body>
        <main><article><h1>First paper</h1><section role="doc-abstract"><p>#{prose * 2}</p></section></article>
          <article><h1>Second paper</h1><section role="doc-abstract"><p>#{prose * 2}</p></section></article></main>
      </body></html>
    HTML
    expect(extract_generic_record(html)).to be_nil
  end

  it 'rejects ambiguous sibling semantic records sharing page-level citation metadata' do
    prose = 'This record describes an independent experiment and reports its own methods and complete outcomes. '
    html = <<~HTML
      <html><head><meta name="citation_title" content="Research collection">
        <meta name="citation_doi" content="10.5555/collection"></head><body>
        <section typeof="ScholarlyArticle"><h1>First record</h1>
          <section role="doc-abstract"><p>#{prose * 3}</p></section>
          <section property="articleBody"><p>#{prose * 4}</p></section>
          <section role="doc-bibliography"><h2>References</h2></section>
        </section>
        <section typeof="ScholarlyArticle"><h1>Second record</h1>
          <section role="doc-abstract"><p>#{prose * 3}</p></section>
          <section property="articleBody"><p>#{prose * 4}</p></section>
          <section role="doc-bibliography"><h2>References</h2></section>
        </section>
      </body></html>
    HTML
    expect(extract_generic_record(html)).to be_nil
  end

  it 'sanitizes visibility-pruned records while retaining source editorial media' do
    prose = 'The study reports complete evidence across repeated observations and explains how each control supports its conclusion. '
    html = <<~HTML
      <html><head><title>Editorial media study</title></head><body>
        <article typeof="ScholarlyArticle"><h1>Editorial media study</h1>
          <section role="doc-abstract"><p>#{prose * 2}</p></section>
          <section property="articleBody"><section id="sec-results"><h2>Results</h2><p>#{prose * 4}</p>
            <figure><img src="https://journal.example.test/images/figure-1.png" alt="Measured results across three samples">
              <figcaption>Figure 1. The measured outcomes remain stable across all three samples.</figcaption>
            </figure>
            <script>window.privateControl = 'must not survive';</script>
            <form action="/subscribe"><label>Email<input name="email"></label><button>Subscribe</button></form>
          </section></section>
        </article>
      </body></html>
    HTML
    payload = extract_generic_record(html)
    extracted_html = payload.fetch('html')

    expect(extracted_html).to include('Measured results across three samples', 'Figure 1. The measured outcomes')
    expect(extracted_html).to include('https://journal.example.test/images/figure-1.png')
    expect(extracted_html).not_to include('privateControl', '<script', '<form', '<input', '<button', 'Subscribe')
  end

  it 'does not borrow a body following an independently owned abstract' do
    abstract = 'This abstract summarizes a bounded research question and its complete experimental observations. '
    unrelated = 'This unrelated article body discusses another study, independent methods and separate outcomes. '
    html = <<~HTML
      <html><head><meta name="citation_doi" content="10.5555/owner"></head><body>
        <main><article><h1>Owned abstract record</h1><section role="doc-abstract"><p>#{abstract * 3}</p></section></article>
          <section id="sec-unrelated"><h2>Different record</h2><p>#{unrelated * 8}</p></section></main>
      </body></html>
    HTML
    payload = extract_generic_record(html)
    expect(payload.fetch('html')).to include('Owned abstract record')
    expect(payload.fetch('html')).not_to include('Different record', 'unrelated article body')
  end

  it 'rejects hidden abstract, body, and headline nodes and stale recommendation records' do
    prose = 'This abstract reports complete observations with enough explanatory prose to identify a scholarly record. '
    hidden_body = "<article><h1>Visible title</h1><section role='doc-abstract'><p>#{prose * 3}</p></section>" \
      "<section property='articleBody' style='display:none'><p>#{prose * 8}</p></section></article>"
    [
      "<article><h1>Visible title</h1><section role='doc-abstract' style='display:none'><p>#{prose * 3}</p></section></article>",
      hidden_body,
      "<article><h1 style='display:none'>Hidden title</h1><section role='doc-abstract'><p>#{prose * 3}</p></section></article>",
      "<main><h1>Stale article title</h1><aside class='recommendations'><article><section role='doc-abstract'><p>#{prose * 3}</p></section></article></aside></main>"
    ].each do |record|
      html = "<html><head></head><body>#{record}</body></html>"
      expect(extract_generic_record(html)).to be_nil
    end
  end

  it 'preserves the checked-in excerpt of archived arXiv record metadata, links, and history' do
    fixture = File.expand_path('../fixtures/academic/arxiv_1706_03762_record.html', __dir__)
    html = File.read(fixture)
    payload = extract_generic_record(html, url: 'https://arxiv.org/abs/1706.03762')
    extracted_html = payload.fetch('html')

    expect(payload.fetch('title')).to eq('Attention Is All You Need')
    expect(payload.fetch('contentType')).to eq('article')
    expect(payload.fetch('hostAware')).to be(true)
    expect(payload.fetch('byline')).to include('Ashish Vaswani', 'Illia Polosukhin')
    expect(payload.fetch('publishedTime')).to include('Submitted on 12 Jun 2017', 'last revised 2 Aug 2023')
    expect(payload.fetch('excerpt')).to include('dominant sequence transduction models')
    expect(payload.fetch('excerpt')).not_to include('view email')
    expect(extracted_html).to include('Computation and Language (cs.CL)', '15 pages, 5 figures')
    expect(extracted_html).to include('href="https://arxiv.org/abs/1706.03762v1"', 'submission-history')
    expect(extracted_html).to include('href="https://arxiv.org/html/1706.03762v7"', 'href="https://arxiv.org/src/1706.03762"')
    expect(extracted_html).to include('href="https://arxiv.org/pdf/1706.03762"', 'Rights to this article')
    expect(extracted_html.scan('Ashish Vaswani').length).to eq(1)
    expect(extracted_html.scan('15 pages, 5 figures').length).to eq(1)
    expect(payload.fetch('excerpt').length).to be > 280
    expect(payload.fetch('excerpt')).to end_with('The Transformer generalizes well to English constituency parsing with large and limited training data.')
    expect(extracted_html).not_to include('Bibliographic and Citation Tools', 'Connected Papers', 'Recommended papers')
  end
end
