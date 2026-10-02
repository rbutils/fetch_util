# frozen_string_literal: true

RSpec.describe 'FetchUtil extractor integration - generic static site articles' do
  include_context 'extractor integration helpers'

  it 'preserves every visible Hugo guide section and its source-owned H1' do
    html = fixture_contents(File.expand_path('../../fixtures/hugo_documentation.html', __dir__))
    with_url_page('https://gohugo.io/getting-started/', html) do |page|
      before = page.evaluate('document.body.innerHTML')
      payload = extract_payload(page)

      expect_content_type(payload, 'article')
      expect(payload['title']).to eq('Getting started')
      expect(payload['excerpt']).to eq('Create first Hugo project.')
      expect(payload['html']).to include('<h1>Getting started</h1>')
      ['Quick start', 'Basic usage', 'Directory structure', 'External resources'].each do |heading|
        expect(payload['markdown'].scan(heading).length).to eq(1)
      end
      ['Create first Hugo project.', 'Use command-line interface (CLI) perform tasks.',
       "An overview Hugo's directory structure.", 'Use third-party resources learn Hugo.'].each do |paragraph|
        expect(payload['markdown'].scan(paragraph).length).to eq(1)
      end
      expect(payload['markdown']).not_to include('Built with Hugo', 'Search docs', 'Community')
      expect_warnings(payload, exclude: %w[short_extraction empty_extraction url_content_mismatch consent_interstitial])
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end

  it 'keeps the complete Jekyll instructions without an empty comment invitation' do
    html = fixture_contents(File.expand_path('../../fixtures/jekyll_docs.html', __dir__))
    with_url_page('https://jekyllrb.com/docs/', html) do |page|
      before = page.evaluate('document.body.innerHTML')
      payload = extract_payload(page)

      expect_content_type(payload, 'article')
      expect(payload['title']).to eq('Quickstart')
      expect(payload['excerpt']).to start_with('Jekyll is static site generator.')
      expect(payload['html']).to include('<h1>Quickstart</h1>')
      ['Jekyll is static site generator.', 'To create a new site, install Jekyll'].each do |paragraph|
        expect(payload['markdown'].scan(paragraph).length).to eq(1)
      end
      expect(payload['markdown'].scan('bundle exec jekyll serve').length).to eq(2)
      expect(payload['markdown']).not_to include('Leave a comment', 'Showcase', 'Resources')
      expect_warnings(payload, exclude: %w[short_extraction empty_extraction url_content_mismatch consent_interstitial])
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end

  it 'preserves a source-owned title extension before a static generator brand' do
    html = fixture_contents(File.expand_path('../../fixtures/jekyll_docs.html', __dir__))
    branded_title = 'Quickstart — Additional setup notes | Jekyll • Simple, blog-aware, static sites'
    html = html.sub('<title>Quickstart | Jekyll • Simple, blog-aware, static sites</title>', "<title>#{branded_title}</title>")

    with_url_page('https://jekyllrb.com/docs/', html) do |page|
      payload = extract_payload(page)

      expect(payload['title']).to eq(branded_title)
      expect(payload['markdown']).to include('bundle exec jekyll serve')
    end
  end

  it 'does not bind a generator suffix through foreign or conflicting Article records' do
    html = fixture_contents(File.expand_path('../../fixtures/jekyll_docs.html', __dir__))
    foreign_record = '<script type="application/ld+json">{"@type":"Article","headline":"Quickstart","url":"https://other.example/guide"}</script>'
    conflicting_record = '<script type="application/ld+json">{"@type":"Article","headline":"Different guide","url":"https://jekyllrb.com/docs/"}</script>'

    [foreign_record, conflicting_record].each do |record|
      with_url_page('https://jekyllrb.com/docs/', html.sub('</head>', "#{record}</head>")) do |page|
        payload = extract_payload(page)

        expect(payload['title']).to eq('Quickstart | Jekyll • Simple, blog-aware, static sites')
      end
    end
  end

  it 'does not bind a generator suffix to a foreign or hidden H1' do
    html = fixture_contents(File.expand_path('../../fixtures/jekyll_docs.html', __dir__))
    foreign = html.sub('<h1>Quickstart</h1>', '<h1>Reference manual</h1><aside><h1>Quickstart</h1></aside>')
    hidden = html.sub('<h1>Quickstart</h1>', '<h1>Reference manual</h1><div hidden><h1>Quickstart</h1></div>')

    [foreign, hidden].each do |source|
      with_url_page('https://jekyllrb.com/docs/', source) do |page|
        payload = extract_payload(page)

        expect(payload['title']).to eq('Quickstart | Jekyll • Simple, blog-aware, static sites')
      end
    end
  end
end
