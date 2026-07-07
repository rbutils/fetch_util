# frozen_string_literal: true

RSpec.describe 'FetchUtil extractor integration - DOM-based docs/article engines' do
  include_context 'extractor integration helpers'

  it 'extracts Ghost articles through DOM detection' do
    expect_fixture_article(
      url: 'https://ghost.org/resources/how-to-setup-your-ghost-publication',
      fixture_path: File.expand_path('../../fixtures/ghost_article.html', __dir__),
      includes: [
        'How to set up your Ghost publication',
        'Start publishing with Ghost in a few practical steps.'
      ],
      excludes: ['Published with Ghost', 'Sign in', 'Get Started'],
      warning_excludes: %w[short_extraction empty_extraction url_content_mismatch consent_interstitial]
    )
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
