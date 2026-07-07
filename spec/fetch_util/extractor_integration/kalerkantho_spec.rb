# frozen_string_literal: true

RSpec.describe 'FetchUtil Kaler Kantho extractor integration' do
  include_context 'extractor integration helpers'

  it 'extracts Kaler Kantho article bodies without e-paper and related-story chrome' do
    expect_fixture_article(
      url: 'https://www.kalerkantho.com/online/national/2026/07/07/1708171',
      fixture_path: File.expand_path('../../fixtures/kalerkantho_article.html', __dir__),
      includes: [
        'প্রধানমন্ত্রীর সফরের পর খুলল মালয়েশিয়ার শ্রমবাজার',
        'বাংলাদেশি শ্রমিকদের জন্য আবারও খুলে দেওয়া হয়েছে মালয়েশিয়ার শ্রমবাজার',
        'সিন্ডিকেট ও দুর্নীতি এড়াতে সরকার ও এজেন্সিগুলোর সমন্বিত উদ্যোগ'
      ],
      excludes: ['ই-পেপার সাবস্ক্রিপশন', 'জুলাইয়ের মধ্যে স্থানীয় নির্বাচনের বিধিমালা', 'related story body should not leak'],
      warning_excludes: %w[empty_extraction short_extraction url_content_mismatch consent_interstitial multi_topic_page truncated_content]
    )
  end
end
