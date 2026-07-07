# frozen_string_literal: true

RSpec.describe 'FetchUtil Kaler Kantho extractor integration' do
  include_context 'extractor integration helpers'

  it 'extracts Kaler Kantho article bodies without e-paper and related-story chrome' do
    html = File.read(File.expand_path('../../fixtures/kalerkantho_article.html', __dir__))
    url = 'https://www.kalerkantho.com/online/national/2026/07/07/1708171'

    extract_from_url(url, html) do |payload|
      expect_content_type(payload, 'article')
      expect(payload['markdown']).to include('প্রধানমন্ত্রীর সফরের পর খুলল মালয়েশিয়ার শ্রমবাজার')
      expect(payload['markdown']).to include('বাংলাদেশি শ্রমিকদের জন্য আবারও খুলে দেওয়া হয়েছে মালয়েশিয়ার শ্রমবাজার')
      expect(payload['markdown']).to include('সিন্ডিকেট ও দুর্নীতি এড়াতে সরকার ও এজেন্সিগুলোর সমন্বিত উদ্যোগ')
      expect(payload['markdown']).not_to include('ই-পেপার সাবস্ক্রিপশন')
      expect(payload['markdown']).not_to include('জুলাইয়ের মধ্যে স্থানীয় নির্বাচনের বিধিমালা')
      expect(payload['markdown']).not_to include('related story body should not leak')
      expect_warnings(payload, exclude: %w[empty_extraction short_extraction url_content_mismatch consent_interstitial multi_topic_page truncated_content])
      expect(payload['suspect']).to be(false)
    end
  end
end
