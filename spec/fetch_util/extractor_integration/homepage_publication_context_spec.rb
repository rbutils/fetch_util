# frozen_string_literal: true

require 'nokogiri'

RSpec.describe 'FetchUtil source-owned homepage publication context' do
  include_context 'extractor integration helpers'

  def publication_page(note:)
    sections = (1..6).map do |index|
      <<~HTML
        <section><h2>Research section #{index}</h2>
        <p>Section #{index} describes the independent research, complete observations and public materials maintained by this publication.</p>
        <a href="/research/#{index}">Complete research #{index}</a></section>
      HTML
    end.join
    <<~HTML
      <html><head><title>Independent research publication</title><meta name="generator" content="WordPress">
      <meta property="og:type" content="website"><link rel="canonical" href="https://publication.example.test/"></head>
      <body class="home page">#{note}<header><nav><a href="/menu">Menu navigation</a></nav></header>
      <main><article id="post-21" class="page type-page"><div class="entry-content">
      <h1>Our public research</h1><p>This collection preserves every published investigation and the materials that support our independent findings.</p>
      #{sections}<pre><code>  preserve_first_value();\npreserve_second_value();</code></pre>
      </div></article></main><footer><a href="/footer">Footer navigation</a></footer></body></html>
    HTML
  end

  def published_note
    '<div class="publication-notice">In 2025 our independent newsroom closed. ' \
      '<a href="https://archive.example.test/research">Independent archive</a> is preserving every investigation and its source materials. ' \
      '<a href="https://archive.example.test/statement">Read the full preservation statement</a>.</div>'
  end

  it 'keeps complete visible flat publication prose and both independent references before the homepage body' do
    with_url_page('https://publication.example.test/', publication_page(note: published_note)) do |page|
      before = page.evaluate('document.body.innerHTML')
      payload = extract_payload(page)
      document = Nokogiri::HTML5.fragment(payload.fetch('html'))
      expect(document.text).to include('In 2025 our independent newsroom closed.', 'is preserving every investigation and its source materials.')
      expect(document.css('a[href]').map { |node| [node.text, node['href']] }).to include(
        ['Independent archive', 'https://archive.example.test/research'],
        ['Read the full preservation statement', 'https://archive.example.test/statement']
      )
      expect(payload.fetch('markdown')).to include('[Independent archive](https://archive.example.test/research)',
                                                   '[Read the full preservation statement](https://archive.example.test/statement)')
      expect(document.css('p').map(&:text)).to eq(Nokogiri::HTML5(publication_page(note: published_note)).css('main p').map(&:text))
      expect(document.css('pre').map(&:text)).to eq(["  preserve_first_value();\npreserve_second_value();"])
      expect(payload.fetch('markdown').index('In 2025 our independent newsroom closed.')).to be < payload.fetch('markdown').index('Our public research')
      (1..6).each { |index| expect(payload.fetch('markdown')).to include("https://publication.example.test/research/#{index}") }
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end

  it 'preserves independent physical occurrences rather than collapsing equal publication prose' do
    html = publication_page(note: published_note + published_note)
    extract_from_url('https://publication.example.test/', html) do |payload|
      document = Nokogiri::HTML5.fragment(payload.fetch('html'))
      expect(document.text.scan('In 2025 our independent newsroom closed.').length).to eq(2)
      expect(document.css('a[href="https://archive.example.test/research"]').length).to eq(2)
      expect(document.css('pre').map(&:text)).to eq(["  preserve_first_value();\npreserve_second_value();"])
    end
  end

  it 'keeps hidden announcements, navigation, consent controls and literal lookalikes out of recovered context' do
    hidden = published_note.sub('<div ', '<div style="display:none" ')
    navigation = "<nav>#{published_note}</nav>"
    controls = published_note.sub('</div>', '<button>Accept all</button><button>Settings</button></div>')
    literal = '<div><pre><code>Literal publication wording is not an announcement.</code></pre></div>'
    html = publication_page(note: hidden + navigation + controls + literal)
    with_url_page('https://publication.example.test/', html) do |page|
      before = page.evaluate('document.body.innerHTML')
      payload = extract_payload(page)
      expect(payload.fetch('html')).not_to include('Independent archive', 'Literal publication wording', 'Accept all')
      expect(payload.fetch('markdown')).to include('preserve_first_value();', 'preserve_second_value();', 'Research section 6')
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end

  it 'keeps the same publication context when the selected body is a linked collection fragment' do
    html = publication_page(note: published_note).sub('<h1>Our public research</h1>', '<h2>Our public research</h2>')
    (1..6).each do |index|
      html = html.sub("<h2>Research section #{index}</h2>", "<h2><a href='/research/#{index}'>Research section #{index}</a></h2>")
    end
    with_url_page('https://publication.example.test/', html) do |page|
      before = page.evaluate('document.body.innerHTML')
      payload = extract_payload(page)
      document = Nokogiri::HTML5.fragment(payload.fetch('html'))
      expect(document.text).to include('In 2025 our independent newsroom closed.', 'is preserving every investigation and its source materials.')
      expect(document.css('a[href="https://archive.example.test/research"]').map(&:text)).to eq(['Independent archive'])
      expect(document.css('a[href="https://archive.example.test/statement"]').map(&:text)).to eq(['Read the full preservation statement'])
      (1..6).each { |index| expect(document.css("a[href='https://publication.example.test/research/#{index}']").length).to eq(2) }
      expect(document.css('p').map(&:text)).to eq(Nokogiri::HTML5(html).css('main p').map(&:text))
      expect(document.css('pre').map(&:text)).to eq(["  preserve_first_value();\npreserve_second_value();"])
      expect(payload.fetch('markdown')).to include('[Independent archive](https://archive.example.test/research)',
                                                   '[Read the full preservation statement](https://archive.example.test/statement)')
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end
end
