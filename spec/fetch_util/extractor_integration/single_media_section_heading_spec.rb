# frozen_string_literal: true

RSpec.describe 'Physical single-media section headings' do
  include_context 'extractor integration helpers'

  def media_section_fragment(header_class: 'block-header-row')
    <<~HTML
      <div class="resource-section">
        <div class="#{header_class}"><h2>Resources from our research partners</h2></div>
        <div class="resource-items"><div class="resource-card">
          <div><img src="/images/partner.svg" alt=""></div>
          <div><div><h3>Partner research catalogue</h3></div>
            <div><a href="https://partner.example.test">Go to the service</a></div>
          </div>
        </div></div>
      </div>
    HTML
  end

  def cleaned_media_sections(page)
    inject_standalone_extractor(page, reader_mode: false)
    root = File.expand_path('../../..', __dir__)
    entries = File.readlines(File.join(root, 'websieve/manifest.txt'), chomp: true)
                  .reject { |entry| entry.empty? || entry.start_with?('#') }
    outro = entries.pop
    source = entries.map { |entry| File.read(File.join(root, 'websieve', entry)) }
    source << <<~JAVASCRIPT
      window.__ownedMediaSections = function() {
        var source = document.querySelector('main');
        var clone = source.cloneNode(true);
        pruneHiddenClone(source, clone);
        materializeHttpAttributes(clone);
        cleanupListRoot(clone);
        return { html: clone.innerHTML, markdown: markdownFor(clone.innerHTML, false, true, true) };
      };
    JAVASCRIPT
    source << File.read(File.join(root, 'websieve', outro))
    page.evaluate("#{source.join("\n")}\ntrue")
    page.evaluate('window.__ownedMediaSections()')
  end

  it 'preserves the complete heading hierarchy and independently linked media resource' do
    html = "<html><body><main>#{media_section_fragment}</main></body></html>"
    with_url_page('https://research.example.test/', html) do |page|
      before = page.evaluate('document.body.innerHTML')
      result = cleaned_media_sections(page)
      native = Nokogiri::HTML5.fragment(result.fetch('html'))

      expect(native.css('h2, h3').map { |node| [node.name, node.text] }).to eq(
        [
          ['h2', 'Resources from our research partners'], ['h3', 'Partner research catalogue']
        ]
      )
      expect(native.css('a').map { |node| [node.text, node['href']] }).to eq(
        [
          ['Go to the service', 'https://partner.example.test/']
        ]
      )
      expect(native.css('img').map { |node| [node['alt'], node['src']] }).to eq(
        [
          ['', 'https://research.example.test/images/partner.svg']
        ]
      )
      expect(result.fetch('markdown')).to include(
        '## Resources from our research partners',
        '### Partner research catalogue',
        '[Go to the service](https://partner.example.test/)',
        '![](https://research.example.test/images/partner.svg)'
      )
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end

  it 'preserves each physical occurrence and complete programs without a header presentation hint' do
    program = "value = \"keep  two spaces\";\n  next(value);\n"
    html = <<~HTML
      <html><body><main>
        #{media_section_fragment(header_class: "heading-layout")}
        #{media_section_fragment(header_class: "heading-layout")}
        <pre><code>#{program}</code></pre>
      </main></body></html>
    HTML
    with_url_page('https://research.example.test/', html) do |page|
      before = page.evaluate('document.body.innerHTML')
      result = cleaned_media_sections(page)
      native = Nokogiri::HTML5.fragment(result.fetch('html'))

      expect(native.css('h2').map(&:text)).to eq(['Resources from our research partners'] * 2)
      expect(native.css('h3').map(&:text)).to eq(['Partner research catalogue'] * 2)
      expect(native.css('a').map { |node| node['href'] }).to eq(['https://partner.example.test/'] * 2)
      expect(native.css('img').map { |node| node['src'] }).to eq(['https://research.example.test/images/partner.svg'] * 2)
      expect(native.css('pre').map(&:text)).to eq([program])
      expect(result.fetch('markdown').scan('[Go to the service](https://partner.example.test/)').length).to eq(2)
      expect(result.fetch('markdown')).to include(program)
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end

  it 'keeps interface headings and source-hidden or closed resources excluded' do
    html = <<~HTML
      <html><body><main>
        <nav>#{media_section_fragment}</nav>
        <div hidden>#{media_section_fragment}</div>
        <details><summary>Closed resources</summary>#{media_section_fragment}</details>
        <p>Visible complete research explanation remains.</p>
      </main></body></html>
    HTML
    with_url_page('https://research.example.test/', html) do |page|
      before = page.evaluate('document.body.innerHTML')
      result = cleaned_media_sections(page)

      expect(result.fetch('markdown')).not_to include(
        'Resources from our research partners',
        'Partner research catalogue', 'partner.example.test'
      )
      expect(result.fetch('markdown')).to include('Visible complete research explanation remains.')
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end

  it 'keeps a separately rendered resource heading below its physical section heading' do
    html = "<html><body><main>#{media_section_fragment}<p>Complete accompanying explanation.</p></main></body></html>"
    with_url_page('https://research.example.test/', html) do |page|
      before = page.evaluate('document.body.innerHTML')
      inject_standalone_extractor(page, reader_mode: false)
      root = File.expand_path('../../../websieve', __dir__)
      entries = File.readlines(File.join(root, 'manifest.txt'), chomp: true)
                    .reject { |entry| entry.empty? || entry.start_with?('#') }
      outro = entries.pop
      source = entries.map { |entry| File.read(File.join(root, entry)) }
      source << <<~JAVASCRIPT
        window.__resourceHeadingHierarchy = function() {
          var main = document.querySelector('main');
          var headings = Array.from(main.querySelectorAll('h2, h3'));
          var sectioned = { regions: headings.map(function(heading) {
            return { node: heading.parentElement, headingNode: heading, label: heading.textContent, cards: [] };
          }) };
          var paragraph = main.querySelector('p');
          return sectionedListMarkdownWithDescriptions(sectioned, [{node: paragraph, markdown: markdownFor(paragraph.outerHTML)}]);
        };
      JAVASCRIPT
      source << File.read(File.join(root, outro))
      page.evaluate("#{source.join("\n")}\ntrue")

      expect(page.evaluate('window.__resourceHeadingHierarchy()')).to eq(
        "## Resources from our research partners\n\n### Partner research catalogue\n\nComplete accompanying explanation."
      )
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end

  it 'keeps the physical resource rank in flat and supplemental section coverage' do
    records = (1..4).map do |index|
      "<article><a href='/publications/#{index}'>Research publication #{index}</a></article>"
    end.join
    html = "<html><body><main>#{media_section_fragment}#{records}</main></body></html>"
    with_url_page('https://research.example.test/', html) do |page|
      before = page.evaluate('document.body.innerHTML')
      inject_standalone_extractor(page, reader_mode: false)
      root = File.expand_path('../../../websieve', __dir__)
      entries = File.readlines(File.join(root, 'manifest.txt'), chomp: true)
                    .reject { |entry| entry.empty? || entry.start_with?('#') }
      outro = entries.pop
      source = entries.map { |entry| File.read(File.join(root, entry)) }
      source << <<~JAVASCRIPT
        window.__flatResourceHierarchy = function() {
          var main = document.querySelector('main');
          var items = Array.from(main.querySelectorAll('a')).map(function(link) {
            return { text: link.textContent, url: link.href, sourceNode: link,
              card: link.closest('article, .resource-card') };
          });
          var heading = main.querySelector('.resource-card h3');
          var sectioned = { items: [items[0]], regions: [{ node: heading.parentElement,
            headingNode: heading, label: heading.textContent, cards: [items[0]] }] };
          var flat = sameRootFlatSectionCoverage(sectioned, items);
          var supplemental = supplementalSameRootSectionCoverage(sectioned, items, [], main, []);
          return { flatHeadings: flat.headingParts.map(function(part) { return part.markdown; }),
            supplementalHeadings: supplemental.headingParts.map(function(part) { return part.markdown; }),
            flat: sameRootFlatListMarkdown(flat.items, flat.headings), supplemental: supplemental.markdown };
        };
      JAVASCRIPT
      source << File.read(File.join(root, outro))
      page.evaluate("#{source.join("\n")}\ntrue")
      result = page.evaluate('window.__flatResourceHierarchy()')

      expect(result.fetch('flatHeadings')).to eq(['### Partner research catalogue'])
      expect(result.fetch('supplementalHeadings')).to eq(['### Partner research catalogue'])
      %w[flat supplemental].each do |key|
        expect(result.fetch(key)).to include('### Partner research catalogue', 'https://partner.example.test/')
        (1..4).each do |index|
          expect(result.fetch(key)).to include("[Research publication #{index}](https://research.example.test/publications/#{index})")
        end
      end
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end

  it 'retains the physical rank when rendering deferred resource descriptions' do
    html = "<html><body><main>#{media_section_fragment}</main></body></html>"
    with_url_page('https://research.example.test/', html) do |page|
      before = page.evaluate('document.body.innerHTML')
      inject_standalone_extractor(page, reader_mode: false)
      root = File.expand_path('../../../websieve', __dir__)
      entries = File.readlines(File.join(root, 'manifest.txt'), chomp: true)
                    .reject { |entry| entry.empty? || entry.start_with?('#') }
      outro = entries.pop
      source = entries.map { |entry| File.read(File.join(root, entry)) }
      source << <<~JAVASCRIPT
        window.__resourceDescriptionHierarchy = function() {
          var main = document.querySelector('main');
          var link = main.querySelector('a');
          var items = [{ text: link.textContent, url: link.href, sourceNode: link, card: link.parentElement }];
          var parts = listDescriptionParts(main, items, { includeInlineProse: true,
            preserveTextLengths: true, preserveUnrepresentedText: true });
          return parts.filter(function(part) { return part.node.matches('h2, h3'); }).map(function(part) {
            return [part.node.tagName, part.markdown];
          });
        };
      JAVASCRIPT
      source << File.read(File.join(root, outro))
      page.evaluate("#{source.join("\n")}\ntrue")

      expect(page.evaluate('window.__resourceDescriptionHierarchy()')).to eq(
        [
          ['H2', '## Resources from our research partners'], ['H3', '### Partner research catalogue']
        ]
      )
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end
end
