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
        <h1>Regional culture program expands</h1>
        <div class="article-meta"><a rel="author" href="#{author_href}"#{title_attribute}>#{visible_author}</a></div>
        <p>The regional culture program is expanding with new venues, workshops, and public events developed with community organizations.</p>
        <p>Organizers said the next phase will support local artists while giving residents more opportunities to participate throughout the year.</p>
        <p>Schools, libraries, and neighborhood groups will publish a shared calendar as each part of the program opens to the public.</p>
      </article></main></body></html>
    HTML
  end

  it 'prefers a substantially more informative metadata name to an opaque reader handle' do
    html = reader_byline_article(metadata_author: 'Yannick von Eisenhart Rothe', visible_author: 'yer')

    extract_from_url('https://example.de/culture/program', html) do |payload|
      expect(payload).to include('byline' => 'Yannick von Eisenhart Rothe', 'readerMode' => true)
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

    extract_from_url('https://example.de/culture/initials', initials) do |payload|
      expect(payload['byline']).to eq('Alice Brown')
    end
    extract_from_url('https://example.de/culture/unrelated', unrelated) do |payload|
      expect(payload['byline']).to eq('Li')
    end
    extract_from_url('https://example.de/culture/untitled', untitled) do |payload|
      expect(payload['byline']).to eq('yer')
    end
    extract_from_url('https://example.de/culture/cross-origin', cross_origin) do |payload|
      expect(payload['byline']).to eq('JD')
    end
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
end
