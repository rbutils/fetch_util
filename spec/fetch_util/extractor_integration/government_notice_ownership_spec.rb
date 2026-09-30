RSpec.describe 'Generic ownership of government notices' do
  include_context 'extractor integration helpers'

  let(:notice_url) { 'https://example.org/notices/fy-2026-innovative-coordinated-access' }
  let(:notice_html) do
    fixture_contents(File.expand_path('../../fixtures/federal_register_notice.html', __dir__))
  end

  it 'extracts the unchanged original notice fixture through generic ownership' do
    extract_from_url(notice_url, notice_html) do |payload|
      expect_content_type(payload, 'notice')
      expect(payload['title']).to eq('FY 2026 Competitive Funding Opportunity: Innovative Coordinated Access and Mobility')
      expect(payload['byline']).to eq('Department of Transportation; Federal Transit Administration')
      expect(payload['publishedTime']).to eq('07/09/2026')
      expect(payload['markdown']).to include('# FY 2026 Competitive Funding Opportunity: Innovative Coordinated Access and Mobility')
      expect(payload['html']).to include('A Notice by')
      expect(payload['html']).to include('07/09/2026')
      expect(payload['markdown']).to include(
        'The fictional transit office invites brief proposals for a small 2026 neighborhood route experiment with shared stops and flexible evening access.'
      )
      expect(payload['markdown']).to include('Complete fictional proposals must be submitted through the listed electronic route by the synthetic closing date.')
    end
  end

  it 'binds formal fields to their labels when optional contact information comes first' do
    html = notice_html.sub(
      '<div class="document-content">',
      '<div class="document-content"><h2>FOR FURTHER INFORMATION CONTACT:</h2>' \
        '<p>Reach the filing desk for questions about this notice.</p>'
    )

    extract_from_url(notice_url, html) do |payload|
      expect_content_type(payload, 'notice')
      expect(payload['byline']).to eq('Department of Transportation; Federal Transit Administration')
      expect(payload['excerpt']).to include('The fictional transit office invites brief proposals')
      expect(payload['excerpt']).not_to include('Reach the filing desk')
      expect(payload['markdown']).to include('Reach the filing desk for questions about this notice.')
      expect(payload['markdown'].index('Reach the filing desk')).to be < payload['markdown'].index('AGENCY:')
    end
  end

  it 'rejects a competing same-main agency record while retaining visible prose' do
    html = notice_html.sub(
      '<div class="document-content">',
      '<dl><dt>Agencies</dt><dd>Unrelated Office</dd><dt>Document Type</dt><dd>Notice</dd><dt>Publication Date</dt><dd>07/09/2026</dd></dl><div class="document-content">'
    )

    extract_from_url(notice_url, html) do |payload|
      expect_content_type(payload, 'article')
      expect(payload['markdown']).to include('The fictional transit office invites brief proposals')
    end
  end

  it 'ignores foreign agency metadata in a same-main sidebar' do
    html = notice_html.sub(
      '</main>',
      '<aside class="sidebar"><dl><dt>Agencies</dt><dd>Foreign Office</dd>' \
        '<dt>Document Type</dt><dd>Notice</dd><dt>Publication Date</dt>' \
        '<dd>1999-01-01</dd></dl></aside></main>'
    )

    extract_from_url(notice_url, html) do |payload|
      expect_content_type(payload, 'notice')
      expect(payload['byline']).to eq('Department of Transportation; Federal Transit Administration')
      expect(payload['publishedTime']).to eq('07/09/2026')
      expect(payload['markdown']).not_to include('Foreign Office', '1999-01-01')
    end
  end

  it 'rejects notice ownership when a separate material article is in the same main' do
    html = notice_html.sub(
      '</main>',
      '<article><h1>Independent record</h1><p>This is a separate article with its own ' \
        'visible publication and substantive explanatory material that must not be joined ' \
        'to the notice record.</p></article></main>'
    )

    extract_from_url(notice_url, html) do |payload|
      expect_content_type(payload, 'article')
      expect(payload['markdown']).to include('The fictional transit office invites brief proposals')
      expect(payload['markdown']).not_to include('Independent record')
    end
  end

  it 'rejects a competing document type in a second visible metadata group' do
    html = notice_html.sub(
      '<div class="document-content">',
      '<dl><dt>Agencies</dt><dd>Federal Transit Administration</dd>' \
        '<dt>Document Type</dt><dd>Rule</dd><dt>Publication Date</dt>' \
        '<dd>07/09/2026</dd></dl><div class="document-content">'
    )

    extract_from_url(notice_url, html) do |payload|
      expect_content_type(payload, 'article')
      expect(payload['markdown']).to include('Notice of funding opportunity (NOFO).')
    end
  end

  it 'rejects foreign Summary and Dates headings elsewhere in the same main' do
    html = notice_html.sub(
      '</main>',
      '<section><h2>SUMMARY:</h2><p>Foreign record summary.</p><h2>DATES:</h2><p>Foreign record date.</p></section></main>'
    )

    extract_from_url(notice_url, html) do |payload|
      expect_content_type(payload, 'article')
      expect(payload['markdown']).to include('The fictional transit office invites brief proposals')
    end
  end

  it 'ignores hidden metadata descendants without losing the original record' do
    html = notice_html.sub(
      '<dd>Notice</dd>',
      '<dd><span hidden>Rule</span>Notice</dd>'
    ).sub(
      '<dd><a href="/agencies/federal-transit-administration">Federal Transit Administration</a></dd>',
      '<dd><span hidden>Unrelated Office</span><a href="/agencies/federal-transit-administration">Federal Transit Administration</a></dd>'
    )

    extract_from_url(notice_url, html) do |payload|
      expect_content_type(payload, 'notice')
      expect(payload['byline']).to eq('Department of Transportation; Federal Transit Administration')
    end
  end

  it 'keeps only visible PDF resources owned by the matching document identity' do
    html = fixture_contents(File.expand_path('../../fixtures/federal_register_notice_with_document_identity.html', __dir__))
    url = 'https://example.org/documents/2026/07/09/2026-0001/fy-2026-innovative-coordinated-access'
    pdf = 'https://www.govinfo.gov/content/pkg/FR-2026-07-09/pdf/2026-0001.pdf'

    extract_from_url(url, html) do |payload|
      expect_content_type(payload, 'notice')
      expect(payload['markdown']).to include('Document Citation', '90 FR 100', 'Document Number', '2026-0001')
      expect(payload['html']).to include('data-fetchutil-source-record-identity="true"', '90 FR 100', '2026-0001')
      expect(payload['markdown'].scan(pdf).length).to eq(1)
      expect(payload['html'].scan(pdf).length).to eq(1)
      expect(payload['markdown']).to include('[contact@example.gov](mailto:contact@example.gov)')
      expect(payload['html']).to include('href="mailto:contact@example.gov"')
      expect(payload['html']).to include('Encoded recipient label')
      expect(payload['markdown']).to include('Encoded recipient label')
      expect(payload['html']).not_to include('mailto:reader%0D%0ABcc%3Aattacker@example.gov')
      expect(payload['markdown']).not_to include('mailto:reader%0D%0ABcc%3Aattacker@example.gov')
      expect(payload['html']).not_to include('href="javascript:')
      expect(payload['markdown']).not_to include('2026-0001-hidden.pdf')
      expect(payload['markdown']).not_to include('2026-0001-supplement.pdf')
    end
  end

  it 'rejects decoded mailto controls without dropping link labels' do
    html = fixture_contents(File.expand_path('../../fixtures/federal_register_notice_with_document_identity.html', __dir__))
    url = 'https://example.org/documents/2026/07/09/2026-0001/fy-2026-innovative-coordinated-access'
    unsafe_destinations = [
      'mailto:reader%0D%0ABcc%3Aattacker@example.gov',
      'mailto:reader%00@example.gov',
      'mailto:reader%7F@example.gov',
      'mailto:reader%C2%85@example.gov',
      'mailto:reader%0G@example.gov',
      'mailto:reader%250D%250A@example.gov',
      'mailto:reader@example.gov?subject=forged-header',
      'mailto:reader@example.gov#forged-fragment'
    ]
    links = unsafe_destinations.each_with_index.map do |destination, index|
      %(<a href="#{destination}">unsafe recipient #{index}</a>)
    end.join(' ')
    html = html.sub('</section>', "#{links}</section>")

    extract_from_url(url, html) do |payload|
      expect(payload['html']).to include('href="mailto:contact@example.gov"', 'contact@example.gov')
      expect(payload['markdown']).to include('[contact@example.gov](mailto:contact@example.gov)')
      unsafe_destinations.each_with_index do |destination, index|
        expect(payload['html']).to include("unsafe recipient #{index}")
        expect(payload['markdown']).to include("unsafe recipient #{index}")
        expect(payload['html']).not_to include(destination)
        expect(payload['markdown']).not_to include(destination)
      end
    end
  end

  it 'preserves safe formal-notice contacts inside definition-list fields' do
    html = fixture_contents(File.expand_path('../../fixtures/federal_register_notice_with_document_identity.html', __dir__))
    html = html.sub(
      '<p>Email <a class="email" href="mailto:contact@example.gov">contact@example.gov</a>;',
      '<dl><dt>Contact details</dt><dd><a class="email" href="mailto:contact@example.gov">contact@example.gov</a></dd></dl>;'
    )
    url = 'https://example.org/documents/2026/07/09/2026-0001/fy-2026-innovative-coordinated-access'

    extract_from_url(url, html) do |payload|
      expect_content_type(payload, 'notice')
      expect(payload['markdown']).to include('[contact@example.gov](mailto:contact@example.gov)')
      expect(payload['html']).to include('<dd>', 'href="mailto:contact@example.gov"')
    end
  end

  it 'does not let foreign definition lists override declared article metadata' do
    html = ordinary_article_html(author: 'A. Writer')

    extract_from_url('https://example.test/ordinary-story', html) do |payload|
      expect_content_type(payload, 'article')
      expect(payload['byline']).to eq('A. Writer')
      expect(payload['publishedTime']).to eq('2025-12-17T09:30:00Z')
    end
  end

  it 'does not invent an author from foreign metadata when the article has none' do
    html = ordinary_article_html(author: nil)

    extract_from_url('https://example.test/ordinary-story', html) do |payload|
      expect_content_type(payload, 'article')
      expect(payload['byline']).to be_nil
      expect(payload['publishedTime']).to eq('2025-12-17T09:30:00Z')
    end
  end

  it 'preserves same-record sibling comments, replies, authors, dates and body text' do
    comments = <<~HTML
      <section id="comments" class="comments-area">
        <h2>Reader comments</h2>
        <div class="comment-item">
          <p class="comment-author">Mina Example</p>
          <time datetime="2026-07-12T10:05:00Z">12 July 2026 at 10:05 UTC</time>
          <p class="comment-body">The notice comment body keeps its full visible route-accessibility point.</p>
          <div class="replies">
            <div class="reply-item">
              <p class="comment-author">Noah Example</p>
              <time datetime="2026-07-12T11:10:00Z">12 July 2026 at 11:10 UTC</time>
              <p class="comment-body">The reply body retains the requested application detail.</p>
            </div>
          </div>
        </div>
        <div class="comment-item">
          <p class="comment-author">Rae Example</p>
          <time datetime="2026-07-13T08:00:00Z">13 July 2026 at 08:00 UTC</time>
          <p class="comment-body">The second comment remains after the first comment and reply.</p>
        </div>
      </section>
    HTML
    html = notice_html.sub('</main>', "#{comments}</main>")

    extract_from_url(notice_url, html) do |payload|
      expect_content_type(payload, 'notice')
      expect(payload['html']).to include(
        'Mina Example', 'datetime="2026-07-12T10:05:00Z"',
        'The notice comment body keeps its full visible route-accessibility point.',
        'Noah Example', 'datetime="2026-07-12T11:10:00Z"',
        'The reply body retains the requested application detail.',
        'Rae Example', 'datetime="2026-07-13T08:00:00Z"'
      )
      expect(payload['markdown']).to include(
        'Mina Example', '12 July 2026 at 10:05 UTC',
        'The notice comment body keeps its full visible route-accessibility point.',
        'Complete fictional proposals must be submitted through the listed electronic route by the synthetic closing date.',
        'Noah Example', '12 July 2026 at 11:10 UTC',
        'The reply body retains the requested application detail.',
        'Rae Example', '13 July 2026 at 08:00 UTC',
        'The second comment remains after the first comment and reply.'
      )
      comment_position = payload['markdown'].index('Mina Example')
      reply_position = payload['markdown'].index('Noah Example')
      second_comment_position = payload['markdown'].index('Rae Example')
      expect(comment_position).to be < reply_position
      expect(reply_position).to be < second_comment_position
    end
  end

  it 'does not borrow comments from an aside or an independent sibling article' do
    aside_comment = '<aside><section id="comments" class="comments"><p>Unrelated sidebar comment.</p></section></aside>'
    aside_html = notice_html.sub('</main>', "#{aside_comment}</main>")
    extract_from_url(notice_url, aside_html) do |payload|
      expect_content_type(payload, 'notice')
      expect(payload['markdown']).not_to include('Unrelated sidebar comment.')
    end

    independent = '<article class="independent-record"><h1>Separate editorial record</h1>' \
      '<p>This separately owned article has its own long substantive visible paragraph ' \
      'and independent explanatory content that must remain outside the notice record.</p>' \
      '<section id="comments" class="comments"><p>Independent record comment must not be borrowed.</p></section></article>'
    sibling_html = notice_html.sub('</main>', "#{independent}</main>")
    extract_from_url(notice_url, sibling_html) do |payload|
      expect(payload['markdown']).not_to include('Independent record comment must not be borrowed.')
    end
  end

  it 'does not mistake a utility navigation comment count for article discussion' do
    utility_comments = '<ul><li id="utility-nav-comments" class="enhanced utility-nav-comments">' \
      '<a href="#comments">Public Comments</a><div class="comment-count-by-docket">' \
      '1 comment has been received at Regulations.gov.</div></li></ul>'
    html = notice_html.sub('</main>', "#{utility_comments}</main>")

    extract_from_url(notice_url, html) do |payload|
      expect_content_type(payload, 'notice')
      expect(payload['markdown']).to include('Complete fictional proposals must be submitted')
      expect(payload['markdown']).not_to include('1 comment has been received at Regulations.gov.')
    end
  end

  it 'does not derive an author or date from a same-main sidebar' do
    html = ordinary_article_html(author: nil).sub(
      '</main>',
      '<aside class="sidebar"><dl><dt>From</dt><dd>Foreign Office</dd>' \
        '<dt>Published</dt><dd>1999-01-01</dd></dl></aside></main>'
    )

    extract_from_url('https://example.test/ordinary-story', html) do |payload|
      expect_content_type(payload, 'article')
      expect(payload['byline']).to be_nil
      expect(payload['publishedTime']).to eq('2025-12-17T09:30:00Z')
    end
  end

  def ordinary_article_html(author:)
    author_data = author ? %("author":{"@type":"Person","name":"#{author}"},) : ''
    <<~HTML
      <!doctype html><html><head>
      <title>Ordinary article</title>
      <script type="application/ld+json">{"@context":"https://schema.org","@type":"NewsArticle","headline":"Ordinary article",#{author_data}"datePublished":"2025-12-17T09:30:00Z"}</script>
      </head><body><main><article><h1>Ordinary article</h1>
      <p>A first visible paragraph in an ordinary unknown-host article.</p>
      <p>A second visible paragraph preserves the complete article body.</p>
      <dl><dt>Agency</dt><dd>Foreign Agency</dd><dt>Published</dt><dd>1999-01-01</dd></dl>
      </article></main></body></html>
    HTML
  end
end
