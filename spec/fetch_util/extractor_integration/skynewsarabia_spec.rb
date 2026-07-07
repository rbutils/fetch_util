# frozen_string_literal: true

RSpec.describe 'FetchUtil Sky News Arabia extractor integration' do
  include_context 'extractor integration helpers'

  it 'extracts Sky News Arabia article bodies without footer chrome warnings' do
    # Sky News Arabia's profile scopes Arabic article content and drops footer/related chrome.
    expect_fixture_article(
      url: 'https://www.skynewsarabia.com/middle-east/1879607-',
      fixture_path: File.expand_path('../../fixtures/skynewsarabia_article.html', __dir__),
      includes: [
        'الشرع: نؤسس لشراكة تقوم على المصالح المتبادلة مع فرنسا',
        'الشراكة الاستراتيجية التي تؤسس لها سوريا مع فرنسا',
        'أهلاً بكم في سوريا الجديدة'
      ],
      excludes: ['كافة العلامات التجارية الخاصة بـ SKY', 'أخبار ذات صلة'],
      warning_excludes: %w[empty_extraction short_extraction url_content_mismatch consent_interstitial stale_content]
    )
  end
end
