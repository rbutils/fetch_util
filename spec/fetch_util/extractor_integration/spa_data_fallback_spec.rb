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

  it 'examines content after the former array and object-key probe limits' do
    array_values = Array.new(205, 'small metadata')
    array_values << ('LATE_ARRAY_CONTENT is visible content beyond the old array probe limit. ' * 8)
    page_props = { 'title' => 'Late SPA content', 'items' => array_values }
    next_data = JSON.generate(props: { pageProps: page_props })
    html = <<~HTML
      <html><head><title>Late SPA content</title></head><body>
        <main><h1>Loading</h1></main>
        <script id="__NEXT_DATA__" type="application/json">#{next_data}</script>
      </body></html>
    HTML

    with_page(html) do |page|
      payload = extract_payload(page)

      expect(payload['markdown']).to include('LATE_ARRAY_CONTENT')
      expect(payload['warnings']).not_to include('spa_data_traversal_guard')
    end
  end

  it 'examines content after the former object-key probe limit' do
    page_props = { 'title' => 'Late SPA key' }
    55.times { |index| page_props["metadata_#{index}"] = "value #{index}" }
    page_props['late_document'] = 'LATE_OBJECT_CONTENT is visible content beyond the old object-key probe limit. ' * 8
    next_data = JSON.generate(props: { pageProps: page_props })
    html = <<~HTML
      <html><head><title>Late SPA key</title></head><body>
        <main><h1>Loading</h1></main>
        <script id="__NEXT_DATA__" type="application/json">#{next_data}</script>
      </body></html>
    HTML

    with_page(html) do |page|
      payload = extract_payload(page)

      expect(payload['markdown']).to include('LATE_OBJECT_CONTENT')
      expect(payload['warnings']).not_to include('spa_data_traversal_guard')
    end
  end

  it 'handles a large flat SPA data array without recursive stack growth' do
    values = Array.new(30_000, 'small value')
    values << ('LARGE_SPA_TAIL_CONTENT remains discoverable after many values. ' * 8)
    next_data = JSON.generate(props: { pageProps: { title: 'Large SPA data', values: values } })
    html = <<~HTML
      <html><head><title>Large SPA data</title></head><body>
        <main><h1>Loading</h1></main>
        <script id="__NEXT_DATA__" type="application/json">#{next_data}</script>
      </body></html>
    HTML

    with_page(html) do |page|
      payload = extract_payload(page)

      expect(payload['warnings']).to include('spa_data_traversal_guard')
    end
  end
end
