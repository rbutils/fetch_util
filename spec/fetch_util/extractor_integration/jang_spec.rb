# frozen_string_literal: true

RSpec.describe 'FetchUtil Jang extractor integration' do
  include_context 'extractor integration helpers'

  it 'retains the parent when the query has no source-owned update URL' do
    html = fixture_contents(File.expand_path('../../fixtures/jang_liveblog_article.html', __dir__))

    extract_from_url('https://jang.com.pk/liveblog/6?story=3591', html) do |payload|
      expect_content_type(payload, 'article')
      expect(payload['contentFormat']).to eq('liveblog')
      expect(payload['title']).to eq('اسلام آباد مفاہمتی یادداشت پر دستخط کے بعد ایران اور امریکا کے پھر ایک دوسرے پر حملے')
      expect(payload['byline']).to be_nil
      expect(payload['publishedTime']).to be_nil
      expect(payload['markdown']).to include(
        'قطری وزارت خارجہ کے ترجمان ماجد الانصاری نے دوحہ سے جاری بیان',
        'یہ دوسری لائیو بلاگ اپڈیٹ ہے', 'Tuesday Jul 07 2026 | 07:39 PM', 'ویب ڈیسک'
      )
      expect(payload['markdown']).not_to include('شئیر کریں')
      expect_warnings(payload, include: 'multi_topic_page', exclude: %w[empty_extraction short_extraction url_content_mismatch consent_interstitial])
    end
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

  it 'preserves the complete liveblog fixture when served at a news route' do
    html = fixture_contents(File.expand_path('../../fixtures/jang_liveblog_article.html', __dir__))

    extract_from_url('https://jang.com.pk/news/1560993', html) do |payload|
      expect_content_type(payload, 'article')
      expect(payload['contentFormat']).to eq('liveblog')
      expect(payload['byline']).to be_nil
      expect(payload['publishedTime']).to be_nil
      expect(payload['markdown']).to include(
        'قطری وزارت خارجہ کے ترجمان ماجد الانصاری نے دوحہ سے جاری بیان', 'یہ دوسری لائیو بلاگ اپڈیٹ ہے'
      )
      expect(payload['markdown']).not_to include('شئیر کریں')
      expect_warnings(payload, include: 'multi_topic_page', exclude: %w[empty_extraction short_extraction url_content_mismatch consent_interstitial])
    end
  end
end
