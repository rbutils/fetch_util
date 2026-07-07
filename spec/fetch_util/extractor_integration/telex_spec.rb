# frozen_string_literal: true

RSpec.describe 'FetchUtil extractor integration' do
  include_context 'extractor integration helpers'

  it 'extracts Telex article bodies through generic article detection' do
    expect_fixture_article(
      url: 'https://telex.hu/kulfold/2026/07/06/nato-csucs-ankara-trump-kozel-kelet-magyar-peter',
      fixture_path: File.expand_path('../../fixtures/telex_article.html', __dir__),
      includes: ['Az évente megrendezett NATO-csúcsok hosszú időn át', 'Politikai konfliktusok árnyékában'],
      excludes: [],
      warning_excludes: %w[empty_extraction short_extraction url_content_mismatch consent_interstitial]
    )
  end
end
