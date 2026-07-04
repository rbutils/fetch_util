# frozen_string_literal: true

RSpec.describe 'FetchUtil scientific record extraction' do
  include_context 'extractor integration helpers'

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
end
