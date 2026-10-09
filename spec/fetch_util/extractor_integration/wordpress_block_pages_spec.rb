# frozen_string_literal: true

RSpec.describe 'FetchUtil WordPress block page ownership' do
  include_context 'extractor integration helpers'

  def block_page(main)
    <<~HTML
      <html><head><title>Casey's studio</title><meta name="generator" content="WordPress"></head>
      <body class="page wp-theme-example"><div class="wp-site-blocks">#{main}</div></body></html>
    HTML
  end

  def introduction
    <<~HTML
      <div class="entry-content">
        <p>I build accessible websites and publish open-source tools for independent organizations.</p>
        <p>My work combines careful research, inclusive design, and maintainable software. Each project
        documents its decisions so that the people using it can understand and improve the result.</p>
      </div>
    HTML
  end

  it 'retains sibling work and dated updates along with the complete page introduction' do
    updates = (1..6).map do |index|
      <<~HTML
        <li class="wp-block-post"><h3><a href="/journal/#{index}">Studio update #{index}</a></h3>
        <time datetime="2026-09-0#{index}">September #{index}, 2026</time>
        <p>Project #{index} explains a different practical lesson from our work.</p></li>
      HTML
    end.join
    html = block_page(<<~HTML)
      <main><h1>Casey's studio</h1>#{introduction}
        <section><h2>Selected clients</h2><ul><li><a href="/clients/library">Community Library</a></li>
        <li><a href="/clients/archive">Public Archive</a></li></ul></section>
        <section><h2>Latest journal</h2><ul class="wp-block-post-template">#{updates}</ul></section>
        <aside><p>Unrelated sidebar promotion</p></aside>
      </main><footer>Unrelated footer navigation</footer>
    HTML

    with_url_page('https://studio.example/', html) do |page|
      before = page.evaluate('document.body.innerHTML')
      payload = extract_payload(page)
      expect(payload.fetch('markdown')).to include('I build accessible websites', 'Selected clients', 'Latest journal')
      %w[library archive].each do |client|
        expect(payload.fetch('markdown')).to include("https://studio.example/clients/#{client}")
      end
      positions = (1..6).flat_map do |index|
        values = ["Studio update #{index}", "September #{index}, 2026", "Project #{index} explains"]
        values.map do |value|
          expect(payload.fetch('markdown')).to include(value)
          payload.fetch('markdown').index(value)
        end
      end
      expect(positions).to eq(positions.sort)
      expect(payload['contentFormat']).to be_nil
      expect(payload.fetch('markdown')).not_to include('Unrelated sidebar promotion', 'Unrelated footer navigation')
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end

  it 'does not expand a real article into the surrounding block page' do
    html = block_page(<<~HTML)
      <main><article><h1 class="entry-title">Casey's studio</h1>#{introduction}</article>
      <section><h2>Unrelated page directory</h2><p>This sibling is outside the article owner.</p></section></main>
    HTML
    extract_from_url('https://studio.example/story', html) do |payload|
      expect(payload.fetch('markdown')).to include('I build accessible websites')
      expect(payload.fetch('markdown')).not_to include('Unrelated page directory', 'outside the article owner')
    end
  end

  it 'does not infer a whole-page owner when visible main regions compete' do
    html = block_page(<<~HTML)
      <main><h1>Casey's studio</h1>#{introduction}</main>
      <main><h1>Another publication</h1><p>Unrelated second main biography.</p></main>
    HTML
    extract_from_url('https://studio.example/', html) do |payload|
      expect(payload.fetch('markdown')).to include('I build accessible websites')
      expect(payload.fetch('markdown')).not_to include('Unrelated second main biography')
    end
  end

  it 'preserves explicit liveblog evidence on a block-theme page' do
    html = block_page(<<~HTML)
      <main><h1>Casey's studio</h1><section data-liveblog="true">#{introduction}</section></main>
    HTML
    extract_from_url('https://studio.example/', html) do |payload|
      expect(payload['contentFormat']).to eq('liveblog')
      expect(payload.fetch('markdown')).to include('I build accessible websites')
    end
  end

  it 'retains newsletter format for an authored edition on a block-theme page' do
    reports = (1..5).map do |index|
      <<~HTML
        <section><h2><a href="/reports/#{index}">Research report #{index}</a></h2>
        <p>Report #{index} describes an independently selected investigation, its findings, and the
        practical lessons that our editors considered useful for this edition.</p></section>
      HTML
    end.join
    html = block_page(<<~HTML)
      <main><h1>Research bulletin</h1><div class="entry-content">
      <p>Our editors selected these independent reports for this research bulletin.</p>#{reports}</div></main>
    HTML
    html.sub!("<title>Casey's studio</title>", '<title>Research bulletin</title>')
    extract_from_url('https://studio.example/bulletin', html) do |payload|
      expect(payload['contentFormat']).to eq('newsletter'), payload.slice('title', 'contentType', 'markdown').inspect
      (1..5).each do |index|
        expect(payload.fetch('markdown')).to include("Research report #{index}", "Report #{index} describes")
      end
    end
  end

  def page_with_declarations(nodes, extra_head: '', article_shell: false)
    html = block_page(<<~HTML)
      <main><h1>Casey's studio</h1>#{introduction}
      <section><h2>Current projects</h2><p>Our library project documents the decisions behind its accessible interface.</p>
      <article><h3>Child journal post</h3><time datetime="2026-09-08">September 8, 2026</time></article></section></main>
    HTML
    if article_shell
      html.sub!('<main><h1>', '<main><article><h1>')
      html.sub!('</section></main>', '</section></article></main>')
    end
    declarations = JSON.generate('@context' => 'https://schema.org', '@graph' => nodes)
    html.sub('</head>', "#{extra_head}<script type='application/ld+json'>#{declarations}</script></head>")
  end

  it 'retains an identity-bound page publication date without borrowing a child post date' do
    page_node = { '@type' => 'WebPage', 'url' => 'https://studio.example/', 'name' => "Casey's studio",
                  'datePublished' => '2025-04-09T11:34:04-07:00', 'dateModified' => '2026-09-23T11:45:34-07:00' }
    child = { '@type' => 'BlogPosting', 'url' => 'https://studio.example/journal/child',
              'datePublished' => '2026-09-08T09:00:00Z' }
    [false, true].each do |article_shell|
      with_url_page('https://studio.example/', page_with_declarations([page_node], article_shell: article_shell)) do |page|
        before = page.evaluate('document.body.innerHTML')
        source_declaration = page.evaluate("document.querySelector('script[type=\"application/ld+json\"]').textContent")
        payload = extract_payload(page)
        expect(Time.iso8601(payload.fetch('publishedTime'))).to eq(Time.iso8601(page_node.fetch('datePublished')))
        expect(payload.fetch('markdown')).to include('I build accessible websites')
        expect(page.evaluate('document.body.innerHTML')).to eq(before)
        expect(page.evaluate("document.querySelector('script[type=\"application/ld+json\"]').textContent")).to eq(source_declaration)
      end
    end
    explicit_head = '<meta property="article:published_time" content="2026-08-12T07:00:00Z">'
    extract_from_url('https://studio.example/', page_with_declarations([page_node, child], extra_head: explicit_head)) do |payload|
      expect(payload.fetch('publishedTime')).to eq('2026-08-12T07:00:00Z')
      expect(payload.fetch('markdown')).to include('Current projects')
    end
    docs_html = page_with_declarations([page_node], article_shell: true).gsub("Casey's studio", 'Docker sandbox guide')
    extract_from_url('https://studio.example/', docs_html) do |payload|
      expect(Time.iso8601(payload.fetch('publishedTime'))).to eq(Time.iso8601(page_node.fetch('datePublished')))
      expect(payload.fetch('markdown')).to include('I build accessible websites')
    end
  end

  it 'declines foreign, conflicting, ambiguous, absent or malformed page publication declarations' do
    valid = { '@type' => 'WebPage', 'url' => 'https://studio.example/', 'name' => "Casey's studio",
              'datePublished' => '2025-04-09T11:34:04-07:00' }
    declarations = [
      [valid.merge('url' => 'https://other.example/')],
      [valid.merge('name' => 'Unrelated publication')],
      [valid, valid.merge('datePublished' => '2025-07-01T12:00:00Z')],
      [valid.reject { |key, _| key == 'datePublished' }.merge('dateModified' => '2026-09-23T11:45:34-07:00')],
      [valid.merge('datePublished' => 'yesterday')]
    ]
    declarations.each do |nodes|
      extract_from_url('https://studio.example/', page_with_declarations(nodes)) do |payload|
        expect(payload['publishedTime']).to be_nil
        expect(payload.fetch('markdown')).to include('I build accessible websites', 'Current projects', 'September 8, 2026')
      end
    end
  end
end
