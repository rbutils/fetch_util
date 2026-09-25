# frozen_string_literal: true

RSpec.describe 'FetchUtil extractor integration - DOM-based docs/article engines' do
  include_context 'extractor integration helpers'

  it 'extracts Ghost articles through shared Reader ownership' do
    html = fixture_contents(File.expand_path('../../fixtures/ghost_article.html', __dir__))
    extract_from_url('https://ghost.org/resources/how-to-setup-your-ghost-publication', html) do |payload|
      expect_content_type(payload, 'article')
      expect(payload['markdown']).to include(
        'How to set up your Ghost publication',
        'Resources',
        '2 min read',
        'A complete introduction to configuring your publication.',
        'Start publishing with Ghost in a few practical steps.'
      )
      expect(payload['markdown']).not_to include('Published with Ghost', 'Sign in', 'Get Started')
      expect_warnings(payload, exclude: %w[short_extraction empty_extraction url_content_mismatch consent_interstitial])
      expect(payload['suspect']).to be(false)
      expect(payload['hostAware']).to be(false)
      expect(payload['readerMode']).to be(true)
      expect(payload['excerpt']).to eq('A complete introduction to configuring your publication.')
    end
  end

  it 'extracts Sphinx docs through DOM detection' do
    expect_fixture_article(
      url: 'https://docs.python.org/3/',
      fixture_path: File.expand_path('../../fixtures/sphinx_document.html', __dir__),
      includes: [
        'Welcome to Python documentation',
        'The official home of the Python Programming Language.'
      ],
      excludes: [],
      warning_excludes: %w[short_extraction empty_extraction url_content_mismatch consent_interstitial]
    )
  end

  it 'extracts Docusaurus docs through DOM detection' do
    expect_fixture_article(
      url: 'https://docusaurus.io/',
      fixture_path: File.expand_path('../../fixtures/docusaurus_article.html', __dir__),
      includes: [
        'Build optimized websites quickly, focus on your content.',
        'Start a project'
      ],
      excludes: ['Skip to main content', 'On this page', 'Edit this page'],
      warning_excludes: %w[short_extraction empty_extraction url_content_mismatch consent_interstitial]
    )
  end
end
