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
end
