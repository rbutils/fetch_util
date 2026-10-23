# frozen_string_literal: true

require 'spec_helper'
require 'support/extractor_integration_helpers'

RSpec.describe 'Source-owned dates beside independent resource records' do
  include_context 'extractor integration helpers'

  let(:page_url) { 'https://forge.publication.example.test/group/project' }

  def repository_document(records, declaration: '', readme_date: '')
    <<~HTML
      <html><head><title>Group / Project · GitLab</title>
        <meta name="application-name" content="GitLab">
        <meta name="description" content="A complete guide to this collaborative project.">
        <link rel="canonical" href="#{page_url}">#{declaration}</head>
      <body><main>
        <header class="project-home-panel"><h1>Group / Project</h1>
          <p>A complete guide to this collaborative project.</p></header>
        #{records}
        <article class="file-holder readme-holder"><div class="md">
          <header><h2>Getting started</h2>#{readme_date}</header>
          <p>Install the complete project and preserve this independently authored introduction.</p>
          <p>Read the <a href="/manual">complete manual</a> before changing configuration.</p>
          <pre><code class="language-sh">project --check --date=2020-01-01\n</code></pre>
        </div></article>
      </main></body></html>
    HTML
  end

  def linked_revision
    <<~HTML
      <div class="revision">
        <a class="item-title" href="/changes/revision-a">Update an independent resource</a>
        <div><a href="/people/editor">Ari Editor</a> authored
          <time datetime="2026-10-19T12:20:05+02:00">One day ago</time></div>
      </div>
    HTML
  end

  def dated_resource_table
    <<~HTML
      <table><thead><tr><th>Name</th><th>Changed</th></tr></thead><tbody>
        <tr><th scope="row"><a href="/files/one">First resource</a></th>
          <td><time datetime="2026-04-07T17:40:41+02:00">Six months ago</time></td></tr>
        <tr><th scope="row"><a href="/files/two">Second resource</a></th>
          <td><time datetime="2026-03-26T22:39:31+01:00">Seven months ago</time></td></tr>
      </tbody></table>
    HTML
  end

  def expect_complete_readme(page, published_time)
    before = page.evaluate('document.body.innerHTML')
    payload = FetchUtil::Extractor.new.extract(page)
    expect(payload['publishedTime']).to eq(published_time)
    expect(payload['markdown']).to include('## Getting started')
    expect(payload['markdown']).to include('Install the complete project and preserve this independently authored introduction.')
    expect(payload['markdown']).to include('[complete manual](https://forge.publication.example.test/manual)')
    expect(payload['markdown']).to include('project --check --date=2020-01-01')
    expect(payload['html']).to include('project --check --date=2020-01-01')
    expect(page.evaluate('document.body.innerHTML')).to eq(before)
  end

  it 'does not assign a separately linked revision date to the repository page' do
    with_url_page(page_url, repository_document(linked_revision)) do |page|
      expect_complete_readme(page, nil)
    end
  end

  it 'does not assign linked row-header resource dates to the repository page' do
    with_url_page(page_url, repository_document(dated_resource_table)) do |page|
      expect_complete_readme(page, nil)
    end
  end

  it 'preserves the independently declared current-document date beside both record forms' do
    date = '<time itemprop="datePublished" datetime="2021-02-03">February 3, 2021</time>'
    with_url_page(page_url, repository_document(linked_revision + dated_resource_table, readme_date: date)) do |page|
      expect_complete_readme(page, '2021-02-03')
    end
  end

  it 'preserves an explicit publisher page date even when a record declares another date' do
    declaration = '<meta property="article:published_time" content="2022-05-06T07:08:09Z">'
    with_url_page(page_url, repository_document(linked_revision + dated_resource_table, declaration: declaration)) do |page|
      expect_complete_readme(page, '2022-05-06T07:08:09Z')
    end
  end

  it 'does not mistake a page-header section link for a separately dated publication' do
    header = <<~HTML
      <header><a class="section-title" href="/documentation">Documentation</a>
        <time itemprop="datePublished" datetime="2023-07-08">July 8, 2023</time></header>
    HTML
    with_url_page(page_url, repository_document(header)) do |page|
      expect_complete_readme(page, '2023-07-08')
    end
  end
end

RSpec.describe 'Current-document dates beside ambiguous resource labels' do
  include_context 'extractor integration helpers'

  let(:page_url) { 'https://forge.publication.example.test/group/project' }

  def date_document(context)
    <<~HTML
      <html><head><title>Group / Project · GitLab</title>
        <meta name="application-name" content="GitLab">
        <link rel="canonical" href="#{page_url}"></head><body><main>
        <header class="project-home-panel"><h1>Group / Project</h1></header>
        #{context}
        <article class="file-holder readme-holder"><div class="md">
          <h2>Getting started</h2>
          <p>Preserve the complete project introduction and its independently declared publication context.</p>
          <p>Read the <a href="/manual">complete manual</a> before changing configuration.</p>
          <pre><code>project --check --date=2020-01-01\n</code></pre>
        </div></article>
      </main></body></html>
    HTML
  end

  def expect_current_date(context)
    with_url_page(page_url, date_document(context)) do |page|
      before = page.evaluate('document.body.innerHTML')
      payload = FetchUtil::Extractor.new.extract(page)
      expect(payload['publishedTime']).to eq('2023-07-08')
      expect(payload['markdown']).to include(
        '## Getting started',
        'Preserve the complete project introduction',
        '[complete manual](https://forge.publication.example.test/manual)',
        'project --check --date=2020-01-01'
      )
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end

  it 'preserves a current-page title link with a tracking query' do
    expect_current_date(<<~HTML)
      <div><a class="item-title" href="/group/project?utm_source=header">Group / Project</a>
        <time itemprop="datePublished" datetime="2023-07-08">July 8, 2023</time></div>
    HTML
  end

  it 'preserves a current-page title used as a resource-table row header' do
    expect_current_date(<<~HTML)
      <table><tbody><tr><th scope="row"><a href="/group/project">Group / Project</a></th>
        <td><time itemprop="datePublished" datetime="2023-07-08">July 8, 2023</time></td></tr></tbody></table>
    HTML
  end

  it 'does not treat an author-profile row header as a publication subject' do
    expect_current_date(<<~HTML)
      <table><tbody><tr><th scope="row"><a rel="author" href="/authors/ari">Ari Editor</a></th>
        <td><time itemprop="datePublished" datetime="2023-07-08">July 8, 2023</time></td></tr></tbody></table>
    HTML
  end

  it 'does not borrow the title of a separate nested article to reject a page date' do
    expect_current_date(<<~HTML)
      <div><article><a class="item-title" href="/news/independent">Independent publication</a></article>
        <div><time itemprop="datePublished" datetime="2023-07-08">July 8, 2023</time></div></div>
    HTML
  end
end

RSpec.describe 'Physical row-date subject witnesses' do
  include_context 'extractor integration helpers'

  let(:page_url) { 'https://forge.publication.example.test/group/project' }

  def assert_current_row_date(header)
    html = <<~HTML
      <html><head><title>Group / Project · GitLab</title>
        <meta name="application-name" content="GitLab">
        <link rel="canonical" href="#{page_url}"></head><body><main>
        <header class="project-home-panel"><h1>Group / Project</h1></header>
        <table><tbody><tr>#{header}
          <td><time itemprop="datePublished" datetime="2023-07-08">July 8, 2023</time></td></tr></tbody></table>
        <article class="file-holder readme-holder"><div class="md">
          <h2>Getting started</h2>
          <p>Preserve the complete project introduction and its independently declared publication context.</p>
          <p>Read the <a href="/manual">complete manual</a> before changing configuration.</p>
          <pre><code>project --check --date=2020-01-01\n</code></pre>
        </div></article>
      </main></body></html>
    HTML
    with_url_page(page_url, html) do |page|
      before = page.evaluate('document.body.innerHTML')
      payload = FetchUtil::Extractor.new.extract(page)
      expect(payload['publishedTime']).to eq('2023-07-08')
      expect(payload['markdown']).to include('Preserve the complete project introduction')
      expect(payload['markdown']).to include('[complete manual](https://forge.publication.example.test/manual)')
      expect(payload['markdown']).to include('project --check --date=2020-01-01')
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end

  it 'binds the visible row-subject link rather than a preceding hidden empty link' do
    assert_current_row_date(<<~HTML)
      <th scope="row"><a hidden href="/files/other"></a>
        <a href="/group/project?utm_source=header">Group / Project</a></th>
    HTML
  end

  it 'does not interpret an explicit column-group heading as a row-owned resource' do
    assert_current_row_date('<th scope="colgroup"><a href="/reference/field">Publication field</a></th>')
  end
end
