require 'spec_helper'
require 'support/extractor_integration_helpers'
require 'cgi'
require 'nokogiri'

RSpec.describe 'Complete rich list-body Markdown' do
  include_context 'complete block reference expectations'

  def rich_landing_page(extra = '')
    features = [
      ['Simple interface', 'Read and write complete publication values using standard HTTP tools.', 'interface.svg'],
      ['Hierarchical storage', 'Store complete publication records in independently named directories.', 'storage.svg'],
      ['Observe changes', 'Watch complete publication records and respond to their independent changes.', 'changes.svg']
    ].map do |title, prose, image|
      %(<div class="feature"><div><h3>#{title}</h3><p>#{prose}</p></div><img src="/images/#{image}" alt="#{title} illustration"></div>)
    end.join
    users = %w[first second third fourth].map do |name|
      %(<div class="user"><a href="https://#{name}.example.test/"><img src="/images/#{name}.png" alt="#{name} publication user"></a></div>)
    end.join
    <<~HTML
      <html><head><title>Helios publication registry</title><meta property="og:type" content="website"></head>
      <body><main role="main">
      <section><div><img src="/images/registry.png" alt=""><h2>A reliable registry for complete publication records</h2>
      <div><a href="/docs/">Learn more</a> <a href="/docs/quickstart/">Quickstart</a></div></div></section>
      <section><h1>What is Helios?</h1><p>Helios is a strongly consistent publication registry that stores the complete configuration
      and independent records needed by distributed applications. Every complete record remains available in its original order,
      together with the references and documentation needed to operate the publication registry. <a href="/docs/">Learn more</a></p></section>
      <div><section><h1>Features</h1><div>#{features}</div>
      <p>Optional certificate authentication protects every complete publication record.</p>
      <p>Independent transactions preserve complete record values and ordering.</p>#{extra}</section>
      <section><h1>Used by</h1><div>#{users}</div></section>
      <section><h4>Helios is an independent publication project</h4><img src="/images/foundation.png" alt="Publication foundation"></section></div>
      </main></body></html>
    HTML
  end

  def generic_rich_list_material(page)
    root = File.expand_path('../..', File.dirname(FetchUtil::Extractor.instance_method(:extract).source_location.first))
    namespace = File.readlines(File.join(root, 'websieve/manifest.txt'), chomp: true)
                    .reject { |path| path.empty? || path.start_with?('#') }
                    .map { |path| File.read(File.join(root, 'websieve', path)) }.join("\n")
    probe = <<~JS
      window.__genericRichListMaterial = function() {
        var content = listContent({ title: document.title, canonicalUrl: location.href });
        return { html: content.html, markdown: content.markdown, contentType: content.contentType };
      };
    JS
    raise 'extractor closure boundary changed' unless namespace.scan('})(window);').size == 1

    page.add_script_tag(content: namespace.sub('})(window);', "#{probe}\n})(window);"))
    page.evaluate('window.__genericRichListMaterial()')
  end

  it 'retains every selected-body image, linked image destination and physical peer heading' do
    with_url_page('https://publication.example.test/', rich_landing_page) do |page|
      before = page.evaluate('document.body.innerHTML')
      payload = extract(page)
      native = Nokogiri::HTML5(payload.fetch('html'))
      images = native.css('img').map { |node| [node['src'], node['alt'].to_s] }
      expect(images.length).to eq(9)
      images.each { |source, alternative| expect(payload.fetch('markdown')).to include("![#{alternative}](#{source})") }
      %w[first second third fourth].each do |name|
        expect(payload.fetch('markdown')).to include("https://#{name}.example.test/")
      end
      expect(payload.fetch('markdown')).to include('#### Helios is an independent publication project')
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end

  it 'keeps independent repeated images, complete literal programs and authored references in order' do
    program = "const literal = \"![kept](https://code.example.test/literal.png)\";\nprint(literal);  "
    extra = <<~HTML
      <div><p>Two independent publication diagrams remain associated with their physical explanations.</p>
      <img src="/images/repeated.png" alt="First independent diagram">
      <img src="/images/repeated.png" alt="Second independent diagram"></div>
      <pre><code data-language="js">#{CGI.escapeHTML(program)}</code></pre>
      <p>Read the <a href="/reference/">complete configuration reference</a> before deploying every publication record.</p>
    HTML
    with_url_page('https://publication.example.test/', rich_landing_page(extra)) do |page|
      before = page.evaluate('document.body.innerHTML')
      payload = extract(page)
      markdown = payload.fetch('markdown')
      expect(markdown).to include('![First independent diagram](https://publication.example.test/images/repeated.png)')
      expect(markdown).to include('![Second independent diagram](https://publication.example.test/images/repeated.png)')
      expect(markdown.index('First independent diagram')).to be < markdown.index('Second independent diagram')
      expect(markdown).to include(program, '[complete configuration reference](https://publication.example.test/reference/)')
      expect(Nokogiri::HTML5(payload.fetch('html')).css('pre').map(&:text)).to eq([program])
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end

  it 'retains visible rich material without exposing hidden images or closed program bodies' do
    extra = <<~HTML
      <img hidden src="/images/hidden.png" alt="Unpublished diagram">
      <details><summary>Additional publication details</summary><img src="/images/closed.png" alt="Closed diagram">
      <pre><code>closed_publication_program();</code></pre></details>
      <p>The complete visible publication explanation remains after the closed disclosure.</p>
    HTML
    with_url_page('https://publication.example.test/', rich_landing_page(extra)) do |page|
      before = page.evaluate('document.body.innerHTML')
      payload = extract(page)
      expect(payload.fetch('markdown')).to include('Additional publication details', 'The complete visible publication explanation remains')
      expect(payload.fetch('markdown')).not_to include('hidden.png', 'closed.png', 'Unpublished diagram', 'Closed diagram', 'closed_publication_program();')
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end

  it 'keeps complete selected-root media when the shared generic list renderer is selected' do
    with_url_page('https://publication.example.test/', rich_landing_page) do |page|
      before = page.evaluate('document.body.innerHTML')
      extract(page)
      payload = generic_rich_list_material(page)
      images = Nokogiri::HTML5(payload.fetch('html')).css('img').map { |node| [node['src'], node['alt'].to_s] }
      expect(payload.fetch('contentType')).to eq('list')
      expect(images.length).to eq(9)
      images.each { |image, alternative| expect(payload.fetch('markdown')).to include("![#{alternative}](#{image})") }
      %w[first second third fourth].each do |name|
        expect(payload.fetch('markdown')).to include("https://#{name}.example.test/")
      end
      expect(payload.fetch('markdown')).to include('#### Helios is an independent publication project')
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end

  it 'preserves literal entity words and complete existing instructions while restoring images' do
    program = "const literal = '&shy;';  "
    extra = <<~HTML
      <p class="source-literal">Literal &amp;shy; is an authored entity spelling, not a discretionary hyphen.</p>
      <div title="Install the publication server">
        <div><div>1</div><div>Download &amp; Extract</div></div>
        <div><div>2</div><div>Run script</div></div>
        <div><div>3</div><div>Proceed to the installation</div></div>
        <div><div>4</div><div>Follow the installation wizard.</div></div>
      </div>
      <pre><code>#{CGI.escapeHTML(program)}</code></pre>
    HTML
    with_url_page('https://publication.example.test/', rich_landing_page(extra)) do |page|
      before = page.evaluate('document.body.innerHTML')
      extract(page)
      payload = generic_rich_list_material(page)
      native = Nokogiri::HTML5(payload.fetch('html'))
      expect(native.at_css('p.source-literal').text).to eq('Literal &shy; is an authored entity spelling, not a discretionary hyphen.')
      expect(native.css('pre').map(&:text)).to eq([program])
      expect(payload.fetch('markdown')).to include('Literal \\&shy; is an authored entity spelling, not a discretionary hyphen.', program)
      ['Download & Extract', 'Run script', 'Proceed to the installation', 'Follow the installation wizard.'].each do |step|
        expect(native.text).to include(step)
        expect(payload.fetch('markdown')).to include(step)
      end
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end

  it 'retains physical block boundaries and separates newly readable empty destinations' do
    extra = <<~HTML
      <div><a href="/first-action/"><div>First action</div></a><a href="/second-action/">Second action</a></div>
      <div><div role="button"><span>release</span><span></span></div><div role="button"><span>firstclient</span><span></span></div><div role="button"><span>secondclient</span><span></span></div></div>
      <p>Complete publication excerpt.<a href="/empty-resource/"></a></p>
    HTML
    with_url_page('https://publication.example.test/', rich_landing_page(extra)) do |page|
      before = page.evaluate('document.body.innerHTML')
      extract(page)
      payload = generic_rich_list_material(page)
      native = Nokogiri::HTML5(payload.fetch('html'))
      expect(native.css('a[href]').map { |node| node['href'] }).to include('https://publication.example.test/empty-resource/')
      markdown = payload.fetch('markdown')
      expect_complete_raw_references(markdown, 'https://publication.example.test/first-action/', payload.fetch('html'))
      expect(markdown).to include('[Second action](https://publication.example.test/second-action/)')
      expect(markdown).to match(%r{</a></div>\s+\[Second action\]})
      expect(markdown.gsub(/[[:space:]]+/, ' ')).to include('release firstclient secondclient')
      expect(markdown).to match(%r{Complete publication excerpt\.\s+\[https://publication\.example\.test/empty-resource/})
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end
end
