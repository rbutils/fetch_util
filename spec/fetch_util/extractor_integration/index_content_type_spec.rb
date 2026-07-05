# frozen_string_literal: true

RSpec.describe 'FetchUtil extractor integration' do
  include_context 'extractor integration helpers'

  it 'classifies section pages dominated by teaser cards as lists' do
    cards = (1..9).map do |i|
      <<~HTML
        <article class="css-card promo-card">
          <a href="/world/2026/jul/#{i}/diplomats-gather-for-regional-summit-#{i}">
            <img src="/images/#{i}.jpg" alt="Summit delegates #{i}">
            <h3>Diplomats gather for regional summit as leaders weigh next steps #{i}</h3>
          </a>
          <p>Brief teaser copy explains the latest development without forming a standalone article body.</p>
        </article>
      HTML
    end.join

    html = <<~HTML
      <html>
        <head><title>International news | Example Daily</title></head>
        <body>
          <main>
            <h1>International</h1>
            <section class="fc-container__body card-grid">
              #{cards}
            </section>
          </main>
        </body>
      </html>
    HTML

    extract_from_url('https://www.example.com/international', html, reader_mode: false) do |payload|
      expect(payload['contentType']).to eq('list')
      expect(payload['markdown']).to include('- [Diplomats gather for regional summit as leaders weigh next steps 1]')
      expect(payload['markdown']).to include('https://www.example.com/world/2026/jul/9/diplomats-gather-for-regional-summit-9')
    end
  end

  it 'classifies publisher section pages with prose intros and flattened article feeds as lists' do
    cards = (1..7).map do |i|
      <<~HTML
        <div class="duet--content-cards--content-card">
          <a href="/tech/#{960_000 + i}/new-device-story-#{i}">
            <img src="/images/device-#{i}.jpg" alt="Device story #{i}">
            New device story #{i} reveals a useful hardware detail for readers
          </a>
          <p>Short teaser copy explains the news item without becoming the body of a standalone article.</p>
          <p>Reporter #{i} Jul #{i}</p>
        </div>
      HTML
    end.join

    html = <<~HTML
      <html>
        <head><title>Tech - Example Publisher</title></head>
        <body>
          <main id="content">
            <h1>Tech</h1>
            <div>
              <p>The latest tech news about the world's best hardware, apps, and services. From large platform companies to tiny startups, this section explains what matters in technology daily.</p>
            </div>
            <div class="river-feed">
              #{cards}
            </div>
          </main>
        </body>
      </html>
    HTML

    extract_from_url('https://www.example.com/tech', html) do |payload|
      expect(payload['contentType']).to eq('list')
      expect(payload['markdown']).to include('- [New device story 1 reveals a useful hardware detail for readers]')
      expect(payload['markdown']).to include('https://www.example.com/tech/960007/new-device-story-7')
    end
  end

  it 'classifies thin commerce search and category pages as lists without fabricating products' do
    html = <<~HTML
      <html>
        <head><title>Search results for desk | Example Market</title></head>
        <body>
          <main>
            <h1>Search results for desk</h1>
            <section class="seo-copy">
              <p>Shop desk ideas for home offices, studios, and shared spaces. Browse styles, finishes, delivery options, and sizes from the marketplace catalog.</p>
              <p>Use filters for price, width, color, and customer ratings to narrow the category.</p>
            </section>
          </main>
        </body>
      </html>
    HTML

    extract_from_url('https://www.example.com/keyword.php?keyword=desk', html) do |payload|
      expect(payload['contentType']).to eq('list')
      expect(payload['markdown']).to include('Shop desk ideas')
    end
  end

  it 'classifies ordered highlights section pages as lists' do
    highlights = (1..5).map do |i|
      <<~HTML
        <li>
          <h3><a href="/2026/07/03/world/story-#{i}.html">World headline #{i} from a section highlights rail</a></h3>
          <p>Foreign correspondents summarized the latest development in a short teaser.</p>
        </li>
      HTML
    end.join

    html = <<~HTML
      <html>
        <head><title>World News - Example Times</title></head>
        <body>
          <main>
            <h1>World News</h1>
            <h2>Highlights</h2>
            <ol class="css-highlights">
              #{highlights}
            </ol>
          </main>
        </body>
      </html>
    HTML

    extract_from_url('https://www.example.com/section/world', html) do |payload|
      expect(payload['contentType']).to eq('list')
      expect(payload['markdown']).to include('World headline 1 from a section highlights rail')
      expect(payload['markdown']).to include('World headline 5 from a section highlights rail')
    end
  end

  it 'classifies repeated job result cards as lists' do
    cards = (1..6).map do |i|
      <<~HTML
        <li data-jobid="10095549266#{i}" data-test="jobListing">
          <div data-test="job-card-wrapper">
            <p><a data-test="job-title" href="/job-listing/ruby-developer-example-#{i}.htm?jl=10095549266#{i}">Senior Ruby Developer #{i}</a></p>
            <p>Remote</p>
            <div data-test="descSnippet">
              <p>Build and maintain Ruby services, APIs, background jobs, and production tooling for distributed product teams.</p>
              <p><b>Skills:</b> Ruby, Rails, PostgreSQL, Redis, Git</p>
            </div>
          </div>
        </li>
      HTML
    end.join

    html = <<~HTML
      <html>
        <head><title>Ruby developer jobs in United States | Example Jobs</title></head>
        <body>
          <main>
            <h1>Ruby developer jobs in United States</h1>
            <ul aria-label="Jobs List">
              #{cards}
            </ul>
          </main>
        </body>
      </html>
    HTML

    extract_from_url('https://www.example.com/Job/ruby-developer-jobs-SRCH_KO0,14.htm', html) do |payload|
      expect(payload['contentType']).to eq('list')
      expect(payload['markdown']).to include('- [Senior Ruby Developer 1]')
      expect(payload['markdown']).to include('https://www.example.com/job-listing/ruby-developer-example-6.htm?jl=100955492666')
    end
  end

  it 'classifies institutional case card indexes as lists despite long summaries' do
    cards = %w[Abd-Al-Rahman Abu-Garda Al-Hassan Al-Mahdi Al-Bashir Bemba].map do |name|
      <<~HTML
        <div class="card">
          <div class="card-header"><h3><a href="/darfur/#{name.downcase}">#{name.tr("-", " ")}</a></h3></div>
          <div class="card-body">
            <p>In ICC custody, Convicted</p>
            <p>The warrant of arrest and charges in this case were addressed by the trial chamber after extensive proceedings before the court. This summary is intentionally long enough to resemble a case record teaser rather than a short news card.</p>
            <p>Next steps: the chamber will continue to manage reparations, appeals, custody, and other case record matters.</p>
          </div>
        </div>
      HTML
    end.join

    html = <<~HTML
      <html>
        <head><title>Cases | International Criminal Court</title></head>
        <body class="cases path-cases">
          <main id="main">
            <h1>Cases</h1>
            <form class="views-exposed-form cases-exposed-search-form"><label>Filter by defendant</label></form>
            <div class="view view-case-listing">
              <h2>34 Cases</h2>
              #{cards}
            </div>
          </main>
        </body>
      </html>
    HTML

    extract_from_url('https://www.example-court.int/cases', html) do |payload|
      expect(payload['contentType']).to eq('list')
      expect(payload['markdown']).to include('Next steps: the chamber will continue to manage reparations')
    end
  end

  it 'classifies legal table-of-contents pages as lists without truncation warnings' do
    entries = (1..8).map do |i|
      <<~HTML
        <li class="LegContentsEntry">
          <p class="LegContentsItem LegClearFix">
            <span class="LegDS LegContentsNo"><a href="/ukpga/1998/42/section/#{i}">#{i}.</a></span>
            <span class="LegDS LegContentsTitle"><a href="/ukpga/1998/42/section/#{i}">Example section #{i} rights and duties.</a></span>
          </p>
        </li>
      HTML
    end.join

    html = <<~HTML
      <html>
        <head><title>Human Rights Act 1998</title></head>
        <body>
          <h1 id="pageTitle" class="pageTitle">Human Rights Act 1998</h1>
          <div class="LegSnippet" id="tocControlsAdded">
            <div class="LegContents LegClearFix">
              <ul class="tocGlobalControls"><li><a href="#" class="tocExpandAll">Collapse all -</a></li></ul>
              <ol>
                <li class="LegContentsEntry"><p class="LegContentsItem LegClearFix"><span class="LegDS LegContentsTitle"><a href="/ukpga/1998/42/introduction">Introductory Text</a></span></p></li>
                <li class="LegClearFix LegContentsPblock">
                  <p class="LegContentsTitle"><a href="/ukpga/1998/42/crossheading/introduction">Introduction</a></p>
                  <ol>#{entries}</ol>
                </li>
                <li class="LegClearFix LegContentsPblock"><p class="LegContentsTitle"><a href="/ukpga/1998/42/schedule/1">SCHEDULE 1 The Articles</a></p></li>
              </ol>
            </div>
          </div>
          <footer>Changes to legislation and print options are available from the service.</footer>
        </body>
      </html>
    HTML

    extract_from_url('https://www.legislation.gov.uk/ukpga/1998/42/contents', html) do |payload|
      expect(payload['contentType']).to eq('list')
      expect(payload['warnings']).not_to include('truncated_content')
      expect(payload['markdown']).to include('Example section 8 rights and duties')
    end
  end

  it 'keeps legislation section pages classified as articles' do
    html = <<~HTML
      <html>
        <head><title>Human Rights Act 1998</title></head>
        <body>
          <nav id="legNav">Changes to legislation</nav>
          <h1 id="pageTitle" class="pageTitle">Human Rights Act 1998</h1>
          <div id="viewLegSnippet" class="LegislationSection">
            <h2>1 The Convention Rights.U.K.</h2>
            <p>(1) In this Act "the Convention rights" means the rights and fundamental freedoms set out in Articles 2 to 12 and 14 of the Convention.</p>
            <p>(2) Those Articles are to have effect for the purposes of this Act subject to any designated derogation or reservation.</p>
            <p>(3) The Articles are set out in Schedule 1.</p>
          </div>
        </body>
      </html>
    HTML

    extract_from_url('https://www.legislation.gov.uk/ukpga/1998/42/section/1', html) do |payload|
      expect(payload['contentType']).to eq('article')
      expect(payload['markdown']).to include('The Convention Rights')
      expect(payload['markdown']).to include('designated derogation or reservation')
    end
  end

  it 'keeps substantial table-based statute text classified as an article' do
    provisions = (1..24).map do |i|
      <<~HTML
        <tr>
          <td>
            <p><a href="/annotations/#{i}">Art. #{i}º</a> A Republica Federativa Exampleira assegura direitos fundamentais, organiza os poderes publicos e estabelece deveres permanentes para a administracao democratica, inclusive quando a materia for tratada em tabelas de consolidacao normativa.</p>
            <p>#{i.even? ? "Paragrafo unico" : "Inciso I"} - Esta disposicao legal integra o texto constitucional e deve ser aplicada em harmonia com os demais principios, garantias, competencias e limitacoes previstos nesta constituicao.</p>
          </td>
        </tr>
      HTML
    end.join

    html = <<~HTML
      <html>
        <head><title>Constituicao da Republica Federativa Exampleira</title></head>
        <body>
          <table class="layout">
            <tr><td>Presidencia da Republica</td></tr>
            <tr><td>Casa Civil Subchefia para Assuntos Juridicos</td></tr>
            <tr><td><strong>PREAMBULO</strong><p>Nos, representantes do povo, promulgamos a seguinte Constituicao da Republica Federativa Exampleira.</p></td></tr>
            <tr><td><strong>TITULO I</strong><strong>Dos Principios Fundamentais</strong></td></tr>
            #{provisions}
          </table>
        </body>
      </html>
    HTML

    extract_from_url('https://www.example.gov/ccivil_03/constituicao/constituicao.htm', html) do |payload|
      expect(payload['contentType']).to eq('article')
      expect(payload['markdown']).to include('PREAMBULO')
      expect(payload['markdown']).to include('Art. 1º')
      expect(payload['markdown']).not_to include('Presidencia da Republica')
      expect(payload['markdown']).not_to start_with('- [Art. 1º')
    end
  end

  it 'keeps reference pages with prose and data tables classified as articles' do
    html = <<~HTML
      <html>
        <head><title>SI base units - BIPM</title></head>
        <body>
          <main>
            <article>
              <h1>The International System of Units (SI): Base units</h1>
              <table>
                <thead><tr><th>Base quantity</th><th>Typical symbol</th><th>Base unit</th><th>Symbol</th></tr></thead>
                <tbody>
                  <tr><td>time</td><td>t</td><td>second</td><td>s</td></tr>
                  <tr><td>length</td><td>l, x, r</td><td>metre</td><td>m</td></tr>
                  <tr><td>mass</td><td>m</td><td>kilogram</td><td>kg</td></tr>
                  <tr><td>electric current</td><td>I</td><td>ampere</td><td>A</td></tr>
                  <tr><td>thermodynamic temperature</td><td>T</td><td>kelvin</td><td>K</td></tr>
                  <tr><td>amount of substance</td><td>n</td><td>mole</td><td>mol</td></tr>
                  <tr><td>luminous intensity</td><td>Iv</td><td>candela</td><td>cd</td></tr>
                </tbody>
              </table>
              <p>All other SI units can be derived from these, by multiplying together different powers of the base units.</p>
              <p>In the 2018 revision of the SI, the definitions of four of the SI base units were changed and are based on fixed numerical values of constants.</p>
              <p>Further, the definitions of all seven base units of the SI are now uniformly expressed using the explicit-constant formulation for practical realization.</p>
            </article>
          </main>
        </body>
      </html>
    HTML

    extract_from_url('https://www.bipm.org/en/measurement-units/si-base-units', html) do |payload|
      expect(payload['contentType']).to eq('article')
      expect(payload['markdown']).to include('| time | t | second | s |')
      expect(payload['markdown']).to include('All other SI units can be derived')
      expect(payload['markdown']).to include('explicit-constant formulation')
    end
  end

  it 'keeps substantial standalone articles classified as articles' do
    paragraphs = (1..7).map do |i|
      <<~HTML
        <p>Reporters described the policy debate in detail, including interviews with officials,
        residents, and analysts. Paragraph #{i} adds context, chronology, and evidence that belongs
        to a single standalone news article rather than a section index.</p>
      HTML
    end.join

    html = <<~HTML
      <html>
        <head>
          <title>Leaders approve climate funding after marathon talks</title>
          <meta property="article:published_time" content="2026-07-03T10:00:00Z">
          <meta name="author" content="A. Reporter">
        </head>
        <body>
          <main>
            <article>
              <h1>Leaders approve climate funding after marathon talks</h1>
              #{paragraphs}
            </article>
          </main>
        </body>
      </html>
    HTML

    extract_from_url('https://www.example.com/world/2026/jul/03/leaders-approve-climate-funding', html) do |payload|
      expect(payload['contentType']).to eq('article')
      expect(payload['markdown']).to include('marathon talks')
    end
  end

  it 'keeps single job description pages classified as articles' do
    paragraphs = (1..6).map do |i|
      <<~HTML
        <p>Responsibility #{i}: maintain production Ruby services, collaborate with product managers, review pull requests, improve deployment safety, and document operational decisions for the engineering team.</p>
      HTML
    end.join

    html = <<~HTML
      <html>
        <head><title>Senior Ruby Developer | Example Company</title></head>
        <body>
          <main>
            <article>
              <h1>Senior Ruby Developer</h1>
              <p>Example Company is hiring one engineer for a platform team.</p>
              #{paragraphs}
              <h2>How to apply</h2>
              <p>Send a resume and a short note about a production system you improved.</p>
            </article>
          </main>
        </body>
      </html>
    HTML

    extract_from_url('https://www.example.com/remote-jobs/remote-senior-ruby-developer-example-company-1134395', html) do |payload|
      expect(payload['contentType']).to eq('article')
      expect(payload['markdown']).to include('Example Company is hiring one engineer')
    end
  end

  it 'keeps articles with trailing related-story lists classified as articles' do
    related = (1..8).map do |i|
      %(<li><a href="/world/related-#{i}">Related background story #{i} with a short headline</a></li>)
    end.join
    paragraphs = (1..6).map do |i|
      <<~HTML
        <p>The investigation found a consistent pattern across public records and interviews.
        Paragraph #{i} provides continuous article prose with enough detail to outweigh the related
        links that follow the story.</p>
      HTML
    end.join

    html = <<~HTML
      <html>
        <head>
          <title>Investigation reveals gaps in emergency planning</title>
          <meta property="article:published_time" content="2026-07-03T11:00:00Z">
        </head>
        <body>
          <main>
            <article>
              <h1>Investigation reveals gaps in emergency planning</h1>
              #{paragraphs}
              <aside class="related-links">
                <h2>Related stories</h2>
                <ul>#{related}</ul>
              </aside>
            </article>
          </main>
        </body>
      </html>
    HTML

    extract_from_url('https://www.example.com/news/2026/07/03/investigation-reveals-gaps', html) do |payload|
      expect(payload['contentType']).to eq('article')
      expect(payload['markdown']).to include('continuous article prose')
    end
  end

  it 'keeps section-named real articles with related links classified as articles' do
    related = (1..4).map do |i|
      %(<li><a href="/tech/#{950_000 + i}/related-background-#{i}">Related background story #{i} with context</a></li>)
    end.join
    paragraphs = (1..6).map do |i|
      <<~HTML
        <p>The product team described the launch in detail, including interviews, chronology, and evidence.
        Paragraph #{i} is continuous article prose that should outweigh the short related links below.</p>
      HTML
    end.join

    html = <<~HTML
      <html>
        <head>
          <title>New headphones show why premium audio keeps changing</title>
          <meta property="article:published_time" content="2026-07-03T12:00:00Z">
          <meta name="author" content="J. Reviewer">
        </head>
        <body>
          <main>
            <article>
              <h1>New headphones show why premium audio keeps changing</h1>
              #{paragraphs}
              <aside class="related-links">
                <h2>Related stories</h2>
                <ul>#{related}</ul>
              </aside>
            </article>
          </main>
        </body>
      </html>
    HTML

    extract_from_url('https://www.example.com/tech/new-headphones-premium-audio-review', html) do |payload|
      expect(payload['contentType']).to eq('article')
      expect(payload['markdown']).to include('continuous article prose')
    end
  end

  it 'keeps long legal judgment pages classified as articles despite citation links' do
    nav_links = (1..12).map do |i|
      %(<li><a href="/au/cases/cth/HCA/1992/#{i}.html">High Court judgment #{i}</a></li>)
    end.join
    judgment_paragraphs = (1..18).map do |i|
      <<~HTML
        <p>The High Court considered the claim by the appellant and respondent in Mabo v Queensland.
        This judgment explains the reasons for judgment, the authorities cited by counsel, and the
        relationship between native title, Crown sovereignty, and the common law. Paragraph #{i}
        records continuous judicial reasoning rather than a list of search results or an index page.</p>
      HTML
    end.join

    html = <<~HTML
      <html>
        <head><title>Mabo v Queensland (No 2) [1992] HCA 23</title></head>
        <body>
          <nav>
            <ul>#{nav_links}</ul>
          </nav>
          <main>
            <article>
              <h1>Mabo v Queensland (No 2) [1992] HCA 23</h1>
              <p><strong>HIGH COURT OF AUSTRALIA</strong></p>
              <p>MABO AND OTHERS v. QUEENSLAND (No. 2) [1992] HCA 23; (1992) 175 CLR 1</p>
              #{judgment_paragraphs}
              <p>Orders: appeal allowed. Solicitors and counsel were heard for the appellant and respondent.</p>
            </article>
          </main>
        </body>
      </html>
    HTML

    extract_from_url('https://www.example.test/cgi-bin/viewdoc/au/cases/cth/HCA/1992/23.html', html) do |payload|
      expect(payload['contentType']).to eq('article')
      expect(payload['markdown']).to include('HIGH COURT OF AUSTRALIA')
      expect(payload['markdown']).to include('continuous judicial reasoning')
    end
  end
end
