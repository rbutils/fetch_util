# frozen_string_literal: true

RSpec.describe 'FetchUtil BBC Igbo extractor integration' do
  include_context 'extractor integration helpers'

  it 'extracts BBC Igbo reportage articles without stale_content warnings' do
    expect_fixture_article(
      url: 'https://www.bbc.com/igbo/articles/c8r07734dp4o',
      fixture_path: File.expand_path('../../fixtures/bbc_igbo_article.html', __dir__),
      includes: [
        "Ndị ụka CAC ahụ kwuru na ha nwetara enyemaka",
        "Akụkọ a gara n'ihu na-akọwa otú ndị uweojii"
      ],
      excludes: [],
      warning_excludes: %w[stale_content],
      suspect: true
    )
  end
end
