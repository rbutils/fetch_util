# frozen_string_literal: true

require 'nokogiri'

RSpec.describe 'FetchUtil static CMS homepage ownership' do
  include_context 'extractor integration helpers'

  def static_homepage(multiple_headings: false)
    sections = (1..6).map do |index|
      tag = multiple_headings ? 'h1' : 'h2'
      <<~HTML
        <section><#{tag}>Public section #{index}</#{tag}>
        <p>Section #{index} explains our independent public work and the practical resources that readers can use.</p>
        <a href="/resources/#{index}">Resource #{index}</a></section>
      HTML
    end.join
    posts = (1..6).map do |index|
      <<~HTML
        <article class="post type-post"><h2><a href="/journal/#{index}">Foreign journal title #{index}</a></h2>
        <time datetime="2026-09-0#{index}T12:0#{index}:00Z">September #{index}, 2026</time>
        <p>Journal #{index} reports a separate investigation, with its own evidence and observations.</p></article>
      HTML
    end.join
    <<~HTML
      <html><head><title>Independent public studio</title><meta name="generator" content="WordPress">
      <link rel="canonical" href="https://studio.example.test/"><meta property="og:type" content="website"></head>
      <body class="home page"><header>Site navigation</header>
      <div class="site-shell"><a href="/"><img src="/logo.png" alt="Studio"></a>
      <button aria-controls="site-links">Menu</button><div id="site-links">
      <a href="/one">One</a><a href="/two">Two</a></div><p><a href="/login">Login</a></p></div>
      <main><article class="page type-page">
      <div class="entry-content"><h1>Our public work</h1><p>Our newsletter archive is part of our independent reporting,
      and this introduction explains the whole studio rather than any linked journal entry.</p>
      #{sections}<section><h2>Journal and community</h2>#{posts}</section>
      <pre><code>keep_complete_program();\nkeep_all_values();</code></pre></div></article></main>
      <footer>Site footer navigation</footer></body></html>
    HTML
  end

  it 'keeps the whole static homepage instead of borrowing an embedded post identity' do
    [false, true].each do |multiple|
      with_url_page('https://studio.example.test/', static_homepage(multiple_headings: multiple)) do |page|
        before = page.evaluate('document.body.innerHTML')
        payload = extract_payload(page)
        expect(payload.fetch('title')).to eq('Independent public studio')
        expect(payload['contentFormat']).to be_nil
        expect(payload['byline']).to be_nil
        expect(payload['publishedTime']).to be_nil
        document = Nokogiri::HTML5.fragment(payload.fetch('html'))
        expect(document.css('p').length).to eq(13)
        expect(payload.fetch('markdown')).to include('Our newsletter archive', 'keep_complete_program();', 'keep_all_values();')
        positions = (1..6).map do |index|
          expect(payload.fetch('markdown')).to include("https://studio.example.test/resources/#{index}",
                                                       "https://studio.example.test/journal/#{index}")
          payload.fetch('markdown').index("Public section #{index}")
        end
        expect(positions).to eq(positions.sort)
        expect(page.evaluate('document.body.innerHTML')).to eq(before)
      end
    end
  end

  it 'keeps complete split headings and prose-first list items without changing genuine programs' do
    html = static_homepage.sub('<h1>Our public work</h1>', '<h1>Our<br><em>public</em> work</h1>')
    html = html.sub('</pre>', <<~HTML)
      </pre><ul><li><div> \n </div><p>Complete first item and its independent source.</p>
      <p><a href="/complete-item">Follow the source</a></p></li>
      <li><pre><code>  keep_indented_value();\nkeep_second_line();</code></pre></li></ul>
    HTML
    extract_from_url('https://studio.example.test/', html) do |payload|
      markdown = payload.fetch('markdown')
      expect(markdown).to match(/^# Our (?:_public_|\*public\*) work$/)
      expect(markdown).to include('-   Complete first item and its independent source.',
                                  '[Follow the source](https://studio.example.test/complete-item)',
                                  '  keep_indented_value();', 'keep_second_line();',
                                  'keep_complete_program();', 'keep_all_values();')
      expect(payload.fetch('html')).to include('<br>', '<em>public</em>')
    end
  end

  it 'retains a separately identity-bound page publication without borrowing child dates' do
    node = { '@context' => 'https://schema.org', '@type' => 'WebPage', 'url' => 'https://studio.example.test/',
             'name' => 'Independent public studio', 'datePublished' => '2025-04-09T11:34:04Z' }
    html = static_homepage.sub('</head>', "<script type='application/ld+json'>#{JSON.generate(node)}</script></head>")
    extract_from_url('https://studio.example.test/', html) do |payload|
      expect(payload.fetch('title')).to eq('Independent public studio')
      expect(payload.fetch('publishedTime')).to eq(node.fetch('datePublished'))
    end
  end

  def homepage_context_probe
    directory = File.expand_path('../../../websieve', __dir__)
    script = File.readlines(File.join(directory, 'manifest.txt'), chomp: true)
                 .reject { |line| line.empty? || line.start_with?('#') }
                 .map { |line| File.read(File.join(directory, line)) }.join("\n")
    raise 'unexpected extraction boundary' unless script.scan('})(window);').length == 1

    script.sub('})(window);', <<~JS)
      global.staticHomepageProof = function() { return !!wordpressHomepageContext({title: document.title}); };
      })(window);
    JS
  end

  it 'declines foreign, ambiguous, post-owned, controlled and competing pages and refreshes the proof' do
    with_url_page('https://studio.example.test/', static_homepage) do |page|
      page.evaluate(homepage_context_probe)
      body = page.evaluate('document.body.innerHTML')
      body_class = page.evaluate('document.body.className')
      expect(page.evaluate('window.staticHomepageProof()')).to be(true)
      mutations = [
        "document.body.classList.remove('home')",
        "document.querySelector('link[rel=canonical]').href = 'https://foreign.example.test/'",
        "document.body.insertAdjacentHTML('beforeend', '<div class=entry-content><h1>Competing</h1><p>Other owner.</p></div>')",
        "document.querySelector('main > article').className = 'post type-post'",
        "document.querySelector('.entry-content').insertAdjacentHTML('beforeend', '<form><input></form>')",
        "document.body.insertAdjacentHTML('beforeend', '<p>Independent outside reporting belongs to another source owner.</p>')",
        "document.querySelector('meta[property=\"og:type\"]').content = 'article'",
        "document.querySelector('.site-shell').insertAdjacentHTML('beforeend', " \
          "'<p>This independently authored report explains a separate investigation and its complete findings.</p>')"
      ]
      mutations.each do |mutation|
        page.evaluate(mutation)
        expect(page.evaluate('window.staticHomepageProof()')).to be(false), mutation
        page.evaluate('document.body.innerHTML = arguments[0]', body)
        page.evaluate('document.body.className = arguments[0]', body_class)
        page.evaluate("document.querySelector('link[rel=canonical]').href = 'https://studio.example.test/'")
        page.evaluate("document.querySelector('meta[property=\"og:type\"]').content = 'website'")
        expect(page.evaluate('window.staticHomepageProof()')).to be(true), mutation
      end
      expect(page.evaluate('document.body.innerHTML')).to eq(body)
    end
  end
end
