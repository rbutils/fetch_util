# frozen_string_literal: true

RSpec.describe 'FetchUtil extractor integration - static SSG DOM profiles' do
  include_context 'extractor integration helpers'

  it 'extracts Hugo documentation pages through DOM detection' do
    expect_fixture_article(
      url: 'https://gohugo.io/getting-started/',
      fixture_path: File.expand_path('../../fixtures/hugo_documentation.html', __dir__),
      includes: [
        'Getting started',
        'Create first Hugo project.',
        'Use command-line interface (CLI) perform tasks.'
      ],
      excludes: ['Built with Hugo', 'Search docs', 'News', 'Community'],
      warning_excludes: %w[short_extraction empty_extraction url_content_mismatch consent_interstitial]
    )
  end

  it 'extracts Jekyll docs pages through DOM detection' do
    expect_fixture_article(
      url: 'https://jekyllrb.com/docs/',
      fixture_path: File.expand_path('../../fixtures/jekyll_docs.html', __dir__),
      includes: [
        'Quickstart',
        'Jekyll is static site generator.',
        'bundle exec jekyll serve'
      ],
      excludes: %w[Home Docs Resources Showcase News],
      warning_excludes: %w[short_extraction empty_extraction url_content_mismatch consent_interstitial]
    )
  end
end
