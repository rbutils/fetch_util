# frozen_string_literal: true

RSpec.describe 'FetchUtil Jang extractor integration' do
  include_context 'extractor integration helpers'

  it 'extracts a single Jang liveblog story without multi-topic related headlines' do
    html = File.read(File.expand_path('../../fixtures/jang_liveblog_article.html', __dir__))
    url = 'https://jang.com.pk/liveblog/6'

    extract_from_url(url, html) do |payload|
      expect_content_type(payload, 'article')
      expect(payload['markdown']).to include('آئل ٹینکر کو نشانہ بنانا ناقابلِ قبول جارحیت ہے، قطر')
      expect(payload['markdown']).to include('قطری وزارت خارجہ کے ترجمان ماجد الانصاری نے دوحہ سے جاری بیان')
      expect(payload['markdown']).not_to include('یہ دوسری لائیو بلاگ اپڈیٹ ہے')
      expect(payload['markdown']).not_to include('شئیر کریں')
      expect_warnings(payload, exclude: %w[multi_topic_page empty_extraction short_extraction url_content_mismatch consent_interstitial])
      expect(payload['suspect']).to be(false)
    end
  end
end
