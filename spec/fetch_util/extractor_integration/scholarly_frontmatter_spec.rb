# frozen_string_literal: true

RSpec.describe 'FetchUtil scholarly frontmatter ownership' do
  include_context 'extractor integration helpers'

  def scholarly_frontmatter_probe_source
    root = File.expand_path('../../..', __dir__)
    source = File.readlines(File.join(root, 'websieve/manifest.txt'), chomp: true)
                 .reject { |line| line.empty? || line.start_with?('#') }
                 .map { |path| File.read(File.join(root, 'websieve', path)) }.join("\n")
    source.sub('})(window);', <<~JAVASCRIPT)
      global.probeGenericScholarlyRecord = function() {
        return genericScholarlyArticleContent(collectMetadata());
      };
      })(window);
    JAVASCRIPT
  end

  def extract_scholarly_frontmatter(html)
    with_url_page('https://journal.example.test/article', html) do |page|
      page.add_script_tag(content: scholarly_frontmatter_probe_source)
      page.evaluate('probeGenericScholarlyRecord()')
    end
  end

  it 'retains a distinct short source-owned abstract group in frontmatter order' do
    body = 'The study describes observed cellular changes and compares tissue repair across measured regions. '
    html = <<~HTML
      <html><head><title>Immune recovery</title><meta name="citation_doi" content="10.5555/frontmatter"></head><body>
        <article typeof="ScholarlyArticle">
          <h1>Immune recovery</h1>
          <div data-extent="frontmatter">
            <section property="abstract" role="doc-abstract"><h2 property="name">Highlights</h2>
              <p>Macrophage and stromal niches coordinate tissue regeneration.</p>
            </section>
            <section property="abstract" role="doc-abstract"><h2 property="name">Summary</h2>
              <p>#{body * 2}</p>
            </section>
            <section class="abstract-mobile" style="display:none" property="abstract" role="doc-abstract">
              <h2 property="name">Summary</h2><p>Hidden responsive duplicate must not be emitted.</p>
            </section>
          </div>
          <section property="articleBody"><section id="sec1"><h2>Results</h2><p>#{body * 3}</p></section></section>
          <aside class="recommendations"><section role="doc-abstract"><h2>Related abstract</h2>
            <p>Foreign recommendation abstract must stay outside this scholarly record.</p>
          </section></aside>
        </article>
      </body></html>
    HTML

    payload = extract_scholarly_frontmatter(html)
    rendered = payload.fetch('html')
    expect(rendered).to include('Macrophage and stromal niches coordinate tissue regeneration.', 'Summary', 'Results')
    expect(rendered.index('Macrophage and stromal niches')).to be < rendered.index('observed cellular changes')
    expect(rendered.scan('Macrophage and stromal niches coordinate tissue regeneration.').length).to eq(1)
    expect(payload.fetch('excerpt')).to include(body.strip, 'observed cellular changes')
    expect(payload.fetch('excerpt')).not_to include('Macrophage and stromal niches')
    expect(rendered).not_to include('Hidden responsive duplicate', 'Foreign recommendation abstract')
  end
end
