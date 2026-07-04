# frozen_string_literal: true

RSpec.describe 'FetchUtil scientific record extraction' do
  include_context 'extractor integration helpers'

  it 'extracts NCBI Gene records as articles from the record report root' do
    html = <<~HTML
      <html>
        <head>
          <title>EGFR epidermal growth factor receptor [Homo sapiens (human)] - Gene - NCBI</title>
          <meta name="ncbi_db" content="gene">
          <meta property="og:site_name" content="NCBI">
        </head>
        <body>
          <aside class="facet_cont"><a href="#">Protein-coding</a><a href="#">Current</a></aside>
          <div class="rprt full-rprt">
            <div class="rprt-header">
              <h1 class="title" id="gene-name"><span class="gn">EGFR</span> epidermal growth factor receptor [<em class="tax">Homo sapiens</em> (human)]</h1>
              <span class="geneid">Gene ID: 1956, updated on 16-Jun-2026</span>
            </div>
            <div class="download-datasets"><a href="#">Download Datasets</a></div>
            <div class="rprt-body">
              <section class="rprt-section gene-summary" data-section="summary">
                <div class="rprt-section-header" id="summary">
                  <h2 id="header-summary"><a href="#"><span class="ui-ncbitoggler-master-text">Summary</span></a></h2>
                  <div class="rprt-section-tools"><a href="#top" class="gene-top-page">Go to the top of the page</a><a class="gene-section-help" href="/books/NBK3841/#EntrezGene.Summary_2">Help</a></div>
                </div>
                <div class="rprt-section-body">
                  <dl id="summaryDl">
                    <dt>Official Symbol</dt><dd>EGFR<span class="prov">provided by <a href="https://www.genenames.org/">HGNC</a></span></dd>
                    <dt>Official Full Name</dt><dd>epidermal growth factor receptor<span class="prov">provided by <a href="https://www.genenames.org/">HGNC</a></span></dd>
                    <dt>Gene type</dt><dd>protein coding</dd>
                    <dt>Organism</dt><dd><a href="/Taxonomy/Browser/wwwtax.cgi?id=9606">Homo sapiens</a></dd>
                    <dt>Summary</dt><dd>The protein encoded by this gene is a transmembrane glycoprotein and receptor for members of the epidermal growth factor family.</dd>
                    <dt>Expression</dt><dd>Broad expression in placenta, skin and 22 other tissues <a href="#gene-expression">See more</a></dd>
                    <dt></dt><dd><strong>Try the new <a href="/datasets/gene/1956/">Gene page</a></strong></dd>
                  </dl>
                </div>
              </section>
              <section class="rprt-section gene-genomic-context" data-section="genomic-context">
                <div class="rprt-section-header" id="genomic-context"><h2><a href="#"><span class="ui-ncbitoggler-master-text">Genomic context</span></a></h2></div>
                <div class="rprt-section-body">
                  <dl class="dl-chr-info"><dt>Location:</dt><dd>7p11.2</dd><dt>Exon count:</dt><dd>32</dd></dl>
                  <table class="jig-ncbigrid"><thead><tr><th>Assembly</th><th>Chr</th><th>Location</th></tr></thead><tbody><tr><td>GRCh38.p14</td><td>7</td><td>NC_000007.14 (55019017..55211628)</td></tr></tbody></table>
                </div>
              </section>
              <section class="rprt-section gene-gene-expression" data-section="gene-expression">
                <div class="rprt-section-header" id="gene-expression"><h2><a href="#"><span class="ui-ncbitoggler-master-text">Expression</span></a></h2></div>
                <div class="rprt-section-body"><ul id="project-summary"><li id="project-summary-title">Project title: Tissue-specific circular RNA induction during human fetal development</li><li id="project-summary-bioprojects">BioProject: <a href="/bioproject/PRJNA270632/">PRJNA270632</a></li></ul></div>
              </section>
              <section class="rprt-section gene-interactions" data-section="interactions">
                <div class="rprt-section-header" id="interactions"><h2><a href="#"><span class="ui-ncbitoggler-master-text">Interactions</span></a></h2></div>
                <div class="rprt-section-body"><table summary="Gene Interaction"><thead><tr><th>Products</th><th>Interactant</th><th>Description</th></tr></thead><tbody><tr><td>EGFR</td><td>ERBB2</td><td>EGFR and ERBB2 form heterodimers in signaling complexes.</td></tr></tbody></table></div>
              </section>
            </div>
          </div>
        </body>
      </html>
    HTML

    extract_from_url('https://www.ncbi.nlm.nih.gov/gene/1956', html) do |payload|
      markdown = payload['markdown']

      expect(payload['contentType']).to eq('article')
      expect(payload['hostAware']).to eq(true)
      expect(markdown).to start_with('# EGFR epidermal growth factor receptor')
      expect(markdown).to include('Official Symbol')
      expect(markdown).to include('The protein encoded by this gene is a transmembrane glycoprotein')
      expect(markdown).to include('Genomic context')
      expect(markdown).to include('NC_000007.14 (55019017..55211628)')
      expect(markdown).to include('Expression')
      expect(markdown).to include('Tissue-specific circular RNA induction')
      expect(markdown).to include('Interactions')
      expect(markdown).to include('EGFR and ERBB2 form heterodimers')
      expect(markdown).not_to start_with('- [')
      expect(markdown.scan('Official Symbol').length).to eq(1)
      expect(markdown).not_to include('Download Datasets')
      expect(markdown).not_to include('Go to the top of the page')
    end
  end

  it 'extracts OEIS sequence records in canonical section order' do
    html = <<~HTML
      <html>
        <head>
          <title>A000045 - OEIS</title>
          <meta property="og:site_name" content="OEIS">
        </head>
        <body>
          <header><a href="/search">Search</a><a href="/login">login</a></header>
          <main>
            <div class="seqhead">
              <div class="seqnumname">
                <div class="seqnum">A000045</div>
                <div class="seqname">Fibonacci numbers: F(n) = F(n-1) + F(n-2) with F(0) = 0 and F(1) = 1.<br><font size="-1">(Formerly M0692 N0256)</font></div>
              </div>
            </div>
            <div class="seqdatabox">
              <div class="seqdata">0, 1, 1, 2, 3, 5, 8, 13, 21, 34, 55, 89</div>
              <div class="seqdatalinks"><a href="/A000045/list">list</a><a href="/A000045/graph">graph</a></div>
            </div>
            <div class="entry">
              <div class="section"><div class="sectname">OFFSET</div><div class="sectbody"><div class="sectline">0,4</div></div></div>
              <div class="section"><div class="sectname">COMMENTS</div><div class="sectbody"><div class="sectline">F(n+2) = number of binary sequences of length n that have no consecutive 0's.</div></div></div>
              <div class="section"><div class="sectname">REFERENCES</div><div class="sectbody"><div class="sectline">D. E. Knuth, The Art of Computer Programming, Vol. 1, p. 78.</div></div></div>
              <div class="section"><div class="sectname">FORMULA</div><div class="sectbody"><div class="sectline">a(n) = a(n-1) + a(n-2) for n &gt;= 2.</div></div></div>
              <div class="section"><div class="sectname">EXAMPLE</div><div class="sectbody"><div class="sectline">a(5) = 5 because 5 = 3 + 2.</div></div></div>
              <div class="section"><div class="sectname">MAPLE</div><div class="sectbody"><div class="sectline">A000045 := proc(n) combinat[fibonacci](n); end;</div></div></div>
            </div>
          </main>
        </body>
      </html>
    HTML

    extract_from_url('https://oeis.org/A000045', html) do |payload|
      markdown = payload['markdown']

      expect(payload['contentType']).to eq('article')
      expect(payload['hostAware']).to eq(true)
      expect(markdown).to start_with('# A000045 - Fibonacci numbers')
      expect(markdown).to include('## Terms')
      expect(markdown).to include('0, 1, 1, 2, 3, 5, 8')
      expect(markdown.index('## Sequence comments')).to be < markdown.index('## Formula')
      expect(markdown.index('## Formula')).to be < markdown.index('## Example')
      expect(markdown.index('## Example')).to be < markdown.index('## References')
      expect(markdown).to include('a(n) = a(n-1) + a(n-2)')
      expect(markdown).to include('a(5) = 5 because 5 = 3 + 2')
      expect(markdown).not_to include('A000045 := proc')
      expect(markdown).not_to include('login')
    end
  end

  it 'extracts RCSB PDB structure metadata before citations' do
    html = <<~HTML
      <html>
        <head>
          <title>RCSB PDB - 1A0J</title>
          <meta property="og:site_name" content="RCSB PDB">
        </head>
        <body>
          <main id="maincontentcontainer">
            <section id="summary">
              <h1><span id="structureID">&nbsp;1A0J </span><span>|</span><span>pdb_00001a0j</span></h1>
              <h4><span id="structureTitle">CRYSTAL STRUCTURE OF A NON-PSYCHROPHILIC TRYPSIN FROM A COLD-ADAPTED FISH SPECIES.</span></h4>
              <ul>
                <li id="header_classification"><strong>Classification:&nbsp;</strong><a href="/search">SERINE PROTEASE</a></li>
                <li id="header_organism"><strong>Organism(s):&nbsp;</strong><a href="/search">Salmo salar</a></li>
                <li><strong>Deposited:&nbsp;</strong>1997-12-01&nbsp;</li>
                <li><strong>Released:&nbsp;</strong>1999-01-13&nbsp;</li>
              </ul>
              <section id="primarycitation">
                <h2>Primary Citation</h2>
                <p>Structure of a non-psychrophilic trypsin from a cold-adapted fish species.</p>
                <p>(1998) Acta Crystallogr D Biol Crystallogr 54: 780-798</p>
                <p>PubMed Abstract: The crystal structure of cationic trypsin from Atlantic salmon has been refined at 1.70 A resolution.</p>
              </section>
              <section id="experimentaldatabottom">
                <h2>Experimental Data</h2>
                <p><strong>Method:&nbsp;</strong>X-RAY DIFFRACTION</p>
                <p><strong>Resolution:&nbsp;</strong>1.70 Å</p>
                <p><strong>R-Value Free:&nbsp;</strong>0.215</p>
              </section>
              <section id="ligands"><h2>Ligands&nbsp; 3 Unique</h2><p>BEN BENZAMIDINE; SO4 SULFATE ION; CA CALCIUM ION</p></section>
            </section>
            <aside>Clicking the button will open your email app with your feedback details already filled in.</aside>
          </main>
        </body>
      </html>
    HTML

    extract_from_url('https://www.rcsb.org/structure/1A0J', html) do |payload|
      markdown = payload['markdown']

      expect(payload['contentType']).to eq('article')
      expect(payload['hostAware']).to eq(true)
      expect(markdown).to start_with('# 1A0J - CRYSTAL STRUCTURE OF A NON-PSYCHROPHILIC TRYPSIN')
      expect(markdown).to include('- PDB ID: 1A0J')
      expect(markdown).to include('- SERINE PROTEASE')
      expect(markdown).to include('- Salmo salar')
      expect(markdown).to include('- X-RAY DIFFRACTION')
      expect(markdown).to include('- 1.70 Å')
      expect(markdown.index('PDB ID: 1A0J')).to be < markdown.index('Primary citation:')
      expect(markdown).to include('Structure of a non-psychrophilic trypsin')
      expect(markdown).not_to start_with('(1998) Acta')
      expect(markdown).not_to include('Clicking the button')
    end
  end

  it 'extracts NIST WebBook compound data before related data links' do
    html = <<~HTML
      <html>
        <head>
          <title>Water</title>
          <meta property="og:site_name" content="NIST Chemistry WebBook">
        </head>
        <body>
          <header><h1>NIST Chemistry WebBook</h1><nav><a href="/chemistry/">Search</a></nav></header>
          <main id="main">
            <h1 id="Top">Water</h1>
            <ul>
              <li><strong><a href="http://goldbook.iupac.org/E02063.html">Formula</a>:</strong> H<sub>2</sub>O</li>
              <li><strong><a href="http://goldbook.iupac.org/R05271.html">Molecular weight</a>:</strong> 18.0153</li>
              <li><strong>IUPAC Standard InChI:</strong> <span class="inchi-text">InChI=1S/H2O/h1H2</span><button class="copy-prior-text">Copy</button></li>
              <li><strong>IUPAC Standard InChIKey:</strong> <span class="inchi-text">XLYOFNOQVPJJNP-UHFFFAOYSA-N</span></li>
              <li><strong>CAS Registry Number:</strong> 7732-18-5</li>
              <li><strong>Chemical structure:</strong> <img src="/cgi/cbook.cgi?Struct=C7732185&amp;Type=Color" alt="H2O"> View 3d structure</li>
              <li><strong>Other names:</strong> Water vapor; Distilled water; Ice; H2O; Dihydrogen oxide; steam</li>
              <li><strong>Other data available:</strong>
                <ul>
                  <li><a href="/cgi/cbook.cgi?ID=C7732185&amp;Mask=1#Thermo-Gas">Gas phase thermochemistry data</a></li>
                  <li><a href="/cgi/cbook.cgi?ID=C7732185&amp;Mask=2#Thermo-Condensed">Condensed phase thermochemistry data</a></li>
                </ul>
              </li>
            </ul>
            <h2>Data at NIST subscription sites:</h2>
            <ul><li><a href="https://wtt-pro.nist.gov/">NIST / TRC Web Thermo Tables</a></li></ul>
          </main>
        </body>
      </html>
    HTML

    extract_from_url('https://webbook.nist.gov/cgi/cbook.cgi?ID=C7732185', html) do |payload|
      markdown = payload['markdown']

      expect(payload['contentType']).to eq('article')
      expect(payload['hostAware']).to eq(true)
      expect(markdown).to start_with('# Water')
      expect(markdown).to include('Formula')
      expect(markdown).to include('H2O')
      expect(markdown).to include('Molecular weight')
      expect(markdown).to include('18.0153')
      expect(markdown).to include('CAS Registry Number')
      expect(markdown).to include('7732-18-5')
      expect(markdown.index('Formula')).to be < markdown.index('Data at NIST subscription sites')
      expect(markdown).to include('Gas phase thermochemistry data')
      expect(markdown).not_to include('View 3d structure')
      expect(markdown).not_to include('Copy')
    end
  end
end
