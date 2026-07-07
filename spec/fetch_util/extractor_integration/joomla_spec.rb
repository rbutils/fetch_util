# frozen_string_literal: true

RSpec.describe 'FetchUtil Joomla extractor integration' do
  include_context 'extractor integration helpers'

  it 'extracts Joomla article bodies from DOM signals and removes module chrome' do
    expect_fixture_article(
      url: 'https://www.joomla.org/announcements/release-news/5955-joomla-6-1-2-5-4-7-security-bugfix-release.html',
      fixture_path: File.expand_path('../fixtures/joomla_article.html', __dir__),
      includes: [
        'Joomla! Project is pleased announce release Joomla 6.1.2',
        'security & bugfix releases'
      ],
      excludes: ['Breadcrumb', 'Pagination', 'Module chrome', 'Sidebar module'],
      warning_excludes: %w[empty_extraction short_extraction url_content_mismatch consent_interstitial]
    )
  end
end
