# frozen_string_literal: true

RSpec.describe 'FetchUtil Jang extractor integration' do
  include_context 'extractor integration helpers'

  it 'extracts a single Jang liveblog story without multi-topic related headlines' do
    expect_fixture_article(
      url: 'https://jang.com.pk/liveblog/6',
      fixture_path: File.expand_path('../../fixtures/jang_liveblog_article.html', __dir__),
      includes: [
        'آئل ٹینکر کو نشانہ بنانا ناقابلِ قبول جارحیت ہے، قطر',
        'قطری وزارت خارجہ کے ترجمان ماجد الانصاری نے دوحہ سے جاری بیان'
      ],
      excludes: ['یہ دوسری لائیو بلاگ اپڈیٹ ہے', 'شئیر کریں'],
      warning_excludes: %w[multi_topic_page empty_extraction short_extraction url_content_mismatch consent_interstitial]
    )
  end
end
