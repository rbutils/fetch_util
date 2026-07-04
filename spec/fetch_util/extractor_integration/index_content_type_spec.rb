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
end
