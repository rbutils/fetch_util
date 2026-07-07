# frozen_string_literal: true

RSpec.describe 'FetchUtil Eenadu extractor integration' do
  include_context 'extractor integration helpers'

  it 'extracts eenadu article bodies without chrome' do
    expect_fixture_article(
      url: 'https://www.eenadu.net/telugu-news/nri/telugu-student-dies-in-a-fatal-car-accident-in-usa/1101/126119342',
      fixture_path: File.expand_path('../../fixtures/eenadu_article.html', __dir__),
      includes: [
        'ఇబ్రహీంపట్నం గ్రామీణం: ఉన్నత చదువుల కోసం అమెరికాకు వెళ్లిన మరో తెలుగు విద్యార్థిని',
        'తండ్రి వసంతరావు వ్యవసాయం',
        'చదివించాలన్న లక్ష్యంతో'
      ],
      excludes: ['TRENDING', 'E-PAPER', 'Read latest', 'Follow us', 'Published', '1 min read', 'Tags :'],
      warning_excludes: %w[empty_extraction short_extraction truncated_content url_content_mismatch consent_interstitial multi_topic_page]
    )
  end
end
