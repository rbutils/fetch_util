# frozen_string_literal: true

RSpec.describe 'FetchUtil generic focal comment ownership' do
  include_context 'extractor integration helpers'

  it 'keeps every visible comment and reply only from the verified focal article thread' do
    html = <<~HTML
      <html><head><title>Refund update | Example News</title>
        <link rel="canonical" href="https://publisher.example/articles/refund-123456">
        <meta property="og:type" content="NewsArticle">
        <script type="application/ld+json">
          {"@type":"NewsArticle","headline":"Refund update","mainEntityOfPage":"https://publisher.example/articles/refund-123456"}
        </script>
      </head><body><main><div class="article-page">
        <article><h1>Refund update</h1><p>The published update explains the latest refund information in detail. Readers can review the eligibility rules, the expected schedule, the support channels available during processing, and the steps needed to check an account without repeating a request. The article also clarifies that each case is reviewed individually and that an earlier notification may arrive before funds settle.</p></article>
        <section id="comments" class="comments">
          <div class="comment-item" id="comment-one">
            <a class="comment-author" href="/users/reader-one">Reader One</a>
            <p>嗯，我也遇到了同样的问题。</p><time datetime="2026-08-24">August 24, 2026</time>
            <span class="comment-location">Guizhou</span><a href="/comment/one">Source link</a>
            <div class="reply-list"><div class="reply-item">
              <a class="reply-author" href="/users/author-two">Author Two</a>
              <p>谢谢补充，我会继续跟进这项退款进度。</p><time datetime="2026-08-25">August 25, 2026</time>
              <a href="/comment/reply">Reply source</a>
            </div></div>
          </div>
          <div class="comment-item" id="comment-two">
            <a class="comment-author" href="/users/reader-three">Reader Three</a>
            <p>I received the same update from support yesterday.</p><time datetime="2026-08-26">August 26, 2026</time>
          </div>
          <div class="comment-item" id="comment-three">
            <footer><span class="comment-author">Reader without a profile</span>
              <time datetime="2026-08-27">August 27, 2026</time><a href="#comments">Whole discussion</a></footer>
            <p>短い補足です。</p>
          </div>
          <div class="comment-item" id="comment-image">
            <span>Image contributor</span><img src="/reader-evidence.jpg" alt="A reader's survey image">
            <time datetime="2026-08-28">August 28, 2026</time>
          </div>
        </section>
        <section id="comments-followup" class="comments-area"><div class="thread-comment">
          <span>Follow-up reader</span><p>The later discussion remains owned by this same article.</p>
        </div></section>
        <section id="comments-custom" class="comments">
          <reader-comment><span>Custom tag reader</span>
            <div slot="comment">This short custom-element comment is part of the same discussion.</div>
          </reader-comment>
        </section>
        <aside><section class="comments"><div class="comment-item">
          <a href="/users/sidebar">Sidebar reader</a><p>This sidebar discussion belongs to another item.</p>
        </div></section></aside>
        <section id="hidden-comments" class="comments" style="display:none"><div class="comment-item">
          <a href="/users/hidden">Hidden reader</a><p>This comment is not visible.</p>
        </div></section>
        <section class="comments-promo"><a href="/sign-in">Sign in</a><p>Join the discussion after signing in.</p></section>
        <form class="comment-form"><textarea placeholder="Write a comment"></textarea><button>Submit</button></form>
        <section id="empty-thread" class="comments"><form><textarea placeholder="No posted comment"></textarea></form></section>
      </div></main></body></html>
    HTML

    with_url_page('https://publisher.example/articles/refund-123456', html) do |page|
      before = page.evaluate('document.body.innerHTML')
      payload = extract_payload(page, reader_mode: false)

      expect_content_type(payload, 'article')
      expect(payload['html']).to include(
        'Reader One', '嗯，我也遇到了同样的问题。', 'Author Two',
        '谢谢补充，我会继续跟进这项退款进度。', 'Reader Three',
        'Reader without a profile', '短い補足です。', 'Image contributor',
        '/reader-evidence.jpg', 'Follow-up reader', 'Custom tag reader',
        'This short custom-element comment', 'August 24, 2026',
        'Guizhou', '/comment/one', '/comment/reply'
      )
      expect(payload['markdown']).to include(
        'Reader One', '嗯，我也遇到了同样的问题。', 'Author Two',
        'Reader Three', 'August 24, 2026', 'Guizhou',
        'Reader without a profile', '短い補足です。',
        'Image contributor', '/reader-evidence.jpg',
        'Follow-up reader', 'Custom tag reader',
        'This short custom-element comment', '/comment/one', '/comment/reply'
      )
      expect(payload['markdown']).not_to include(
        'Sidebar reader', 'Hidden reader', 'Join the discussion',
        'Write a comment', 'This sidebar discussion', 'No posted comment'
      )
      expect(payload['html']).to include('id="comments"')
      expect(payload['markdown']).to include('August 27, 2026', 'https://publisher.example/articles/refund-123456#comments')
      expect(page.evaluate('document.body.innerHTML')).to eq(before)

      ordered = ['The published update', 'Reader One', '嗯，我也遇到了同样的问题。', 'Author Two',
                 '谢谢补充，我会继续跟进这项退款进度。', 'Reader Three', 'Reader without a profile',
                 'Image contributor', 'Follow-up reader', 'Custom tag reader']
      positions = ordered.map { |text| payload['html'].index(text) }
      expect(positions).not_to include(nil)
      expect(positions).to eq(positions.sort)
    end
  end

  it 'does not attach a collection discussion to any individual record' do
    records = (1..3).map do |index|
      <<~HTML
        <article><h2><a href="/story/report-#{index}00001">Independent report #{index}</a></h2>
          <p>Each story has its own summary and belongs to the larger reporting section.</p></article>
      HTML
    end.join
    html = <<~HTML
      <html><head><title>Latest reports | Example News</title></head><body>
        <main><h1>Latest reports</h1>#{records}
        </main><aside>
          <section id="comments"><div class="comment-item"><a href="/users/list">List reader</a>
            <p>This discussion does not belong to an individual story.</p></div></section>
        </aside></body></html>
    HTML

    with_url_page('https://publisher.example/section/latest', html) do |page|
      payload = extract_payload(page)

      expect_content_type(payload, 'list')
      expect(payload['markdown']).not_to include('List reader', 'does not belong to an individual story')
    end
  end
end
