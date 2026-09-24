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

  it 'retains every visible section and story link in its article root' do
    html = File.read(File.expand_path('../fixtures/almasryalyoum_article.html', __dir__))
    url = 'https://www.almasryalyoum.com/news/details/3055115'

    with_url_page(url, html) do |page|
      before = page.evaluate('document.body.innerHTML')
      paragraphs = page.evaluate("Array.from(document.querySelectorAll('.article-details p'), node => node.textContent.trim())")
      story_links = page.evaluate("Array.from(document.querySelectorAll('.article-details a[href]'), node => node.href)")
      image = page.evaluate("document.querySelector('.article-main-img img').src")
      heading = page.evaluate("document.querySelector('.article-title').textContent.trim()")
      payload = extract_payload(page)

      expect(payload).to include(
        'title' => heading, 'contentType' => 'article',
        'readerMode' => false, 'hostAware' => true, 'warnings' => []
      )
      expect(payload.fetch('html')).to match(%r{<h1\b[^>]*>#{Regexp.escape(heading)}</h1>})
      expect(payload.fetch('html')).to include(image, 'نشرة أخبار الصباح - صورة أرشيفية')
      expect(payload.fetch('markdown')).to include(image, 'نشرة أخبار الصباح - صورة أرشيفية')
      paragraphs.each do |paragraph|
        expect(payload.fetch('markdown').scan(paragraph).length).to eq(1)
        expect(payload.fetch('html').scan(paragraph).length).to eq(1)
      end
      story_links.each do |destination|
        expect(payload.fetch('markdown')).to include(destination)
        expect(payload.fetch('html')).to include(destination)
      end
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end
end
