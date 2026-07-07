# frozen_string_literal: true

RSpec.describe 'FetchUtil Drupal extractor integration' do
  include_context 'extractor integration helpers'

  it 'extracts Drupal article bodies from DOM signals and removes views and comment chrome' do
    expect_fixture_article(
      url: 'https://www.drupal.org/docs/develop',
      fixture_path: File.expand_path('../fixtures/drupal_article.html', __dir__),
      includes: [
        'Drupal content lives in the main node body',
        'The article body remains after views, blocks, and comments are removed.'
      ],
      excludes: ['Related view item', 'Sidebar block', 'Comment chrome'],
      warning_excludes: %w[empty_extraction short_extraction url_content_mismatch consent_interstitial]
    )
  end
end
