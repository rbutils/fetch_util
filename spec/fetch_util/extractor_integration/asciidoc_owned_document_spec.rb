# frozen_string_literal: true

RSpec.describe 'FetchUtil extractor integration - generated technical document ownership' do
  include_context 'extractor integration helpers'

  def generated_owner_source
    root = File.expand_path('../../..', __dir__)
    paths = File.readlines(File.join(root, 'websieve/manifest.txt'), chomp: true)
                .reject { |line| line.empty? || line.start_with?('#') }
    source = paths.map { |path| File.read(File.join(root, 'websieve', path)) }.join("\n")
    source.sub('})(window);', <<~JAVASCRIPT)
      global.generatedDocsOwner = asciidocDocsContext;
      })(window);
    JAVASCRIPT
  end

  def expect_no_generated_owner(url, html)
    with_url_page(url, html) do |page|
      page.add_script_tag(content: generated_owner_source)
      expect(page.evaluate('generatedDocsOwner({title: document.title}) === null')).to be(true)
    end
  end

  def generated_document(body, header: '<h1>Ownership reference</h1>', generator: 'Asciidoctor 2.0.23', extra: '')
    <<~HTML
      <html><head><title>Ownership reference</title><meta name="generator" content="#{generator}"></head>
      <body><div id="header">#{header}</div><div id="content">#{body}</div>#{extra}</body></html>
    HTML
  end

  def technical_sections(count)
    (1..count).map do |index|
      <<~HTML
        <div class="sect1" id="section-#{index}"><h2>Ownership section #{index}</h2>
        <p>Record #{index} explains the complete lifetime of an owned resource and its independently published reference.
        Consult <a href="/resources/#{index}">resource #{index}</a> before applying the documented operation.</p>
        <div class="listingblock"><pre><code data-lang="ruby">resource_#{index} = acquire(#{index})
        release(resource_#{index})</code></pre></div>
        <table><tr><th>Record</th><th>Value</th></tr><tr><td>#{index}</td><td>value-#{index}</td></tr></table></div>
      HTML
    end.join
  end

  it 'retains every source-owned section, code example, table, resource and printed header' do
    sections = technical_sections(240)
    toc = (1..240).map { |index| "<li><a href=\"#section-#{index}\">Section #{index}</a></li>" }.join
    header = <<~HTML
      <h1>Ownership reference</h1><div class="details"><span>Prepared by Example Author</span></div>
      <div id="toc"><div id="toctitle">Table of Contents</div><ul>#{toc}</ul></div>
    HTML
    authored = <<~HTML
      <blockquote><p>The subscription interface must preserve privacy policy references and published replies.</p></blockquote>
      <p><a href="/policy">privacy policy</a></p>
    HTML
    footer = '<footer><p>Unrelated service catalogue</p></footer>'
    html = generated_document(sections + authored, header: header, extra: footer)

    with_url_page('https://publication.example.test/docs/ownership.html', html) do |page|
      page.add_script_tag(content: generated_owner_source)
      expect(page.evaluate('generatedDocsOwner({title: document.title}) !== null')).to be(true)
      payload = extract_payload(page)
      expect(payload['html']).to include('Prepared by Example Author')
      expect(payload['contentType']).to eq('article')
      expect(payload['hostAware']).to be(false)
      expect(payload['readerMode']).to be(false)
      expect(payload['html'].scan('<pre').length).to eq(240)
      expect(payload['html'].scan('<table').length).to eq(240)
      (1..240).each do |index|
        expect(payload['html']).to include("Ownership section #{index}", "resource_#{index} = acquire(#{index})", "value-#{index}")
        expect(payload['markdown']).to include("resource_#{index} = acquire(#{index})", "release(resource_#{index})", "value-#{index}")
        expect(payload['html']).to include("/resources/#{index}")
      end
      expect(payload['markdown']).to include('Prepared by Example Author', 'published replies', '[privacy policy]')
      expect(payload['markdown']).not_to include('Table of Contents', 'Unrelated service catalogue')
    end
  end

  it 'does not use a fragment to discard the other complete authored sections' do
    html = generated_document(technical_sections(3))
    extract_from_url('https://publication.example.test/docs/ownership.html#section-2', html) do |payload|
      expect(payload['readerMode']).to be(false)
      (1..3).each { |index| expect(payload['markdown']).to include("Ownership section #{index}") }
    end
  end

  it 'declines hidden, conflicting and ambiguous generated owners' do
    body = technical_sections(2)
    ordinary = generated_document(body)
    variants = [
      ordinary.sub('id="content"', 'id="content" hidden'),
      ordinary.sub('<h1>Ownership reference</h1>', '<h1>Foreign title</h1>'),
      ordinary.sub('</body>', '<div id="content">Foreign body</div></body>'),
      ordinary.sub('</head>', '<meta name="generator" content="Other generator"></head>')
    ]
    variants.each do |html|
      expect_no_generated_owner('https://publication.example.test/docs/ownership.html', html)
    end
  end

  it 'does not classify literary articles by their generator or layout alone' do
    literary = '<div class="sect1"><h2>The next chapter</h2><p>A complete fictional account of the journey and its characters.</p></div>'
    expect_no_generated_owner('https://publication.example.test/docs/chapter.html', generated_document(literary))
    expect_no_generated_owner('https://publication.example.test/features/chapter.html', generated_document(technical_sections(1)))
  end
end
