# frozen_string_literal: true

RSpec.describe 'FetchUtil B.T. extractor integration' do
  include_context 'extractor integration helpers'

  it 'extracts public B.T. Ritzau article bodies without navigation and front-page chrome' do
    expect_fixture_article(
      url: 'https://www.bt.dk/samfund/efter-usaedvanligt-dyr-juni-aabner-juli-med-lavere-elpriser',
      fixture_path: File.expand_path('../../fixtures/bt_dk_article.html', __dir__),
      includes: [
        'Efter usædvanligt dyr juni åbner juli med lavere elpriser',
        'Hedebølge og manglende vindproduktion skabte høje strømpriser',
        'SVM-regeringen har dog sænket elafgiften',
        'RITZAU'
      ],
      excludes: ['NavigationSektioner', 'Front-page teaser should not leak', 'Log ind og læs'],
      warning_excludes: %w[empty_extraction short_extraction url_content_mismatch consent_interstitial multi_topic_page]
    )
  end
end
