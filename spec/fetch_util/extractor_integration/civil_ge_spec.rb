# frozen_string_literal: true

RSpec.describe 'FetchUtil Civil.ge extractor integration' do
  include_context 'extractor integration helpers'

  it 'extracts Civil.ge article bodies instead of sidebar lists' do
    # Civil.ge's profile selects the archive article body instead of sidebar/news lists.
    expect_fixture_article(
      url: 'https://civil.ge/archives/743770',
      fixture_path: File.expand_path('../../fixtures/civil_ge_article.html', __dir__),
      includes: [
        'Giorgi Bakhuashvili, who reportedly served as a personal bodyguard',
        'According to RFE/RL’s Georgian Service'
      ],
      excludes: ['MFA’s Newly Created Diplomatic Academy', 'Read Next'],
      warning_excludes: %w[empty_extraction short_extraction url_content_mismatch consent_interstitial]
    )
  end
end
