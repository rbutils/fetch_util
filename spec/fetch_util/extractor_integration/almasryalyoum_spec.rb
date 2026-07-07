# frozen_string_literal: true

RSpec.describe 'FetchUtil Al Masry Al Youm extractor integration' do
  include_context 'extractor integration helpers'

  it 'extracts Al Masry Al Youm article bodies without stale-content warnings' do
    # Al Masry Al Youm article pages wrap the real body in the masry article container.
    expect_fixture_article(
      url: 'https://www.almasryalyoum.com/news/details/3055115',
      fixture_path: File.expand_path('../fixtures/almasryalyoum_article.html', __dir__),
      includes: [
        'ترصد «المصرى اليوم»، في النشرة الصباحية، أبرز الأخبار التي حظيت باهتمام القراء خلال الساعات الأولى من صباح اليوم.',
        'حسن شحاتة يفجر مفاجأة: شيكابالا كان يتهرب من الانضمام لمنتخب مصر'
      ],
      excludes: %w[related-article-inside-body masry-article-horizontal-ads],
      warning_excludes: %w[empty_extraction short_extraction url_content_mismatch consent_interstitial stale_content]
    )
  end
end
