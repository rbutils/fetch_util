# frozen_string_literal: true

RSpec.describe 'FetchUtil Seznam Novinky extractor integration' do
  include_context 'extractor integration helpers'

  it 'extracts Novinky article bodies through generic article detection' do
    expect_fixture_article(
      url: 'https://www.novinky.cz/clanek/domaci-zemrel-namestek-ministryne-pro-mistni-rozvoj-endal-40586881',
      fixture_path: File.expand_path('../../fixtures/seznam_novinky_article.html', __dir__),
      includes: ['Ve věku 51 let zemřel náměstek ministryně', 'Byl to skvělý profesionál a nesmírně erudovaný člověk'],
      excludes: ['Nastavení souhlasu s personalizací', 'Související témata'],
      warning_excludes: %w[empty_extraction short_extraction url_content_mismatch consent_interstitial]
    )
  end
end
