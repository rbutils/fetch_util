# frozen_string_literal: true

RSpec.describe 'FetchUtil Jang extractor integration' do
  include_context 'extractor integration helpers'

  it 'extracts a single Jang liveblog story without multi-topic related headlines' do
    expect_fixture_article(
      url: 'https://jang.com.pk/liveblog/6?story=3591',
      fixture_path: File.expand_path('../../fixtures/jang_liveblog_article.html', __dir__),
      includes: [
        'آئل ٹینکر کو نشانہ بنانا ناقابلِ قبول جارحیت ہے، قطر',
        'قطری وزارت خارجہ کے ترجمان ماجد الانصاری نے دوحہ سے جاری بیان'
      ],
      excludes: ['یہ دوسری لائیو بلاگ اپڈیٹ ہے', 'شئیر کریں'],
      warning_excludes: %w[multi_topic_page empty_extraction short_extraction url_content_mismatch consent_interstitial]
    )
  end

  it 'generically preserves every visible update on an unscoped Jang liveblog' do
    html = fixture_contents(File.expand_path('../../fixtures/jang_liveblog_article.html', __dir__))

    extract_from_url('https://jang.com.pk/liveblog/6', html) do |payload|
      expect_content_type(payload, 'article')
      expect(payload['contentFormat']).to eq('liveblog')
      expect(payload['markdown']).to include('قطری وزارت خارجہ کے ترجمان ماجد الانصاری نے دوحہ سے جاری بیان')
      expect(payload['markdown']).to include('یہ دوسری لائیو بلاگ اپڈیٹ ہے')
      expect(payload['markdown']).not_to include('شئیر کریں')
      expect_warnings(payload, include: 'multi_topic_page', exclude: %w[empty_extraction short_extraction url_content_mismatch consent_interstitial])
      expect(payload['suspect']).to be(true)
    end
  end

  it 'extracts the public Jang news URL without short_extraction' do
    expect_fixture_article(
      url: 'https://jang.com.pk/news/1560993',
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
