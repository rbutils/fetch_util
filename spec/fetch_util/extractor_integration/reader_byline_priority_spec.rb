# frozen_string_literal: true

RSpec.describe 'reader byline priority' do
  include_context 'extractor integration helpers'

  def reader_byline_article(metadata_author:, visible_author:, author_title: metadata_author, author_href: '/autoren/reporter')
    title_attribute = author_title ? %( title="#{author_title}") : ''
    <<~HTML
      <html><head>
        <title>Regional culture program expands</title>
        <meta name="author" content="#{metadata_author}">
      </head><body><main><article>
        <header class="article-header">
          <h1 class="article-heading"><span>Regional culture</span><span class="visually-hidden">: </span><span>program expands</span></h1>
          <div class="summary">Community organizations are preparing a larger regional culture program for the coming year.</div>
          <a rel="author" href="#{author_href}"#{title_attribute}>#{visible_author}</a>
        </header>
        <div class="article-body"><div class="article-page">
          <p>The regional culture program is expanding with new venues, workshops, and public events developed with community organizations.</p>
          <p>Organizers said the next phase will support local artists while giving residents more opportunities to participate throughout the year.</p>
          <p>Schools, libraries, and neighborhood groups will publish a shared calendar as each part of the program opens to the public.</p>
        </div></div>
      </article></main></body></html>
    HTML
  end

  def reader_byline_test_source
    root = File.expand_path('../../..', __dir__)
    source = File.readlines(File.join(root, 'websieve/manifest.txt'), chomp: true)
                 .reject { |line| line.empty? || line.start_with?('#') }
                 .map { |path| File.read(File.join(root, 'websieve', path)) }.join("\n")
    outro = File.read(File.join(root, 'websieve/99_outro.js'))
    source.delete_suffix(outro) + <<~JS + outro
      window.__supplementReaderByline = function(input) {
        var before = document.body.innerHTML;
        var first = supplementReaderBylineLink(input.content, input.author);
        var second = supplementReaderBylineLink(first, input.author);
        return JSON.stringify({
          result: second,
          idempotent: JSON.stringify(first) === JSON.stringify(second),
          sourceUnchanged: document.body.innerHTML === before
        });
      };
      window.__readerSourceAuthor = function(input) {
        return JSON.stringify(readerBylineSourceAuthorLink(input.content, input.metadataByline));
      };
      window.__readerHtmlHasAuthor = function(input) {
        var root = document.createElement('div');
        root.innerHTML = input.html;
        return readerBylineHtmlHasAuthor(root, input.author);
      };
      window.__readerBylineCanExpand = function(input) {
        return readerBylineCanExpand(input.content, input.author);
      };
    JS
  end

  def supplemented_reader_byline(content, author)
    source = reader_byline_test_source

    with_url_page('https://example.de/culture/rendered', '<main><article><p>Original source body.</p></article></main>') do |page|
      page.add_script_tag(content: source)
      JSON.parse(page.evaluate("window.__supplementReaderByline(#{JSON.generate(content: content, author: author)})"))
    end
  end

  def source_reader_author(page_html, content, metadata_byline)
    with_url_page('https://example.de/culture/source-owner', page_html) do |page|
      page.add_script_tag(content: reader_byline_test_source)
      JSON.parse(page.evaluate("window.__readerSourceAuthor(#{JSON.generate(content: content, metadataByline: metadata_byline)})"))
    end
  end

  def rendered_reader_author?(html, author)
    with_url_page('https://example.de/culture/rendered-author', '<main>Original source body.</main>') do |page|
      page.add_script_tag(content: reader_byline_test_source)
      page.evaluate("window.__readerHtmlHasAuthor(#{JSON.generate(html: html, author: author)})")
    end
  end

  def expandable_reader_byline?(content, author)
    with_url_page('https://example.de/culture/expandable-author', '<main>Original source body.</main>') do |page|
      page.add_script_tag(content: reader_byline_test_source)
      page.evaluate("window.__readerBylineCanExpand(#{JSON.generate(content: content, author: author)})")
    end
  end

  it 'prefers a substantially more informative metadata name to an opaque reader handle' do
    html = reader_byline_article(metadata_author: 'Yannick von Eisenhart Rothe', visible_author: 'yer')

    with_url_page('https://example.de/culture/program', html) do |page|
      before = page.evaluate('document.body.innerHTML')
      payload = extract_payload(page)

      expect(payload).to include('byline' => 'Yannick von Eisenhart Rothe', 'readerMode' => true)
      expect(payload['markdown']).to include('[Yannick von Eisenhart Rothe](https://example.de/autoren/reporter)')
      expect(payload['markdown'].scan('https://example.de/autoren/reporter').length).to eq(1)
      expect(payload['html']).to include('href="https://example.de/autoren/reporter" rel="author"')
      expect(payload['textContent']).to include('Yannick von Eisenhart Rothe')
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end

  it 'preserves an exact locally owned author destination omitted by reader mode' do
    html = fixture_contents(File.expand_path('../../fixtures/blic_article.html', __dir__))
           .gsub('Teodora Boskovski', 'Alice Brown')
           .sub('/autori/teodora-boskovski', '/autori/alice-brown')

    with_url_page('https://example.de/culture/local-author', html) do |page|
      before = page.evaluate('document.body.innerHTML')
      payload = extract_payload(page)

      expect(payload).to include('byline' => 'Alice Brown', 'readerMode' => true)
      expect(payload['markdown']).to include('[Alice Brown](https://example.de/autori/alice-brown)')
      expect(payload['markdown'].scan('https://example.de/autori/alice-brown').length).to eq(1)
      expect(payload['html']).to include('href="https://example.de/autori/alice-brown" rel="author"')
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end

  it 'preserves meaningful visible bylines and mononyms' do
    meaningful = reader_byline_article(metadata_author: 'Structured Reporter Name', visible_author: 'News Desk')
    mononym = reader_byline_article(metadata_author: 'Cher', visible_author: 'AB')

    extract_from_url('https://example.de/culture/meaningful', meaningful) do |payload|
      expect(payload['byline']).to eq('News Desk')
    end
    extract_from_url('https://example.de/culture/mononym', mononym) do |payload|
      expect(payload['byline']).to eq('AB')
    end
  end

  it 'requires the same safe author link and matching initials before expanding a reader byline' do
    initials = reader_byline_article(metadata_author: 'Alice Brown', visible_author: 'A. B.')
    unrelated = reader_byline_article(metadata_author: 'Jane Doe', visible_author: 'Li')
    untitled = reader_byline_article(metadata_author: 'Yannick von Eisenhart Rothe', visible_author: 'yer', author_title: nil)
    cross_origin = reader_byline_article(
      metadata_author: 'Jane Doe',
      visible_author: 'JD',
      author_href: 'https://authors.example.net/jane-doe'
    )
    credentials = reader_byline_article(
      metadata_author: 'Jane Doe',
      visible_author: 'JD',
      author_href: 'https://user:secret@example.de/autoren/jane-doe'
    )

    extract_from_url('https://example.de/culture/initials', initials) do |payload|
      expect(payload['byline']).to eq('Alice Brown')
      expect(payload['markdown']).to include('[Alice Brown](https://example.de/autoren/reporter)')
    end
    extract_from_url('https://example.de/culture/unrelated', unrelated) do |payload|
      expect(payload['byline']).to eq('Li')
    end
    extract_from_url('https://example.de/culture/untitled', untitled) do |payload|
      expect(payload['byline']).to eq('yer')
    end
    extract_from_url('https://example.de/culture/cross-origin', cross_origin) do |payload|
      expect(payload['byline']).to eq('JD')
      expect(payload['markdown']).not_to include('authors.example.net')
    end
    extract_from_url('https://example.de/culture/credentials', credentials) do |payload|
      expect(payload['byline']).to eq('JD')
      expect(payload['markdown']).not_to include('user:secret')
    end

    expect(
      expandable_reader_byline?(
        { 'byline' => 'a. b.' },
        { 'name' => 'Alice Brown', 'sourceNames' => ['A. B.'] }
      )
    ).to be(true)
  end

  it 'does not use identity evidence from another article or related module' do
    paragraph = 'The selected report contains independently verified details about the primary subject and its public impact.'
    html = <<~HTML
      <html><head>
        <title>Target report</title>
        <meta name="author" content="Yannick von Eisenhart Rothe">
      </head><body><main>
        <article>
          <h1>Target report</h1>
          <span class="byline">yer</span>
          <article class="teaser"><a rel="author" href="/authors/yannick-nested" title="Yannick von Eisenhart Rothe">yer</a></article>
          <p>#{paragraph} #{paragraph}</p>
          <p>#{paragraph} #{paragraph}</p>
          <p>#{paragraph} #{paragraph}</p>
          <div class="related"><a rel="author" href="/authors/yannick-related" title="Yannick von Eisenhart Rothe">yer</a></div>
        </article>
        <article>
          <h2>Unrelated report</h2>
          <a rel="author" href="/authors/yannick-decoy" title="Yannick von Eisenhart Rothe">yer</a>
          <p>This separate article must not supply identity evidence for the selected report.</p>
        </article>
      </main></body></html>
    HTML

    extract_from_url('https://example.de/culture/target', html) do |payload|
      expect(payload['byline']).to eq('yer')
    end
  end

  it 'does not use an article owned by an outer related module as identity evidence' do
    paragraph_one = 'The focal-looking card repeats enough article prose to test that outer related ownership still blocks author identity evidence.'
    paragraph_two = 'A second uniquely mapped paragraph ensures the source article itself would otherwise satisfy the reader ownership proof.'
    html = <<~HTML
      <main><section class="related-reports"><article>
        <a rel="author" href="/authors/yannick-related" title="Yannick von Eisenhart Rothe">yer</a>
        <p>#{paragraph_one}</p><p>#{paragraph_two}</p>
      </article></section></main>
    HTML
    content = {
      'html' => "<p>#{paragraph_one}</p><p>#{paragraph_two}</p>",
      'textContent' => "#{paragraph_one} #{paragraph_two}",
      'byline' => 'yer'
    }

    expect(source_reader_author(html, content, 'Yannick von Eisenhart Rothe')).to be_nil
  end

  it 'rejects late, conflicting, or unsafe source identities' do
    metadata_name = 'Alice Brown'
    paragraph_one = 'The selected report contains independently verified details about its subject and public impact for every participating community.'
    paragraph_two = 'A second substantial paragraph establishes the same focal article without relying on unrelated author metadata or nearby modules.'
    content = {
      'html' => "<p>#{paragraph_one}</p><p>#{paragraph_two}</p>",
      'textContent' => "#{paragraph_one} #{paragraph_two}",
      'byline' => 'AB'
    }
    article = lambda do |links|
      <<~HTML
        <main><article><h1>Selected report</h1>
          #{links}
          <p>#{paragraph_one}</p><p>#{paragraph_two}</p>
        </article></main>
      HTML
    end
    valid = '<a rel="author" href="/authors/alice" title="Alice Brown">AB</a>'
    conflicting = '<a rel="author" href="/authors/alice-other" title="Alice Brown">AB</a>'
    unsafe = '<a rel="author" href="https://authors.example.net/alice" title="Alice Brown">AB</a>'
    late = <<~HTML
      <main><article><h1>Selected report</h1>
        <p>#{paragraph_one}</p><p>#{paragraph_two}</p>
        #{valid}
      </article></main>
    HTML

    expect(source_reader_author(article.call(valid + conflicting), content, metadata_name)).to be_nil
    expect(source_reader_author(article.call(valid + unsafe), content, metadata_name)).to be_nil
    expect(source_reader_author(late, content, metadata_name)).to be_nil
  end

  it 'requires exact local author ownership for unmarked localized links' do
    metadata_name = 'Alice Brown'
    paragraph_one = 'The selected report contains independently verified details about its subject and public impact for every participating community.'
    paragraph_two = 'A second substantial paragraph establishes the same focal article without relying on unrelated author metadata or nearby modules.'
    content = {
      'html' => "<p>#{paragraph_one}</p><p>#{paragraph_two}</p>",
      'textContent' => "#{paragraph_one} #{paragraph_two}",
      'byline' => metadata_name
    }
    article = lambda do |author_markup|
      <<~HTML
        <main><article><h1>Selected report</h1>
          #{author_markup}
          <p>#{paragraph_one}</p><p>#{paragraph_two}</p>
        </article></main>
      HTML
    end

    valid = '<div class="article-author"><a href="/autori/alice-brown">Alice Brown</a></div>'
    expect(source_reader_author(article.call(valid), content, metadata_name)).to include(
      'name' => metadata_name,
      'url' => 'https://example.de/autori/alice-brown'
    )

    controls = {
      'missing metadata owner' => '<div><a href="/autori/alice-brown">Alice Brown</a></div>',
      'body prose link' => '<p>Read more from <a href="/autori/alice-brown">Alice Brown</a> in the complete archive.</p>',
      'name mismatch' => '<div class="article-author"><a href="/autori/alice-brown">Alicia Brown</a></div>',
      'related owner' => '<div class="related article-author"><a href="/autori/alice-brown">Alice Brown</a></div>',
      'nested article' => '<div class="article-author"><article><a href="/autori/alice-brown">Alice Brown</a></article></div>',
      'hidden link' => '<div class="article-author"><a hidden href="/autori/alice-brown">Alice Brown</a></div>',
      'aria-hidden link' => '<div class="article-author"><a aria-hidden="true" href="/autori/alice-brown">Alice Brown</a></div>',
      'cross-origin link' => '<div class="article-author"><a href="https://authors.example.net/autori/alice-brown">Alice Brown</a></div>',
      'credential link' => '<div class="article-author"><a href="https://user:secret@example.de/autori/alice-brown">Alice Brown</a></div>',
      'missing slug' => '<div class="article-author"><a href="/autori">Alice Brown</a></div>',
      'directory slug' => '<div class="article-author"><a href="/autori/directory">Alice Brown</a></div>'
    }
    controls.each do |label, markup|
      expect(source_reader_author(article.call(markup), content, metadata_name)).to be_nil, label
    end
  end

  it 'expands initials across a lowercase particle joined to a surname' do
    html = reader_byline_article(metadata_author: "Jean d'Arc", visible_author: 'JA')

    extract_from_url('https://example.de/culture/particle', html) do |payload|
      expect(payload['byline']).to eq("Jean d'Arc")
    end
  end

  it 'supports exact initials in names without case distinctions' do
    html = reader_byline_article(metadata_author: '王 小明', visible_author: '王小')

    extract_from_url('https://example.de/culture/unicameral', html) do |payload|
      expect(payload['byline']).to eq('王 小明')
    end
  end

  it 'supplements an explicit article markdown payload without duplicating the author destination' do
    url = 'https://example.de/autoren/reporter'
    body = 'Original article body with enough independently verified reporting detail to establish the first substantive article paragraph.'
    inert_markup = <<~HTML
      <script>
        var authorTemplate = '<a rel="author" href="#{url}">Alice Brown</a>';
      </script>
      <style>
        .author-template::before {
          content: '<a rel="author" href="#{url}">Alice Brown</a>';
        }
      </style>
    HTML
    result = supplemented_reader_byline(
      {
        'html' => inert_markup + "<div style=\"display:none\"><a rel=\"author\" href=\"#{url}\">Alice Brown</a></div>" \
                  "<h1>Original article</h1><p><a href=\"#{url}\">Source</a> #{body}</p>",
        'markdown' => "# Original article\n\n`[Alice Brown](#{url})`\n\n```text\n[Alice Brown](#{url})\n```\n\n" \
                      "A source variant mentions #{url}?ref=context.\n\n#{body}",
        'textContent' => body
      },
      { 'name' => 'Alice Brown', 'url' => url }
    )
    content = result.fetch('result')

    expect(content['markdown']).to start_with("# Original article\n\n[Alice Brown](#{url})")
    expect(content['markdown'].scan("](#{url})").length).to eq(3)
    expect(content['html'].scan(url).length).to eq(5)
    expect(content['html']).to match(%r{<h1>Original article</h1><p><a href="#{url}" rel="author">Alice Brown</a></p>})
    expect(content['textContent']).to start_with('Alice Brown ')
    expect(result['idempotent']).to be(true)
    expect(result['sourceUnchanged']).to be(true)
  end

  it 'places the author after a markdown title preceded by metadata and ignores related HTML duplicates' do
    url = 'https://example.de/autoren/reporter'
    body = 'Original article body with enough independently verified reporting detail to establish the first substantive article paragraph.'
    related_html = "<article class=\"related-reports\"><h1>Related article</h1>" \
                   "<a rel=\"author\" href=\"#{url}\">Alice Brown</a><p>#{body}</p></article>"
    retained_html = "<article><h1>Original article</h1><p>#{body}</p>" \
                    "<a rel=\"author\" href=\"#{url}\">Alice Brown</a></article>"

    expect(rendered_reader_author?(related_html, { 'name' => 'Alice Brown', 'url' => url })).to be(false)
    expect(rendered_reader_author?(related_html + retained_html, { 'name' => 'Alice Brown', 'url' => url })).to be(true)
    expect(rendered_reader_author?("<p><a href=\"#{url}\">Alice Brown</a></p>", { 'name' => 'Alice Brown', 'url' => url })).to be(true)

    nested_related = "<article><h1>Original article</h1><p>#{body}</p>" \
                     "<article class=\"related\"><a href=\"#{url}\">Alice Brown</a></article></article>"
    nested_result = supplemented_reader_byline(
      { 'html' => nested_related, 'markdown' => "# Original article\n\n#{body}", 'textContent' => body },
      { 'name' => 'Alice Brown', 'url' => url }
    )
    expect(nested_result.dig('result', 'html').scan(url).length).to eq(2)

    result = supplemented_reader_byline(
      {
        'html' => "<h1>Original article</h1><p>#{body}</p>",
        'markdown' => "---\ntitle: Original article\n---\n\n<!-- lead -->\n<div>Context</div>\n\n# Original article\n\n#{body}",
        'textContent' => body
      },
      { 'name' => 'Alice Brown', 'url' => url }
    )
    content = result.fetch('result')

    expect(content['markdown']).to include("# Original article\n\n[Alice Brown](#{url})\n\n#{body}")
    expect(content['markdown']).to start_with("---\ntitle: Original article")
    expect(content['html'].scan(url).length).to eq(1)
    expect(result['idempotent']).to be(true)
  end

  it 'does not duplicate an exact author resource already linked in article prose' do
    url = 'https://example.de/autoren/reporter'
    body = 'Original article body with enough independently verified reporting detail to establish the first substantive article paragraph.'
    markdown = "# Original article\n\n#{body} See [Alice Brown](#{url}) for the source biography."

    result = supplemented_reader_byline(
      {
        'html' => "<h1>Original article</h1><p>#{body}</p>",
        'markdown' => markdown,
        'textContent' => body
      },
      { 'name' => 'Alice Brown', 'url' => url }
    )

    expect(result.dig('result', 'markdown')).to eq(markdown)
    expect(result.fetch('idempotent')).to be(true)
  end
end
