# frozen_string_literal: true

require 'json'

RSpec.describe 'SPA data fallback' do
  include_context 'extractor integration helpers'

  it 'uses substantial Next.js data when normal DOM extraction is sparse' do
    fallback_text = ('NEXT_DATA_FALLBACK_TEXT explains the fully rendered article content. ' * 8).strip
    next_data = JSON.generate(props: { pageProps: { title: 'SPA fallback record', content: fallback_text } })
    html = <<~HTML
      <html>
        <head><title>SPA fallback record</title></head>
        <body>
          <main><h1>Loading article</h1><p>Please wait.</p></main>
          <script id="__NEXT_DATA__" type="application/json">#{next_data}</script>
        </body>
      </html>
    HTML

    with_page(html) do |page|
      payload = extract_payload(page)

      expect(payload['markdown']).to include('NEXT_DATA_FALLBACK_TEXT')
    end
  end

  it 'keeps a substantial regular article instead of replacing it with Next.js data' do
    article_text = ('REGULAR_ARTICLE_TEXT is the visible article body and must remain authoritative. ' * 8).strip
    fallback_text = ('NEXT_DATA_SHOULD_NOT_REPLACE_ARTICLE is only embedded page data. ' * 8).strip
    next_data = JSON.generate(props: { pageProps: { title: 'Embedded fallback', content: fallback_text } })
    html = <<~HTML
      <html>
        <head><title>Regular article</title></head>
        <body>
          <main><article><h1>Regular article</h1><p>#{article_text}</p></article></main>
          <script id="__NEXT_DATA__" type="application/json">#{next_data}</script>
        </body>
      </html>
    HTML

    with_page(html) do |page|
      payload = extract_payload(page)

      expect(payload['markdown']).to include('visible article body and must remain authoritative')
      expect(payload['markdown']).not_to include('NEXT_DATA_SHOULD_NOT_REPLACE_ARTICLE')
    end
  end
end
