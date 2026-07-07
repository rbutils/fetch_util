# frozen_string_literal: true

RSpec.describe 'FetchUtil Sky News Arabia extractor integration' do
  include_context 'extractor integration helpers'

  it 'extracts Sky News Arabia article bodies without footer chrome warnings' do
    html = File.read(File.expand_path('../../fixtures/skynewsarabia_article.html', __dir__))
    url = 'https://www.skynewsarabia.com/middle-east/1879607-'

    extract_from_url(url, html) do |payload|
      expect_content_type(payload, 'article')
      expect(payload['markdown']).to include('الشرع: نؤسس لشراكة تقوم على المصالح المتبادلة مع فرنسا')
      expect(payload['markdown']).to include('الشراكة الاستراتيجية التي تؤسس لها سوريا مع فرنسا')
      expect(payload['markdown']).to include('أهلاً بكم في سوريا الجديدة')
      expect(payload['markdown']).not_to include('كافة العلامات التجارية الخاصة بـ SKY')
      expect(payload['markdown']).not_to include('أخبار ذات صلة')
      expect_warnings(payload, exclude: %w[empty_extraction short_extraction url_content_mismatch consent_interstitial stale_content])
      expect(payload['suspect']).to be(false)
    end
  end
end
