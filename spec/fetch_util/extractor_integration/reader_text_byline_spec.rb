# frozen_string_literal: true

RSpec.describe 'reader text byline preservation' do
  include_context 'extractor integration helpers'

  def text_byline_article(metadata_author: 'Alice Brown', visible_byline: 'By Alice Brown', extra_header: '', body_owner: '')
    <<~HTML
      <html><head>
        <title>Regional culture program expands</title>
        <meta name="author" content="#{metadata_author}">
      </head><body><main><article class="#{body_owner}">
        <h1>Regional culture program expands</h1>
        <h2>Community organizations are preparing a larger regional culture program for the coming year.</h2>
        <div class="article-content">
          <div class="article-meta">
            #{extra_header}
            <div class="article-byline">#{visible_byline}</div>
          </div>
          <p>The regional culture program is expanding with new venues, workshops, and public events developed with community organizations.</p>
          <p>Organizers said the next phase will support local artists while giving residents more opportunities to participate throughout the year.</p>
          <p>Schools, libraries, and neighborhood groups will publish a shared calendar as each part of the program opens to the public.</p>
        </div>
      </article></main></body></html>
    HTML
  end

  it 'preserves one verified visible byline omitted by reader mode' do
    path = File.expand_path('../../fixtures/hindustantimes_article.html', __dir__)

    with_url_page('https://example.test/opinion/hindi-future.html', File.read(path)) do |page|
      before = page.evaluate('document.body.innerHTML')
      payload = extract_payload(page)

      expect(payload).to include('byline' => 'Girish Nath Jha', 'readerMode' => true)
      expect(payload['markdown']).to include("# Hindi, and its role in the unified future of India\n\nBy Girish Nath Jha")
      expect(payload['markdown'].scan('By Girish Nath Jha').length).to eq(1)
      expect(payload['html']).to include('<p data-fetchutil-reader-byline="">By Girish Nath Jha</p>')
      expect(payload['textContent']).to include('By Girish Nath Jha')
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end

  it 'requires matching metadata, reader, and source identities' do
    mismatched = text_byline_article(metadata_author: 'Alice Brown', visible_byline: 'By Carol Davis')
    body_mention = text_byline_article(visible_byline: 'Editorial desk')

    extract_from_url('https://example.test/culture/mismatched', mismatched) do |payload|
      expect(payload['html']).not_to include('data-fetchutil-reader-byline')
    end
    extract_from_url('https://example.test/culture/body-mention', body_mention) do |payload|
      expect(payload['markdown']).not_to include('By Alice Brown')
    end
  end

  it 'rejects linked, related, comment-owned, and conflicting source bylines' do
    linked = text_byline_article(visible_byline: '<a href="/authors/alice">By Alice Brown</a>')
    related = text_byline_article(body_owner: 'related-stories')
    commented = text_byline_article(extra_header: '<div class="comments"><div class="byline">By Alice Brown</div></div>')

    [linked, related, commented].each_with_index do |html, index|
      extract_from_url("https://example.test/culture/rejected-#{index}", html) do |payload|
        expect(payload['html']).not_to include('data-fetchutil-reader-byline')
      end
    end
  end

  it 'rejects duplicate, hidden, self-owned, and narrative author markers' do
    variants = [
      '<div class="byline">By Alice Brown</div><div class="byline">By Alice Brown</div>',
      '<div aria-hidden="true"><div class="byline">By Alice Brown</div></div>',
      '<div style="display:none"><div class="byline">By Alice Brown</div></div>',
      '<div style="opacity:0"><div class="byline">By Alice Brown</div></div>',
      '<div class="related-byline">By Alice Brown</div>',
      '<div class="comments"><div class="byline">By Alice Brown</div></div>',
      '<p>Discussion: <span class="author">By Alice Brown</span></p>',
      '<div class="story-narrative"><span class="author">By Alice Brown</span><span> reports from the region.</span></div>',
      '<div class="story-narrative"><div class="author">By Alice Brown</div><span> reports from the region.</span></div>',
      '<div class="article-copy"><p class="author">By Alice Brown</p><span> reports from the region.</span></div>',
      '<div class="article-meta"><span class="author">By Alice Brown</span><span> reports from the region.</span></div>',
      '<div class="story-narrative byline">By Alice Brown</div>',
      '<div class="byline">By Alice Brown</div><p>By Alice Brown</p>'
    ]

    variants.each_with_index do |visible_byline, index|
      html = text_byline_article(visible_byline: visible_byline)
      extract_from_url("https://example.test/culture/adversarial-#{index}", html) do |payload|
        expect(payload['html']).not_to include('data-fetchutil-reader-byline'), "adversarial variant #{index}"
      end
    end
  end

  it 'does not let body mentions or fenced code suppress the verified byline' do
    html = text_byline_article
           .sub('<p>The regional culture program', '<pre><code>By Alice Brown</code></pre><p>The regional culture program')
           .sub('<p>Schools, libraries, and neighborhood groups', '<p>Alice Brown</p><p>Schools, libraries, and neighborhood groups')

    extract_from_url('https://example.test/culture/represented-name', html) do |payload|
      expect(payload['markdown']).to start_with("# Regional culture program expands\n\nBy Alice Brown")
      expect(payload['markdown']).to include("\nAlice Brown\n")
      expect(payload['markdown']).to include("By Alice Brown\n```")
    end
  end

  it 'accepts one nested semantic marker owned by the same visible byline' do
    variants = [
      '<div class="article-byline"><span itemprop="author"><span itemprop="name">By Alice Brown</span></span><time>2024-09-13</time></div>',
      '<div data-testid="byline">By Alice Brown</div>',
      '<div class="article-meta"><span class="byline">By Alice Brown</span> | Sep 13, 2024</div>'
    ]

    variants.each_with_index do |visible_byline, index|
      html = text_byline_article(visible_byline: visible_byline)
      extract_from_url("https://example.test/culture/semantic-byline-#{index}", html) do |payload|
        expect(payload['markdown']).to start_with("# Regional culture program expands\n\nBy Alice Brown")
        expect(payload['markdown'].scan('By Alice Brown').length).to eq(1)
        expect(payload['textContent']).to include('By Alice Brown')
      end
    end
  end

  it 'does not let a long markdown title hide an existing byline' do
    title = 'Regional culture institutions coordinate a deliberately long public program across the entire country'
    html = text_byline_article
           .sub('<title>Regional culture program expands</title>', "<title>#{title}</title>")
           .sub('<h1>Regional culture program expands</h1>', "<h1>#{title}</h1>")

    extract_from_url('https://example.test/culture/long-title-byline', html) do |payload|
      expect(payload['markdown'].scan('By Alice Brown').length).to eq(1)
    end
  end

  it 'does not let a long markdown resource hide an existing byline' do
    label = 'Related reporting and background material with a deliberately long descriptive resource title'
    html = text_byline_article(extra_header: %(<p><a href="/background">#{label}</a></p>))

    extract_from_url('https://example.test/culture/long-resource-byline', html) do |payload|
      expect(payload['markdown']).to include("[#{label}](https://example.test/background)")
      expect(payload['markdown'].scan('By Alice Brown').length).to eq(1)
    end
  end

  it 'does not mistake an exact-author resource for the visible byline' do
    path = File.expand_path('../../fixtures/hindustantimes_article.html', __dir__)
    html = File.read(path).sub(
      '<p>Hindi Divas (Hindi Day)',
      '<figure><a href="/source-note">By Girish Nath Jha</a></figure><p>Hindi Divas (Hindi Day)'
    )

    extract_from_url('https://example.test/opinion/author-resource.html', html) do |payload|
      expect(payload['markdown']).to start_with("# Hindi, and its role in the unified future of India\n\nBy Girish Nath Jha")
      expect(payload['markdown']).to include('[By Girish Nath Jha](https://example.test/source-note)')
      expect(payload['markdown'].scan('By Girish Nath Jha').length).to eq(2)
    end
  end

  it 'synchronizes text content when selected HTML already represents the byline' do
    html = text_byline_article

    with_url_page('https://example.test/culture/html-represented-byline', html) do |page|
      extract_payload(page)
      page.evaluate(<<~JS)
        () => {
          const articleHtml = `
            <h1>Regional culture program expands</h1>
             <p class="byline"><span>By Alice Brown</span></p>
            <p>The regional culture program is expanding with new venues, workshops, and public events developed with community organizations.</p>
            <p>Organizers said the next phase will support local artists while giving residents more opportunities to participate throughout the year.</p>
            <p>Schools, libraries, and neighborhood groups will publish a shared calendar as each part of the program opens to the public.</p>`;
          window.Readability = function() {
            this.parse = () => ({
              title: 'Regional culture program expands',
              byline: 'Alice Brown',
              excerpt: null,
              siteName: null,
              publishedTime: null,
              content: articleHtml,
              textContent: 'The regional culture program is expanding with new venues, workshops, and public events developed with community organizations. Organizers said the next phase will support local artists while giving residents more opportunities to participate throughout the year. Schools, libraries, and neighborhood groups will publish a shared calendar as each part of the program opens to the public.'
            });
          };
        }
      JS

      payload = page.evaluate('window.FetchUtilExtract.extract({ reader_mode: true })')
      expect(payload['html'].scan('By Alice Brown').length).to eq(1)
      expect(payload['html']).not_to include('data-fetchutil-reader-byline')
      expect(payload['markdown'].scan('By Alice Brown').length).to eq(1)
      normalized_text = payload['textContent'].split(/\s+/).join(' ').strip
      expect(normalized_text).to start_with('By Alice Brown ')
    end
  end

  it 'does not duplicate an already synchronized text-content prefix' do
    html = text_byline_article

    with_url_page('https://example.test/culture/text-prefix', html) do |page|
      extract_payload(page)
      page.evaluate(<<~JS)
        () => {
          const articleHtml = `
            <h1>Regional culture program expands</h1>
            <p class="byline">By Alice Brown</p>
            <p>The regional culture program is expanding with new venues, workshops, and public events developed with community organizations.</p>
            <p>Organizers said the next phase will support local artists while giving residents more opportunities to participate throughout the year.</p>
            <p>Schools, libraries, and neighborhood groups will publish a shared calendar as each part of the program opens to the public.</p>`;
          const bodyText = 'The regional culture program is expanding with new venues, workshops, and public events developed with community organizations. Organizers said the next phase will support local artists while giving residents more opportunities to participate throughout the year. Schools, libraries, and neighborhood groups will publish a shared calendar as each part of the program opens to the public.';
          window.Readability = function() {
            this.parse = () => ({
              title: 'Regional culture program expands',
              byline: 'Alice Brown',
              excerpt: null,
              siteName: null,
              publishedTime: null,
              content: articleHtml,
              textContent: 'By Alice Brown\\n\\n' + bodyText
            });
          };
        }
      JS

      payload = page.evaluate('window.FetchUtilExtract.extract({ reader_mode: true })')
      expect(payload['textContent'].scan('By Alice Brown').length).to eq(1)

      page.evaluate(<<~JS)
        () => {
          const parsed = new window.Readability().parse();
          parsed.textContent = parsed.textContent.replace(/^By Alice Brown\s*/, '') + '\\nBy Alice Brown';
          window.Readability = function() { this.parse = () => parsed; };
        }
      JS
      reordered_payload = page.evaluate('window.FetchUtilExtract.extract({ reader_mode: true })')
      expect(reordered_payload['textContent'].scan('By Alice Brown').length).to eq(1)
    end
  end

  it 'does not duplicate an exact text-content byline when selected HTML omits it' do
    html = text_byline_article

    with_url_page('https://example.test/culture/text-only-represented-byline', html) do |page|
      extract_payload(page)
      page.evaluate(<<~JS)
        () => {
          const articleHtml = `
            <h1>Regional culture program expands</h1>
            <p>The regional culture program is expanding with new venues, workshops, and public events developed with community organizations.</p>
            <p>Organizers said the next phase will support local artists while giving residents more opportunities to participate throughout the year.</p>
            <p>Schools, libraries, and neighborhood groups will publish a shared calendar as each part of the program opens to the public.</p>`;
          const bodyText = 'The regional culture program is expanding with new venues, workshops, and public events developed with community organizations. Organizers said the next phase will support local artists while giving residents more opportunities to participate throughout the year. Schools, libraries, and neighborhood groups will publish a shared calendar as each part of the program opens to the public.';
          window.Readability = function() {
            this.parse = () => ({
              title: 'Regional culture program expands',
              byline: 'Alice Brown',
              excerpt: null,
              siteName: null,
              publishedTime: null,
              content: articleHtml,
              textContent: bodyText + '\\nBy Alice Brown'
            });
          };
        }
      JS

      payload = page.evaluate('window.FetchUtilExtract.extract({ reader_mode: true })')
      expect(payload['html'].scan('By Alice Brown').length).to eq(1)
      expect(payload['markdown']).to start_with("# Regional culture program expands\n\nBy Alice Brown")
      expect(payload['textContent'].scan('By Alice Brown').length).to eq(1)
    end
  end

  it 'does not supplement without two uniquely mapped focal paragraphs' do
    html = text_byline_article
           .sub(%r{<p>Organizers.*?</p>}, '')
           .sub(%r{<p>Schools.*?</p>}, '')

    extract_from_url('https://example.test/culture/short', html) do |payload|
      expect(payload['html']).not_to include('data-fetchutil-reader-byline')
    end
  end
end
