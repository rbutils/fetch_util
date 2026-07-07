# frozen_string_literal: true

RSpec.describe 'FetchUtil Eenadu extractor integration' do
  include_context 'extractor integration helpers'

  it 'extracts eenadu article bodies without chrome' do
    html = File.read(File.expand_path('../../fixtures/eenadu_article.html', __dir__))
    url = 'https://www.eenadu.net/telugu-news/nri/telugu-student-dies-in-a-fatal-car-accident-in-usa/1101/126119342'

    extract_from_url(url, html) do |payload|
      expect_content_type(payload, 'article')
      expect(payload['markdown']).to include('ఇబ్రహీంపట్నం గ్రామీణం: ఉన్నత చదువుల కోసం అమెరికాకు వెళ్లిన మరో తెలుగు విద్యార్థిని')
      expect(payload['markdown']).to include('తండ్రి వసంతరావు వ్యవసాయం')
      expect(payload['markdown']).to include('చదివించాలన్న లక్ష్యంతో')
      expect(payload['markdown']).not_to include('TRENDING')
      expect(payload['markdown']).not_to include('E-PAPER')
      expect(payload['markdown']).not_to include('Read latest')
      expect(payload['markdown']).not_to include('Follow us')
      expect(payload['markdown']).not_to include('Published')
      expect(payload['markdown']).not_to include('1 min read')
      expect(payload['markdown']).not_to include('Tags :')
      expect_warnings(payload, exclude: %w[empty_extraction short_extraction truncated_content url_content_mismatch consent_interstitial multi_topic_page])
    end
  end
end
