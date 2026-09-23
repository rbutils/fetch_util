# frozen_string_literal: true

RSpec.describe 'FetchUtil Blogger extractor integration' do
  include_context 'extractor integration helpers'

  it 'extracts Blogger blogspot article content from DOM signals' do
    html = fixture_contents(File.expand_path('../../fixtures/blogger_blogspot_article.html', __dir__))
    url = 'https://bloggingatoz24.blogspot.com/2013/10/how-to-increase-space-between-post.html'

    with_url_page(url, html) do |page|
      source_body = page.evaluate('document.body.innerHTML')
      payload = extract_payload(page)

      expect_content_type(payload, 'article')
      expect(payload['title']).to eq('How to Increase the Space Between the Post Title & the Post Body on Blogger')
      expect(payload['publishedTime']).to eq('Posted on July 8, 2026')
      expect(payload['warnings']).to eq([])
      expect(payload['excerpt']).to eq(
        'How to Increase the Space Between the Post Title & the Post Body on Blogger ' \
        'The first paragraph keeps the actual Blogger article body. ' \
        'The second paragraph stays in extracted markdown.'
      )
      paragraphs = [
        'The first paragraph keeps the actual Blogger article body.',
        'The second paragraph stays in extracted markdown.'
      ]
      paragraphs.each do |paragraph|
        expect(payload['markdown'].scan(paragraph).length).to eq(1)
        expect(payload['html']).to include("<p>#{paragraph}</p>")
      end
      expect(payload['markdown']).to start_with('# How to Increase the Space Between the Post Title & the Post Body on Blogger')
      expect(payload['markdown']).not_to include('Blogger navbar', 'Archive widget', 'Leave a comment', 'Comment thread')
      expect(payload['html']).not_to include('Leave a comment', 'Comment thread')
      expect(page.evaluate('document.body.innerHTML')).to eq(source_body)
    end
  end

  it 'extracts custom-domain Blogger article content from DOM signals' do
    expect_fixture_article(
      url: 'https://www.wazipoint.com/2019/05/how-show-post-title-only-on-your.html',
      fixture_path: File.expand_path('../../fixtures/blogger_custom_domain_article.html', __dir__),
      includes: [
        '# HOW SHOW THE POST TITLE ONLY ON YOUR BLOGGER HOMEPAGE',
        'This custom-domain Blogger article keeps the post body text.',
        'The closing paragraph still belongs in the article output.'
      ],
      excludes: [
        'Blogger navbar',
        'Recent posts widget',
        'Published July 8, 2026',
        'Comments'
      ],
      warning_excludes: %w[empty_extraction short_extraction url_content_mismatch consent_interstitial]
    )
  end
end
