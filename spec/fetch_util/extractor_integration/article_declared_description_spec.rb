# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Declared article descriptions' do
  include_context 'extractor integration helpers'

  def extract_url_payload(url, html)
    result = nil
    extract_from_url(url, html) { |payload| result = payload }
    result
  end

  def result_description_policy
    html = <<~HTML
      <html><head><title>Description policy</title>
        <meta name="description" content="Page fallback description">
      </head><body></body></html>
    HTML

    with_page(html) do |page|
      websieve_root = File.expand_path('../../../websieve', __dir__)
      source_paths = File.readlines(File.join(websieve_root, 'manifest.txt'), chomp: true).reject(&:empty?)
      source = source_paths.map { |path| File.read(File.join(websieve_root, path)) }.join("\n")
      probe = source.sub('})(window);', <<~'JS'.strip)
        window.__contentDescriptionForResult = contentDescriptionForResult;
        window.__collectMetadata = collectMetadata;
        window.__finalizeExtractResult = finalizeExtractResult;
        })(window);
      JS
      page.add_script_tag(content: probe)
      page.evaluate(<<~JS)
        (function() {
          var metadata = window.__collectMetadata();
          var publicArticle = window.__finalizeExtractResult({
            title: 'Empty article description',
            siteName: 'publisher.example.test',
            description: '',
            excerpt: 'Visible content excerpt remains separate',
            html: '<article><h1>Empty article description</h1><p>Visible article body with enough text to retain.</p></article>',
            markdown: '# Empty article description\\n\\nVisible article body with enough text to retain.',
            textContent: 'Visible article body with enough text to retain.',
            contentType: 'article',
            hostAware: true,
            warnings: []
          }, metadata, 'Visible article body with enough text to retain.', {}, false);
          var publicEvent = window.__finalizeExtractResult({
            title: 'Empty event description',
            siteName: 'publisher.example.test',
            description: '',
            html: '<main><h1>Empty event description</h1></main>',
            markdown: '# Empty event description',
            textContent: 'Visible event details',
            contentType: 'event',
            hostAware: true,
            warnings: []
          }, metadata, 'Visible event details', {}, false);
          return {
          article: window.__contentDescriptionForResult({ contentType: 'article' }, { declaredDescription: 'Declared page description' }),
          articleOwned: window.__contentDescriptionForResult({ contentType: 'article', description: 'Article-owned description' }, { declaredDescription: 'Declared page description' }),
          articleOwnedEmpty: window.__contentDescriptionForResult({ contentType: 'article', description: '' }, { declaredDescription: 'Declared page description' }),
          articleOwnedNull: window.__contentDescriptionForResult({ contentType: 'article', description: null }, { declaredDescription: 'Declared page description' }),
          eventOwned: window.__contentDescriptionForResult({ contentType: 'event', description: 'Event record description' }, { declaredDescription: 'Declared page description' }),
          eventOwnedEmpty: window.__contentDescriptionForResult({ contentType: 'event', description: '' }, { declaredDescription: 'Declared page description' }),
          eventWithoutDescription: window.__contentDescriptionForResult({ contentType: 'event' }, { declaredDescription: 'Declared page description' }),
          list: window.__contentDescriptionForResult({ contentType: 'list' }, { declaredDescription: 'Declared page description' }),
          publicArticleDescription: publicArticle.description,
          publicArticleExcerpt: publicArticle.excerpt,
          publicArticleMarkdown: publicArticle.markdown,
          publicEventDescription: publicEvent.description
          };
        })()
      JS
    end
  end

  it 'keeps the declared description separate from a longer article excerpt and body' do
    declared = 'Metadata summary: the council approved a regional transit plan after public review.'
    lead = 'VISIBLE-LEAD: the transit authority approved a revised evening schedule after consultation.'
    html = <<~HTML
      <html><head>
        <title>Regional transit schedule approved</title>
        <meta property="og:title" content="Regional transit schedule approved">
        <meta name="description" content="#{declared}">
      </head><body><main><article>
        <h1>Regional transit schedule approved</h1>
        <p>#{lead}</p>
        <p>The published plan identifies stations, intervals, and connecting routes for the timetable.</p>
        <p>Officials will publish service results after six months and review the schedule publicly.</p>
      </article></main></body></html>
    HTML

    payload = extract_url_payload('https://publisher.example.test/articles/transit-plan', html)

    expect(payload['contentType']).to eq('article')
    expect(payload['description']).to eq(declared)
    expect(payload['excerpt']).to include('VISIBLE-LEAD')
    expect(payload['excerpt']).not_to include(declared)
    expect(payload['markdown']).to include(lead)
    expect(payload['markdown']).not_to include(declared)
    expect(payload['html']).not_to include(declared)
  end

  it 'preserves declared descriptions for short bodies and visible access gates' do
    short_description = 'Declared summary: the launch begins at noon at the regional station.'
    short_body = 'VISIBLE-SHORT-BODY: the source says the launch begins at noon.'
    short_html = <<~HTML
      <html><head>
        <title>Visible short article heading</title>
        <meta property="og:title" content="Visible short article heading">
        <meta name="description" content="#{short_description}">
      </head><body><main>
        <h1>Visible short article heading</h1>
        <article><p>#{short_body}</p></article>
      </main></body></html>
    HTML
    gate_description = 'Declared summary: the complete analysis is available to registered readers.'
    gate = 'Login to read the full article.'
    gate_html = <<~HTML
      <html><head>
        <title>Visible gated article heading</title>
        <meta property="og:title" content="Visible gated article heading">
        <meta name="description" content="#{gate_description}">
      </head><body><main><article>
        <h1>Visible gated article heading</h1>
        <div class="readall_box">#{gate}</div>
      </article></main></body></html>
    HTML

    short = extract_url_payload('https://publisher.example.test/short-dispatch', short_html)
    gated = extract_url_payload('https://publisher.example.test/gated-analysis', gate_html)

    expect(short['description']).to eq(short_description)
    expect(short['excerpt']).to include(short_body)
    expect(short['markdown']).to include(short_body)
    expect(gated['description']).to eq(gate_description)
    expect(gated['excerpt']).to include(gate)
    expect(gated['markdown']).to include(gate)
  end

  it 'supports metadata-only descriptions without inventing one for a title-only page' do
    description = 'Metadata-only description: the source listing identifies a report without body text.'
    described_html = <<~HTML
      <html><head><title>Report listing</title>
        <meta property="og:type" content="article">
        <meta name="description" content="#{description}">
      </head><body></body></html>
    HTML
    described = extract_url_payload(
      'https://publisher.example.test/metadata-only',
      described_html
    )
    title_only = extract_url_payload(
      'https://publisher.example.test/title-only',
      '<html><head><title>Title only article</title></head><body></body></html>'
    )

    expect(described['description']).to eq(description)
    expect(title_only['title']).to eq('Title only article')
    expect(title_only['description']).to be_nil
  end

  it 'uses a nonempty Open Graph description when the standard declaration is blank' do
    open_graph = 'Open Graph summary: the source announcement includes launch details.'
    html = <<~HTML
      <html><head><title>Launch announcement</title>
        <meta property="og:type" content="article">
        <meta name="description" content="  ">
        <meta property="og:description" content="#{open_graph}">
      </head><body></body></html>
    HTML
    payload = extract_url_payload(
      'https://publisher.example.test/open-graph-description',
      html
    )

    expect(payload['description']).to eq(open_graph)
  end

  it 'uses declared descriptions only as article fallbacks' do
    policy = result_description_policy
    expect(policy).to eq(
      'article' => 'Declared page description',
      'articleOwned' => 'Article-owned description',
      'articleOwnedEmpty' => '',
      'articleOwnedNull' => 'Declared page description',
      'eventOwned' => 'Event record description',
      'eventOwnedEmpty' => '',
      'eventWithoutDescription' => nil,
      'list' => nil,
      'publicArticleDescription' => '',
      'publicArticleExcerpt' => 'Visible content excerpt remains separate',
      'publicArticleMarkdown' => "# Empty article description\n\nVisible article body with enough text to retain.",
      'publicEventDescription' => ''
    )
    expect(policy.fetch('publicArticleMarkdown')).not_to include('Page fallback description')
  end

  it 'keeps structured event descriptions authoritative' do
    page_description = 'Page summary: the site provides calendar information.'
    event_description = 'Structured event description: a complete public agenda and venue details.'
    event_html = <<~HTML
      <html><head>
        <meta name="description" content="#{page_description}">
        <script type="application/ld+json">{"@context":"https://schema.org","@type":"Event","name":"Community workshop","startDate":"2026-10-12T10:00:00Z","description":"#{event_description}"}</script>
      </head><body><main><h1>Community workshop</h1><time datetime="2026-10-12T10:00:00Z">October 12, 2026</time></main></body></html>
    HTML
    event = extract_url_payload('https://events.example.test/community-workshop', event_html)

    expect(event['contentType']).to eq('event')
    expect(event['description']).to eq(event_description)
    expect(event['description']).not_to eq(page_description)
  end
end
