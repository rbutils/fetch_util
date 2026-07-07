# frozen_string_literal: true

RSpec.describe 'FetchUtil WordPress DOM extractor integration' do
  include_context 'extractor integration helpers'

  it 'extracts WordPress block theme article content when only DOM signals identify the site' do
    html = <<~HTML
      <html lang="en">
        <head>
          <title>WordPress Block Theme Sample</title>
          <meta name="generator" content="WordPress 6.6">
          <meta property="og:site_name" content="Example Blog">
          <link rel="stylesheet" href="/wp-content/themes/example/style.css">
          <script src="/wp-content/themes/example/view.js"></script>
        </head>
        <body>
          <article class="post-123 wp-block-post type-post">
            <header class="entry-header">
              <p class="byline">By Example Author</p>
              <h1 class="entry-title">WordPress Block Theme Sample</h1>
              <div class="entry-meta">July 7, 2026</div>
            </header>
            <div class="wp-block-post-content entry-content">
              <p>The first paragraph of the article is the actual content we want to keep.</p>
              <div class="wp-block-image"><img src="/wp-content/uploads/2026/07/example.jpg" alt="Example"></div>
              <p>The second paragraph stays in the extracted markdown.</p>
            </div>
            <div class="wp-block-post-author">Author bio and social links</div>
            <div class="wp-block-comments">
              <p>Leave a reply</p>
            </div>
            <div class="share">Share on social media</div>
          </article>
        </body>
      </html>
    HTML

    extract_from_url('https://example-blog.test/2026/07/wordpress-block-theme-sample/', html) do |payload|
      expect_content_type(payload, 'article')
      expect(payload['markdown']).to include('# WordPress Block Theme Sample')
      expect(payload['markdown']).to include('The first paragraph of the article is the actual content we want to keep.')
      expect(payload['markdown']).to include('The second paragraph stays in the extracted markdown.')
      expect(payload['markdown']).not_to include('By Example Author')
      expect(payload['markdown']).not_to include('Author bio and social links')
      expect(payload['markdown']).not_to include('Leave a reply')
      expect(payload['markdown']).not_to include('Share on social media')
      expect_warnings(payload, exclude: %w[short_extraction empty_extraction url_content_mismatch consent_interstitial])
      expect(payload['suspect']).to be(false)
    end
  end
end
