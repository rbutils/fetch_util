# frozen_string_literal: true

RSpec.describe 'FetchUtil extractor integration' do
  include_context 'extractor integration helpers'

  it 'separates directly adjacent labelled anchors without changing other inline boundaries' do
    html = <<~HTML
      <html>
        <head>
          <title>Link spacing report</title>
          <style>.css-hidden-group { display: none; }</style>
        </head>
        <body>
          <main>
            <article>
              <h1>Link spacing report</h1>
              <p>Article prose provides enough context for the linked labels that follow.</p>
              <p class="tags"><a>Alpha</a><a>Beta</a></p>
              <p class="topic-list"><a href="/one">One</a><a href="/two">Two</a></p>
              <p><a class="tag">Tagged</a><a>Ordinary</a></p>
              <p class="not-tags"><a>Not</a><a>Tags</a></p>
              <p><a href="/plain-one">Plain one</a><a href="/plain-two">Plain two</a></p>
              <p><a href="/tokyo">東京</a><a href="/university">大学</a></p>
              <p><a href="/area">555</a><a href="/number">1234</a></p>
              <p><a href="/three">Three</a>,<a href="/four">Four</a></p>
              <p class="tags"><a>One</a><a>,Two</a></p>
              <p class="tags"><a>Fullwidth</a><a>，punctuation</a></p>
              <p class="tags"><a>Period</a><a>．punctuation</a></p>
              <p class="tags"><a>Language</a><a>%python</a></p>
              <p class="tags"><a>Quote</a><a>&quot;punctuation</a></p>
              <p class="tags"><a>Dash</a><a>-punctuation</a></p>
              <p class="tags"><a>Read more</a><a>Tag</a></p>
              <p class="tags"><a>Read more!</a><a>Topic</a></p>
              <p class="tags"><a>Alert!</a><a>Next topic</a></p>
              <p class="tags"><a>Quote“</a><a>word</a></p>
              <p class="tags"><a href="/five">Five</a> <a href="/six">Six</a></p>
              <p class="tags"><a href="/empty"></a><a href="/seven">Seven</a></p>
              <p class="tags"><a href="/hidden"><span hidden>Hidden</span></a><a href="/visible">Visible</a></p>
              <p class="tags" hidden><a>Ancestor</a><a>hidden</a></p>
              <p class="tags" style="visibility: hidden"><a>Styled</a><a>hidden</a></p>
              <p class="css-hidden-group"><a class="tag">Computed</a><a class="tag">hidden</a></p>
              <p class="tags"><a href="/comment-one">Comment one</a><!-- boundary --><a href="/comment-two">Comment two</a></p>
              <p><a rel="tag" href="/rel-one">Rel one</a><a rel="tag" href="/rel-two">Rel two</a></p>
              <p class="chips"><a href="/image-one"><img src="/one.png" alt="Image one"></a><a href="/image-two"><img src="/two.png" alt="Image two"></a></p>
              <pre class="tags"><code><a>left</a><a>right</a></code></pre>
            </article>
          </main>
        </body>
      </html>
    HTML

    with_url_page('https://example.com/link-spacing', html) do |page|
      before = page.evaluate('document.body.outerHTML')
      markdown = extract_payload(page, reader_mode: false).fetch('markdown')

      expect(markdown).to include(
        'Alpha Beta',
        '[One](https://example.com/one) [Two](https://example.com/two)',
        'TaggedOrdinary',
        'NotTags',
        '[Plain one](https://example.com/plain-one)[Plain two](https://example.com/plain-two)',
        '[東京](https://example.com/tokyo)[大学](https://example.com/university)',
        '[555](https://example.com/area)[1234](https://example.com/number)',
        '[Three](https://example.com/three),[Four](https://example.com/four)',
        'One,Two',
        'Fullwidth，punctuation',
        'Period．punctuation',
        'Language %python',
        'Quote"punctuation',
        'Dash\\-punctuation',
        'Read moreTag',
        'Read more!Topic',
        'Alert! Next topic',
        'Quote“word',
        '[Five](https://example.com/five) [Six](https://example.com/six)',
        '[Seven](https://example.com/seven)',
        '[Visible](https://example.com/visible)',
        '[Comment one](https://example.com/comment-one)[Comment two](https://example.com/comment-two)',
        '[Rel one](https://example.com/rel-one) [Rel two](https://example.com/rel-two)',
        '[![Image one](https://example.com/one.png)](https://example.com/image-one) [![Image two](https://example.com/two.png)](https://example.com/image-two)',
        "```\nleftright\n```"
      )
      expect(page.evaluate('document.body.outerHTML')).to eq(before)
      expect(markdown).not_to include('Ancestor', 'Styled', 'Computed')
    end
  end

  it 'does not change list record discovery for adjacent tag-styled links' do
    rows = (1..8).map do |index|
      <<~HTML
        <tr class="athing"><td>
          <a class="tag" href="https://example.com/stories/#{index}">Story #{index}</a><a class="tag" href="https://example.com/topics/#{index}">Topic #{index}</a>
        </td></tr>
        <tr><td>Independent story #{index} has enough local detail to remain a material list record.</td></tr>
      HTML
    end.join

    with_url_page('https://example.com/', <<~HTML) do |page|
      <!doctype html>
      <html><head><title>Topic stories</title></head>
      <body><main><h1>Topic stories</h1><table class="itemlist">#{rows}</table></main></body></html>
    HTML
      source = page.evaluate('document.body.outerHTML')
      result = extract_payload(page, reader_mode: false)

      expect(result['contentType']).to eq('list')
      record_lines = result['markdown'].lines.grep(/\A\| \[Story \d+\]/)
      expect(record_lines.length).to eq(8)
      expect(record_lines.map { |line| line[/Story \d+/] }).to eq((1..8).map { |index| "Story #{index}" })
      expect(record_lines.map { |line| line[/Topic \d+/] }).to eq((1..8).map { |index| "Topic #{index}" })
      detail_lines = result['markdown'].lines.grep(/\A\| Independent story \d+/)
      expect(detail_lines.map { |line| line[/Independent story \d+/] }).to eq((1..8).map { |index| "Independent story #{index}" })
      expect(result['markdown'].scan(%r{https://example\.com/stories/\d})).to eq((1..8).map { |index| "https://example.com/stories/#{index}" })
      expect(page.evaluate('document.body.outerHTML')).to eq(source)
    end
  end
end
