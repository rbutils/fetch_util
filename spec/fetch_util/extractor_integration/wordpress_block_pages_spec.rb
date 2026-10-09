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
end
