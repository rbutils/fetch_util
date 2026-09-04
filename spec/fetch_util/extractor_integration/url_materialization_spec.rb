# frozen_string_literal: true

RSpec.describe 'FetchUtil public URL materialization' do
  include_context 'extractor integration helpers'

  def profile_payload(markdown:, html: '<p>Visible profile content</p>', text_content: 'Visible profile content', overrides: {})
    page_html = '<html><head><title>URL materialization</title></head><body><main>Visible page content</main></body></html>'

    with_url_page('https://materialization.example/result', page_html) do |page|
      extract_payload(page, reader_mode: false)
      return page.evaluate(<<~JS)
        (function () {
          window.registerHostAwareProfile(/materialization\.example$/, function () {
            return Object.assign({
              contentType: "article",
              markdown: #{JSON.generate(markdown)},
              html: #{JSON.generate(html)},
              textContent: #{JSON.generate(text_content)},
              readerMode: false,
              siteName: "Materialization Probe"
            }, #{JSON.generate(overrides)});
          });
          return window.FetchUtilExtract.extract({ reader_mode: false });
        })()
      JS
    end
  end

  it 'materializes active Markdown destinations without activating malformed syntax' do
    markdown = <<~'MARKDOWN'
      [Unsafe `literal ] bracket`](javascript:unsafeLabel())
      <a
       href="javascript:unsafeRaw()">Raw multiline action</a>
      <a href="/safe" onclick="unsafeHandler()">Safe raw link</a>
      <//cdn.example.test/inert>
      [Unbalanced](https://example.test/a(b
      [Safe titled link](/guide "Title ) remains")
    MARKDOWN

    output = profile_payload(markdown: markdown)['markdown']

    expect(output).to include(
      'Unsafe `literal ] bracket`',
      '<a>Raw multiline action</a>',
      '<a href="https://materialization.example/safe">Safe raw link</a>',
      '<//cdn.example.test/inert>',
      '[Unbalanced](https://example.test/a(b',
      '[Safe titled link](https://materialization.example/guide "Title ) remains")'
    )
    expect(output).not_to include('javascript:unsafeLabel', 'javascript:unsafeRaw', 'onclick=')
  end

  it 'removes credential-bearing HTTP destinations while preserving visible labels' do
    markdown = <<~'MARKDOWN'
      [Credential link](https://reader:secret@public.example.test/private)
      <https://reader:secret@public.example.test/autolink>
      Bare https://reader:sec'ret@public.example.test/bare reference
      Adjacent https://reader:secret@public.example.test/adjacent,https://writer:token@public.example.test/malformed
      <a href="https://reader:secret@public.example.test/raw">Raw credential link</a>
    MARKDOWN
    html = <<~'HTML'
      <section>
        <a href="https://reader:secret@public.example.test/html">HTML credential link</a>
        <img src="https://reader:secret@public.example.test/image.png" alt="Credential image">
        <p>Visible https://reader:secret@public.example.test/html-text reference</p>
        <pre>Literal https://reader:secret@public.example.test/html-code</pre>
      </section>
    HTML

    payload = profile_payload(
      markdown: markdown,
      html: html,
      text_content: 'Visible https://reader:secret@public.example.test/text reference',
      overrides: {
        title: 'Read https://reader:secret@public.example.test/title',
        excerpt: 'Summary https://reader:secret@public.example.test/excerpt',
        language: 'https://reader:secret@public.example.test/language',
        ingredients: ['https://reader:secret@public.example.test/ingredient']
      }
    )

    expect(payload['markdown']).to include(
      'Credential link', 'Raw credential link', 'https&#58;//public.example.test/autolink',
      "https://public.example.test/bare", 'https://public.example.test/adjacent',
      'https://public.example.test/malformed'
    )
    expect(payload['html']).to include(
      'HTML credential link', 'Credential image', 'https://public.example.test/html-text',
      'https://reader:secret@public.example.test/html-code'
    )
    expect(payload['textContent']).to include('https://public.example.test/text')
    expect(payload.values_at('title', 'excerpt').join).to include(
      'https://public.example.test/title', 'https://public.example.test/excerpt'
    )
    expect(payload['language']).to be_nil
    expect(payload['ingredients']).to eq(['https://public.example.test/ingredient'])
    expect(payload.reject { |key, _value| key == 'html' }.values.join).not_to include(
      'reader', 'secret', "sec'ret", 'writer', 'token', 'public.example.test/private'
    )
  end

  it 'preserves destinations inside CommonMark code and closed raw blocks' do
    markdown = <<~'MARKDOWN'
      <pre>
      [Preformatted literal](javascript:preformatted())
      </pre>

      > quoted item
      >
      >     [Quoted code](javascript:quotedCode())

      - list item

            [List code](javascript:listCode())

      - > ~~~~lang`name
        > [Fenced code](javascript:fencedCode())
        > https://reader:secret@public.example.test/fenced
        > ~~~~

      `https://reader:secret@public.example.test/inline-code`

      [Active action](javascript:active())
    MARKDOWN

    output = profile_payload(markdown: markdown)['markdown']

    expect(output).to include(
      '[Preformatted literal](javascript:preformatted())',
      '>     [Quoted code](javascript:quotedCode())',
      '      [List code](javascript:listCode())',
      '- > ~~~~lang`name',
      '> [Fenced code](javascript:fencedCode())',
      '> https://reader:secret@public.example.test/fenced',
      "  > ~~~~\n",
      '`https://reader:secret@public.example.test/inline-code`',
      'Active action'
    )
    expect(output).not_to include('[Active action](', 'javascript:active')
  end

  it 'ends unclosed fenced code at its opening container boundary' do
    quoted_markdown = <<~'MARKDOWN'
      > ```text
      > [Quoted literal](javascript:quoted())
      [Quoted outside](/quoted-outside)
      [Quoted unsafe](javascript:quotedOutside())
    MARKDOWN
    listed_markdown = <<~'MARKDOWN'
      - ```text
        [List literal](javascript:listed())
      [List outside](/list-outside)
      [List unsafe](javascript:listOutside())
    MARKDOWN
    listed_with_blank_markdown = <<~'MARKDOWN'
      - ```text
        [First literal](javascript:first())

        [Second literal](javascript:second())
        ```

      [List blank unsafe](javascript:blankOutside())
    MARKDOWN
    quoted = profile_payload(markdown: quoted_markdown)['markdown']
    listed = profile_payload(markdown: listed_markdown)['markdown']
    listed_with_blank = profile_payload(markdown: listed_with_blank_markdown)['markdown']

    expect(quoted).to include('[Quoted literal](javascript:quoted())', '[Quoted outside](https://materialization.example/quoted-outside)', 'Quoted unsafe')
    expect(listed).to include('[List literal](javascript:listed())', '[List outside](https://materialization.example/list-outside)', 'List unsafe')
    expect(listed_with_blank).to include('[First literal](javascript:first())', '[Second literal](javascript:second())', 'List blank unsafe')
    expect(quoted).not_to include('javascript:quotedOutside')
    expect(listed).not_to include('javascript:listOutside')
    expect(listed_with_blank).not_to include('javascript:blankOutside')
  end

  it 'removes unclosed executable raw blocks through the end of Markdown' do
    script_output = profile_payload(markdown: "Before script\n\n<script>\n[Hidden](javascript:hidden())\nAfter script")['markdown']
    style_output = profile_payload(markdown: "Before style\n\n<style>\n[Hidden](javascript:hidden())\nAfter style")['markdown']
    pre_output = profile_payload(markdown: "<pre>\n[Literal](javascript:literal())\n[Later](javascript:later())")['markdown']

    expect(script_output).to end_with("Before script\n\n")
    expect(style_output).to end_with("Before style\n\n")
    expect(script_output).not_to include('Hidden', 'After script', 'javascript:hidden')
    expect(style_output).not_to include('Hidden', 'After style', 'javascript:hidden')
    expect(pre_output).to include('<pre>', 'Literal', 'Later')
    expect(pre_output).to include('javascript:literal', 'javascript:later')
  end

  it 'ends unclosed executable raw blocks at their opening container boundary' do
    quoted = profile_payload(markdown: "> <script>\n> hiddenQuoted()\nQuoted outside\n[Quoted link](/quoted-link)")['markdown']
    listed = profile_payload(markdown: "- <style>\n  .hidden { background: unsafeList() }\nList outside\n[List link](/list-link)")['markdown']
    listed_with_blank_markdown = <<~'MARKDOWN'
      - <script>
        hiddenFirst()

        hiddenSecond()
        </script>

      List script outside
      [List safe](/list-safe)
    MARKDOWN
    listed_with_blank = profile_payload(markdown: listed_with_blank_markdown)['markdown']

    expect(quoted).to include('Quoted outside', '[Quoted link](https://materialization.example/quoted-link)')
    expect(listed).to include('List outside', '[List link](https://materialization.example/list-link)')
    expect(listed_with_blank).to include('List script outside', '[List safe](https://materialization.example/list-safe)')
    expect(quoted).not_to include('hiddenQuoted', '<script')
    expect(listed).not_to include('unsafeList', '<style')
    expect(listed_with_blank).not_to include('hiddenFirst', 'hiddenSecond', '<script')
  end

  it 'ends raw HTML blocks on blank lines inside their opening container' do
    markdown = <<~'MARKDOWN'
      > <div>Quoted raw block</div>
      >
      > [Quoted action](javascript:quotedAction())

      - <div>Listed raw block</div>

        [Listed action](javascript:listedAction())
    MARKDOWN

    output = profile_payload(markdown: markdown)['markdown']

    expect(output).to include('Quoted raw block', '> Quoted action', 'Listed raw block', '  Listed action')
    expect(output).not_to include('javascript:quotedAction', 'javascript:listedAction')
  end

  it 'preserves container markers while sanitizing raw HTML blocks' do
    markdown = <<~'MARKDOWN'
      > <div><a href="javascript:quoted()">Quoted action</a></div>
      > <p><a href="/quoted-safe">Quoted safe</a></p>

      - <div><a href="javascript:listed()">Listed action</a></div>
        <p><a href="/listed-safe">Listed safe</a></p>
    MARKDOWN

    output = profile_payload(markdown: markdown)['markdown']

    expect(output).to include(
      '> <div><a>Quoted action</a></div>',
      '> <p><a href="https://materialization.example/quoted-safe">Quoted safe</a></p>',
      '- <div><a>Listed action</a></div>',
      '  <p><a href="https://materialization.example/listed-safe">Listed safe</a></p>'
    )
    expect(output).not_to include('&gt;', 'javascript:quoted', 'javascript:listed')
  end

  it 'leaves malformed destinations and overlong reference labels as literal text' do
    label = 'r' * 1_000
    markdown = <<~MARKDOWN
      [Angle literal](https://example.test/a<b>)
      [Whitespace literal](javascript:alert(one two))
      [#{label}]: javascript:reference()
      [Overlong reference][#{label}]
    MARKDOWN

    output = profile_payload(markdown: markdown)['markdown']

    expect(output).to include(
      '[Angle literal](https://example.test/a<b>)',
      '[Whitespace literal](javascript:alert(one two))',
      "[#{label}]: javascript:reference()",
      "[Overlong reference][#{label}]"
    )
  end

  it 'distinguishes active reference definitions from indented code' do
    active_top = profile_payload(markdown: "   [top-active]: javascript:unsafe()\n[Top active][top-active]")['markdown']
    code_top = profile_payload(markdown: "    [top-code]: javascript:literal()\n\n[Top code][top-code]")['markdown']
    active_list = profile_payload(markdown: "-    [list-active]: javascript:unsafe()\n[List active][list-active]")['markdown']
    code_list = profile_payload(markdown: "-     [list-code]: javascript:literal()\n\n[List code][list-code]")['markdown']

    expect(active_top).to include('[Top active][top-active]')
    expect(active_list).to include('[List active][list-active]')
    expect(active_top).not_to include('[top-active]:', 'javascript:unsafe')
    expect(active_list).not_to include('[list-active]:', 'javascript:unsafe')
    expect(code_top).to include('[Top code][top-code]')
    expect(code_list).to include('[list-code]: javascript:literal()', '[List code][list-code]')
    expect(code_top).not_to include('javascript:')
  end

  it 'does not consume reference continuations outside their opening container' do
    markdown = "> [outside-ref]:\njavascript:outside()\n[Outside reference][outside-ref]"

    output = profile_payload(markdown: markdown)['markdown']

    expect(output).to include('> [outside-ref]:', 'javascript:outside()', '[Outside reference][outside-ref]')
  end

  it 'keeps type-seven raw blocks and paragraph reference text inert' do
    markdown = <<~'MARKDOWN'
      <x-card>
      [Literal raw action](javascript:literalRaw())
      </x-card>

      Visible explanation
      [example]: javascript:shownAsText()
      Visible continuation

      [Safe action](/safe-action)
    MARKDOWN

    output = profile_payload(markdown: markdown)['markdown']

    expect(output).to include(
      '[Literal raw action](javascript:literalRaw())',
      '[example]: javascript:shownAsText()',
      '[Safe action](https://materialization.example/safe-action)'
    )
  end

  it 'removes inline executable raw-text elements' do
    markdown = 'Before <script>unsafeScript()</script> middle <style>.unsafe { color: red }</style> after'

    output = profile_payload(markdown: markdown)['markdown']

    expect(output).to include('Before ', ' middle ', ' after')
    expect(output).not_to include('unsafeScript', '.unsafe', '<script', '</script>', '<style', '</style>')
  end

  it 'removes executable HTML while retaining safe public attributes' do
    html = <<~'HTML'
      <section>
        <a href="/safe" onclick="unsafeClick()">Safe action</a>
        <img src="/safe.png" onerror="unsafeImage()">
        <img imagesrcset="/safe-wide.png 2x, javascript:unsafeWide() 1x">
        <div style="background:u\72l(/pixel)">Styled content</div>
        <style>.hidden { background: url(/hidden.png) }</style>
        <template><a href="/nested" onmouseover="unsafeHover()">Nested action</a><script>unsafeNested()</script></template>
        <svg><a><set attributeName="href" to="javascript:mutated()"></set><text>Mutation target</text></a></svg>
        <script>unsafeTopLevel()</script>
      </section>
    HTML

    output = profile_payload(markdown: 'Visible profile content', html: html)['html']

    expect(output).to include(
      'href="https://materialization.example/safe"',
      'src="https://materialization.example/safe.png"',
      'imagesrcset="https://materialization.example/safe-wide.png 2x"',
      'href="https://materialization.example/nested"',
      'Styled content'
    )
    expect(output).not_to include(
      'style=', '<style', 'onclick=', 'onerror=', 'onmouseover=', '<script', '<set',
      'javascript:mutated', 'unsafeNested', 'unsafeTopLevel', '/pixel', '/hidden.png'
    )
  end

  it 'uses the first safe canonical link in document order' do
    html = <<~HTML
      <html><head><title>Canonical fallback</title>
        <link rel="canonical" href="https://reader:secret@materialization.example/private-canonical">
        <link rel="canonical" href="javascript:unsafeCanonical()">
        <link rel="canonical" href="/safe-canonical">
      </head><body><main><p>Visible canonical content with enough detail for extraction.</p></main></body></html>
    HTML

    with_url_page('https://materialization.example/source', html) do |page|
      payload = extract_payload(page, reader_mode: false)
      expect(payload['canonicalUrl']).to eq('https://materialization.example/safe-canonical')
    end
  end

  it 'does not use unsafe action links as generic-list evidence' do
    cards = 8.times.map do |index|
      %(<article><h2><a href="javascript:action#{index}()">Action #{index + 1}</a></h2><p>Visible explanation #{index + 1} with enough text for the page.</p></article>)
    end.join
    html = "<html><head><title>Action guide</title></head><body><main><h1>Action guide</h1>#{cards}</main></body></html>"

    with_url_page('https://materialization.example/action-guide', html) do |page|
      payload = extract_payload(page)

      expect(payload['contentType']).not_to eq('list')
      expect(payload['markdown']).not_to include('javascript:action')
    end
  end

  it 'keeps distinct unsafe list records with identical visible content' do
    safe_rows = 8.times.map do |index|
      %(<tr><td><a href="/story/#{index}">Safe story #{index + 1}</a><span>Shared context</span></td></tr>)
    end.join
    html = <<~HTML
      <html><head><title>Materialized list</title></head><body><main>
        <table class="itemlist">
          #{safe_rows}
          <tr><td><a href="javascript:firstAction()">Repeated action</a><span>Same detail</span></td></tr>
          <tr><td><a href="javascript:secondAction()">Repeated action</a><span>Same detail</span></td></tr>
        </table>
      </main></body></html>
    HTML

    with_url_page('https://www.ft.com/', html) do |page|
      payload = extract_payload(page)
      expect(payload['contentType']).to eq('list')
      expect(payload['markdown'].scan('Repeated action').length).to eq(2)
      expect(payload['markdown'].scan('Same detail').length).to eq(2)
      expect(payload['markdown']).not_to include('javascript:firstAction', 'javascript:secondAction')
    end
  end

  it 'keeps established generic-list records when only two destinations are safe' do
    safe_cards = 2.times.map do |index|
      %(<article><h2><a href="/safe/#{index}">Safe archive record #{index + 1}</a></h2><p>Shared archive detail</p></article>)
    end.join
    unsafe_cards = 6.times.map do |index|
      %(<article><h2><a href="javascript:action#{index}()">Unsafe archive record #{index + 1}</a></h2><p>Shared archive detail</p></article>)
    end.join
    html = "<html><head><title>Record archive</title></head><body><main><h1>Record archive</h1>#{safe_cards}#{unsafe_cards}</main></body></html>"

    with_url_page('https://archive.example/records', html) do |page|
      payload = extract_payload(page)
      expect(payload['contentType']).to eq('list')
      expect(payload['markdown'].scan(/^## (?:Safe|Unsafe) archive record \d$/).length).to eq(8)
      expect(payload['markdown']).not_to include('javascript:action', 'nullaction')
    end
  end

  it 'keeps unsafe rows in a qualifying linked table without exposing their destinations' do
    safe_rows = 6.times.map do |index|
      %(<tr><td><a href="/build/#{index}">Package #{index + 1}</a></td><td>Target #{index + 1}</td><td>Complete</td></tr>)
    end.join
    html = <<~HTML
      <html><head><title>Build monitor</title></head><body><main><h1>Build monitor</h1>
        <table><thead><tr><th>Package</th><th>Target</th><th>Status</th></tr></thead><tbody>
          #{safe_rows}
          <tr><td><a href="javascript:retryBuild()">Retry package</a></td><td>Target retry</td><td>Pending</td></tr>
        </tbody></table>
      </main></body></html>
    HTML

    with_url_page('https://builds.example/monitor', html) do |page|
      payload = extract_payload(page)

      expect(payload['contentType']).to eq('list')
      expect(payload['markdown']).to include('Retry package', 'Target: Target retry', 'Status: Pending')
      expect(payload['markdown']).not_to include('javascript:retryBuild')
    end
  end

  it 'preserves identical rendered list records after semantic destination dedupe' do
    consecutive = 4.times.map do |index|
      href = if index < 2
               variant = index.zero? ? 'A' : 'a'
               "javascript:retry('#{variant}')"
             else
               "javascript:consecutive#{index}()"
             end
      %(<li><h2><a href="#{href}">Repeated visible record</a></h2><p>Identical visible detail</p></li>)
    end.join
    interleaved = 4.times.map do |index|
      unsafe_card = %(<li><h2><a href="javascript:interleaved#{index}()">Interleaved visible record</a></h2><p>Shared interleaved detail</p></li>)
      safe_card = %(<li><h2><a href="/separator/#{index}">Safe separator record #{index + 1}</a></h2><p>Separator detail</p></li>)
      "#{unsafe_card}#{safe_card}"
    end.join
    safe_cards = 2.times.map do |index|
      %(<li><h2><a href="/anchor/#{index}">Safe anchor record #{index + 1}</a></h2><p>Anchor detail</p></li>)
    end.join
    html = <<~HTML
      <html><head><title>Visible record archive</title></head><body><main><h1>Visible record archive</h1>
        <ul>#{safe_cards}#{consecutive}#{interleaved}</ul>
      </main></body></html>
    HTML

    with_url_page('https://archive.example/visible-records', html) do |page|
      payload = extract_payload(page)

      expect(payload['markdown'].scan('Repeated visible record').length).to eq(4)
      expect(payload['markdown'].scan('Interleaved visible record').length).to eq(4)
      expect(payload['markdown']).not_to include('javascript:consecutive', 'javascript:interleaved')
    end
  end

  it 'keeps non-heading unsafe cards in established sections' do
    sections = 2.times.map do |section_index|
      safe_cards = 3.times.map do |card_index|
        %(<article><h3><a href="/section/#{section_index}/#{card_index}">Safe section record #{section_index + 1}-#{card_index + 1}</a></h3><p>Safe context</p></article>)
      end.join
      unsafe_card = <<~HTML
        <article><a href="javascript:section#{section_index}()">Unsafe section record #{section_index + 1}</a>
          <p>Unsafe section context #{section_index + 1}</p>
        </article>
      HTML
      "<section><h2>Section #{section_index + 1}</h2>#{safe_cards}#{unsafe_card}</section>"
    end.join
    html = "<html><head><title>Section archive</title></head><body><main><h1>Section archive</h1>#{sections}</main></body></html>"

    with_url_page('https://archive.example/sections', html) do |page|
      payload = extract_payload(page)

      expect(payload['contentType']).to eq('list')
      expect(payload['markdown']).to include('Unsafe section record 1', 'Unsafe section record 2')
      expect(payload['markdown']).not_to include('javascript:section')
    end
  end

  it 'preserves distinct cross-section records that share a destination' do
    html = <<~HTML
      <html><head><title>Release archive</title></head><body><main><h1>Release archive</h1>
        <section><h2>Spring releases</h2>
          <article><h3><a href="/record">Spring release</a></h3><time>2026-03-01</time><p>Spring context</p></article>
        </section>
        <section><h2>Autumn releases</h2>
          <article><h3><a href="/record">Autumn release</a></h3><time>2026-09-01</time><p>Autumn context</p></article>
          <article><h3><a href="/record">Winter release</a></h3><time>2026-12-01</time><p>Winter context</p></article>
          <article><h3><a href="/record">Spring release</a></h3><time>2026-03-01</time><p>Spring context</p></article>
        </section>
      </main></body></html>
    HTML

    with_url_page('https://archive.example/releases', html) do |page|
      payload = extract_payload(page)
      markdown = payload['markdown']

      expect(payload['contentType']).to eq('list')
      expect(markdown).to include('## Spring releases', '## Autumn releases')
      expect(markdown.scan('](https://archive.example/record)').length).to eq(3)
      expect(markdown.index('Spring release')).to be < markdown.index('Autumn release')
      expect(markdown.index('Autumn release')).to be < markdown.index('Winter release')
    end
  end

  it 'keeps unsafe-only headline records selected by fallback extraction' do
    safe_cards = 8.times.map do |index|
      %(<article><a href="/safe-fallback/#{index}">Safe item #{index + 1}</a></article>)
    end.join
    unsafe_cards = 4.times.map do |index|
      %(<article><a href="javascript:fallback#{index}()">Risk item #{index + 1}</a></article>)
    end.join
    html = "<html><head><title>Fallback archive</title></head><body><main><h1>Fallback archive</h1>#{safe_cards}#{unsafe_cards}</main></body></html>"

    with_url_page('https://archive.example/fallback', html) do |page|
      payload = extract_payload(page)

      expect(payload['contentType']).to eq('list')
      expect(payload['markdown'].scan(/Risk item \d/).length).to eq(4)
      expect(payload['markdown']).not_to include('javascript:fallback')
    end
  end
end
