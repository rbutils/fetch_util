# frozen_string_literal: true

RSpec.describe 'Physical collection section heading ownership' do
  include_context 'extractor integration helpers'

  def section_records(linked: false)
    [1, 2, 3, 4, 1].map do |number|
      if linked
        <<~HTML
          <div class="story-card">
            <a href="/reports/#{number}"><img src="/covers/#{number}.png" alt="Cover #{number}"></a>
            <h2><a href="/reports/#{number}">Field report #{number}</a></h2>
            <p>Published June #{number}, 2026</p>
          </div>
        HTML
      else
        <<~HTML
          <div class="story-card">
            <img src="/covers/#{number}.png" alt="Cover #{number}">
            <h2>Field report #{number}</h2>
            <p>Published June #{number}, 2026</p><a href="/reports/#{number}">Read field report</a>
          </div>
        HTML
      end
    end.join
  end

  def section_page(heading: '<div id="section-label"><h2>Recent field reports</h2></div>', before: '', after: '', owner: 'div', linked: false)
    <<~HTML
      <html><head><title>Publication archive</title></head><body><form id="page-shell">
        <#{owner} id="publication-section">
          <div id="section-target"></div>#{heading}#{before}
          <div id="record-branch"><span><div><div>
            <div><span id="records">#{section_records(linked: linked)}</span></div>
            <div aria-label="Collection navigation"><span></span><span></span></div>
          </div></div><script type="text/javascript">window.collectionReady = true;</script></span>
          <div style="display:none"><a href="javascript:void(0)">Previous</a><a href="javascript:void(0)">Next</a></div></div>
          #{after}
        </#{owner}>
      </form></body></html>
    HTML
  end

  def section_context_probe
    root = File.expand_path('../../..', __dir__)
    names = File.readlines(File.join(root, 'websieve/manifest.txt')).map(&:strip)
    names.reject! { |name| name.empty? || name.start_with?('#') }
    source = names.map { |name| File.read(File.join(root, 'websieve', name)) }.join("\n")
    boundary = '})(window);'
    raise 'ambiguous section probe boundary' unless source.scan(boundary).length == 1

    probe = <<~JS
      global.__sectionContextProbe = function() {
        return withSourceVisibilityRead(function() {
          var context = pageOwnedRenderContext(document.querySelector('#records'), {title: document.title});
          if (!context) return null;
          return {owner: context.owner.id, nodes: context.nodes.map(function(node) { return node.id; }),
            headings: context.nodes.flatMap(function(node) {
              var headings = node.matches('h1,h2,h3,h4,h5,h6') ? [node] : Array.from(node.querySelectorAll('h1,h2,h3,h4,h5,h6'));
              return headings.map(function(heading) { return [heading.localName, heading.textContent]; });
            })};
        });
      };
    JS
    "(() => {\n#{source.sub(boundary, probe + boundary)}\nreturn window.__sectionContextProbe();\n})()"
  end

  it 'retains the owned section heading and every independent record through ordinary extraction' do
    with_url_page('https://records.publication.example.test/archive/', section_page) do |page|
      body = page.evaluate('document.body.innerHTML')
      payload = extract_payload(page)
      output = Nokogiri::HTML5.fragment(payload.fetch('html'))
      expected_titles = ['Recent field reports', *[1, 2, 3, 4, 1].map { |number| "Field report #{number}" }]
      expect(output.css('h2').map(&:text)).to eq(expected_titles)
      expect(output.css('p').map(&:text)).to eq([1, 2, 3, 4, 1].map { |number| "Published June #{number}, 2026" })
      expect(output.css('img').map { |image| image['alt'] }).to eq([1, 2, 3, 4, 1].map { |number| "Cover #{number}" })
      markdown = payload.fetch('markdown')
      expect(markdown).to include('## Recent field reports')
      expect(markdown.index('## Recent field reports')).to be < markdown.index('Field report 1')
      expect(markdown.scan('](https://records.publication.example.test/reports/1)').length).to eq(2)
      expect(markdown.scan('https://records.publication.example.test/covers/1.png').length).to eq(2)
      expect(markdown).not_to include('Previous', 'Next', 'collectionReady')
      expect(page.evaluate('document.body.innerHTML')).to eq(body)
    end
  end

  it 'binds the complete physical section across inert siblings instead of assigning unrelated context' do
    with_url_page('https://records.publication.example.test/archive/', section_page) do |page|
      body = page.evaluate('document.body.innerHTML')
      proof = page.evaluate(section_context_probe)
      expect(proof).not_to be_nil
      expect(proof.fetch('owner')).to eq('publication-section')
      expect(proof.fetch('nodes')).to include('section-label', 'record-branch')
      expected_headings = [['h2', 'Recent field reports'], *[1, 2, 3, 4, 1].map { |number| ['h2', "Field report #{number}"] }]
      expect(proof.fetch('headings')).to eq(expected_headings)
      expect(page.evaluate('document.body.innerHTML')).to eq(body)
    end
  end

  it 'preserves all linked-cover records when the headline fallback ranks their destinations more highly' do
    with_url_page('https://records.publication.example.test/archive/', section_page(linked: true)) do |page|
      body = page.evaluate('document.body.innerHTML')
      payload = extract_payload(page)
      output = Nokogiri::HTML5.fragment(payload.fetch('html'))
      expected_titles = ['Recent field reports', *[1, 2, 3, 4, 1].map { |number| "Field report #{number}" }]
      expect(output.css('h2').map(&:text)).to eq(expected_titles)
      expect(output.css('p').map(&:text)).to eq([1, 2, 3, 4, 1].map { |number| "Published June #{number}, 2026" })
      expect(output.css('img').map { |image| image['alt'] }).to eq([1, 2, 3, 4, 1].map { |number| "Cover #{number}" })
      markdown = payload.fetch('markdown')
      expect(markdown).to include('## Recent field reports')
      expect(markdown.index('## Recent field reports')).to be < markdown.index('Field report 1')
      expect(markdown.scan('](https://records.publication.example.test/reports/1)').length).to eq(4)
      expect(markdown.scan('https://records.publication.example.test/covers/1.png').length).to eq(2)
      expected_records = [1, 2, 3, 4, 1].flat_map do |number|
        destination = "https://records.publication.example.test/reports/#{number}"
        [
          "[![Cover #{number} Field report #{number}](https://records.publication.example.test/covers/#{number}.png)](#{destination})",
          "## [Field report #{number}](#{destination})",
          "Published June #{number}, 2026"
        ]
      end
      expect(markdown).to eq(['## Recent field reports', *expected_records].join("\n\n"))
      expect(page.evaluate('document.body.innerHTML')).to eq(body)
    end
  end

  it 'rejects unproved, hidden, linked, ambiguous, reversed and interface-owned headings' do
    negatives = [
      section_page(before: '<p>A separate authored explanation must not be skipped.</p>'),
      section_page(before: '<pre><code>literal_program = "keep_every_byte";</code></pre>'),
      section_page(before: 'Standalone prose between the heading and records.'),
      section_page(after: 'Standalone prose after the records.'),
      section_page.sub('<span id="records">', 'Standalone prose inside the wrapper.<span id="records">'),
      section_page(heading: '<div><h2><a href="/other">Another publication</a></h2></div>'),
      section_page(heading: '<div><h2>First section</h2><h3>Different section</h3></div>'),
      section_page(heading: '', after: '<div><h2>Later section</h2></div>'),
      section_page(heading: '<div hidden><h2>Hidden section</h2></div>'),
      section_page(heading: '<div><h2>Mixed heading</h2><span>Independent authored text</span></div>'),
      section_page(owner: 'nav')
    ]
    negatives.each do |html|
      with_url_page('https://records.publication.example.test/archive/', html) do |page|
        body = page.evaluate('document.body.innerHTML')
        expect(page.evaluate(section_context_probe)).to be_nil
        expect(page.evaluate('document.body.innerHTML')).to eq(body)
      end
    end
  end
end
