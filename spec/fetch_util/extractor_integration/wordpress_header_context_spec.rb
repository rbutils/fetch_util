# frozen_string_literal: true

RSpec.describe 'FetchUtil WordPress article header context' do
  include_context 'extractor integration helpers'

  def wordpress_header_page(header:, before_body: '', after_body: '')
    <<~HTML
      <html><head><title>Restoring a river</title><meta name="generator" content="WordPress 6.6"></head><body>
        #{header}
        <main><article id="post-42">
          #{before_body}
          <div class="entry-content">
            <p>The restoration team returned to the river to measure the effect of removing the concrete barriers.</p>
            <p>Engineers compared water levels and wildlife counts before discussing the next stage with residents.</p>
            <p>The work will continue through the autumn, with a public report documenting each result.</p>
          </div>
          #{after_body}
        </article></main>
      </body></html>
    HTML
  end

  def river_header(lead: '<div class="article-excerpt">A source-owned lead explains the river restoration.</div>')
    "<header><h1 class='entry-title'>Restoring a river</h1>#{lead}</header>"
  end

  it 'preserves an adjacent article header lead before the body without changing the live DOM' do
    html = wordpress_header_page(header: river_header)

    with_url_page('https://example-blog.test/river-restoration/', html) do |page|
      payload = extract_payload(page)
      expect(payload['markdown']).to include('A source-owned lead explains the river restoration.')
      expect(payload['html']).to include('A source-owned lead explains the river restoration.')
      expect(payload['excerpt']).to start_with('A source-owned lead explains the river restoration.')
      expect(payload['markdown'].index('A source-owned lead')).to be < payload['markdown'].index('The restoration team')
      expect(page.at_css('.article-excerpt').text).to eq('A source-owned lead explains the river restoration.')
      expect(page.css('.entry-content').length).to eq(1)
      expect_content_type(payload, 'article')
      expect_warnings(payload, exclude: %w[short_extraction empty_extraction multi_topic_page])
    end
  end

  it 'keeps an article-owned lead once even when nested semantic markers identify the same content' do
    header = river_header(lead: '<div class="entry-summary"><span itemprop="description">The river belongs to everyone.</span></div>')
    html = wordpress_header_page(header: '', before_body: header)

    extract_from_url('https://example-blog.test/river-restoration/', html) do |payload|
      expect(payload['markdown'].scan('The river belongs to everyone.').length).to eq(1)
    end
  end

  it 'does not adopt hidden leads, sidebar summaries, ambiguous headlines or unrelated headers' do
    hidden = '<div class="article-excerpt" hidden>A hidden promotional summary.</div>'
    css_hidden = '<div style="display:none"><div class="entry-summary">A CSS-hidden summary.</div></div>'
    sidebar = '<aside><div class="article-excerpt">An unrelated sidebar summary.</div></aside>'
    cases = [
      wordpress_header_page(header: river_header(lead: hidden + css_hidden + sidebar)),
      wordpress_header_page(header: "#{river_header}<h1>A second independent headline</h1>"),
      wordpress_header_page(header: "#{river_header}<nav>Independent navigation separates these records.</nav>"),
      wordpress_header_page(header: '', after_body: river_header),
      wordpress_header_page(header: river_header, after_body: '<article><div class="entry-content">A second independent article body.</div></article>')
    ]

    cases.each do |html|
      extract_from_url('https://example-blog.test/river-restoration/', html) do |payload|
        expect(payload['markdown']).to include('The restoration team returned to the river')
        expect(payload['html']).not_to include('A source-owned lead', 'A hidden promotional summary', 'A CSS-hidden summary', 'An unrelated sidebar summary')
      end
    end
  end
end
