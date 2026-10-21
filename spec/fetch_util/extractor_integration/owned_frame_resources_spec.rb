# frozen_string_literal: true

require 'spec_helper'
require 'support/extractor_integration_helpers'
require 'cgi'

RSpec.describe 'Source-owned frame resources through article cleanup' do
  include_context 'extractor integration helpers'

  def owned_frame_page(generator: '', owner: 'article', attributes: '', frames: nil)
    program = "const example = '<iframe src=\"/literal-frame\"></iframe>';\nconsole.log(example);"
    frames ||= '<iframe src="https://media.example.test/embed/lesson" title="Complete demonstration"></iframe>'
    [<<~HTML, program]
      <!doctype html><html><head><title>Recording reference</title>
      <meta name="generator" content="#{generator}"><meta property="og:type" content="article">
      <link rel="canonical" href="https://publication.example.test/course/"></head><body>
      <#{owner} #{attributes}><h1>Recording reference</h1>
      <p>This published explanation introduces the complete recording and its accompanying program.
      The author describes every step and keeps the independent written references beside the demonstration.</p>
      <h2>Demonstration</h2>#{frames}
      <p>Keep the independent <a href="/written-reference">written reference</a> and the complete program below.</p>
      <pre><code data-language="js">#{CGI.escapeHTML(program)}</code></pre>
      <h2>Conclusion</h2><p>The complete explanation ends after the program and every recorded resource.</p>
      </#{owner}></body></html>
    HTML
  end

  def owned_frame_cleanup_probe(prune: false)
    directory = File.expand_path('../../../websieve', __dir__)
    source = File.readlines(File.join(directory, 'manifest.txt'), chomp: true)
                 .reject { |line| line.empty? || line.start_with?('#') }
                 .map { |file| File.read(File.join(directory, file)) }.join("\n")
    boundary = '})(window);'
    raise 'unexpected source closure' unless source.scan(boundary).length == 1

    source.sub(boundary, <<~JS)
      window.ownedFrameCleanupProbe = withComposedDomRead(function() {
        var source = document.querySelector('[data-owned-probe]');
        var mapping = new Map();
        var clone = #{prune ? "visibilityPrunedClone(source, document, mapping)" : "source.cloneNode(true)"};
        var cleaned = cleanClonedContent(source, clone, null, mapping);
        return {html: cleaned.outerHTML, markdown: markdownFor(cleaned.outerHTML, false, true)};
      });
      })(window);
    JS
  end

  [
    ['MkDocs', { generator: 'MkDocs 1.6', attributes: 'class="md-content__inner md-typeset"' }],
    ['WordPress', { generator: 'WordPress 6.9', attributes: 'class="entry-content"' }],
    ['plain article', { attributes: 'class="post-content"' }],
    ['semantic main', { owner: 'main' }]
  ].each do |name, options|
    it "retains an ordinary #{name} section's declared resource and complete program" do
      html, program = owned_frame_page(**options)
      with_url_page('https://publication.example.test/course/', html) do |page|
        before = page.evaluate('document.body.innerHTML')
        result = extract(page)
        native = Nokogiri::HTML5.fragment(result.fetch('html'))
        destinations = native.css('a[href], iframe[src]').map { |node| node['href'] || node['src'] }
        expect(destinations).to include('https://media.example.test/embed/lesson')
        expect(native.css('pre').map(&:text)).to eq([program])
        expect(result.fetch('markdown')).to include(
          '[Complete demonstration](https://media.example.test/embed/lesson)',
          '[written reference](https://publication.example.test/written-reference)', program,
          'The author describes every step and keeps the independent written references beside the demonstration.',
          'The complete explanation ends after the program and every recorded resource.'
        )
        expect(native.css('h2').map(&:text)).to eq(%w[Demonstration Conclusion])
        expect(page.evaluate('document.body.innerHTML')).to eq(before)
      end
    end
  end

  it 'keeps independent equal destinations, labels and the physical authored link in order' do
    frames = <<~HTML
      <iframe src="/embed/same" title="First recording"></iframe>
      <p>The second recording is an independent presentation.</p>
      <div><iframe src="/embed/same" aria-label="Second recording"></iframe></div>
      <iframe src="/embed/unlabelled"></iframe>
      <p><a href="/embed/same">Authored recording link</a> is independent of the players.</p>
    HTML
    html, program = owned_frame_page(generator: 'WordPress 6.9', attributes: 'class="entry-content"', frames: frames)
    with_url_page('https://publication.example.test/course/', html) do |page|
      before = page.evaluate('document.body.innerHTML')
      result = extract(page)
      references = [
        '[First recording](https://publication.example.test/embed/same)',
        '[Second recording](https://publication.example.test/embed/same)',
        '[Embedded content](https://publication.example.test/embed/unlabelled)',
        '[Authored recording link](https://publication.example.test/embed/same)'
      ]
      markdown = result.fetch('markdown')
      expect(markdown).to include(*references, program, 'The second recording is an independent presentation.')
      positions = references.map { |reference| markdown.index(reference) }
      expect(positions).to eq(positions.sort)
      expect(markdown.scan('https://publication.example.test/embed/same').length).to eq(3)
      expect(Nokogiri::HTML5.fragment(result.fetch('html')).css('pre').map(&:text)).to eq([program])
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end

  it 'uses actual mapped visible peers when a source-hidden frame has already been pruned' do
    html = <<~HTML
      <article data-owned-probe><h1>Recorded field notes</h1><p>The complete observations accompany these recordings.</p>
      <h2>Recordings</h2><iframe src="/one" title="First visible recording"></iframe>
      <div style="display:none"><iframe src="/hidden" title="Hidden recording"></iframe></div>
      <iframe src="/two" title="Second visible recording"></iframe><p>Keep the final observation.</p></article>
    HTML
    with_url_page('https://publication.example.test/course/', html) do |page|
      before = page.evaluate('document.body.innerHTML')
      FetchUtil::Extractor.new.send(:inject_vendor_assets, page)
      page.add_script_tag(content: owned_frame_cleanup_probe(prune: true))
      result = page.evaluate('ownedFrameCleanupProbe({})')
      native = Nokogiri::HTML5.fragment(result.fetch('html'))
      expected = [
        ['First visible recording', 'https://publication.example.test/one'],
        ['Second visible recording', 'https://publication.example.test/two']
      ]
      expect(native.css('a').map { |link| [link.text, link['href']] }).to eq(expected)
      expect(result.fetch('markdown')).to include('Keep the final observation.')
      expect(result.fetch('markdown')).not_to include('Hidden recording', '/hidden')
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end

  it 'does not borrow peer-section headings or expose interface, inactive, hidden, closed or literal resources' do
    program = '<iframe src="https://publication.example.test/literal-frame"></iframe>'
    html = <<~HTML
      <article data-owned-probe><h1>Recording boundaries</h1><p>The complete source description stays visible.</p>
      <iframe src="/unowned" title="Unowned page-level frame"></iframe>
      <section><h2>Peer section</h2><p>This section owns its own description.</p></section>
      <section><iframe src="/peer-heading" title="Unowned peer frame"></iframe></section>
      <h2>Owned demonstration</h2>
      <nav><iframe src="/navigation" title="Navigation player"></iframe></nav>
      <aside><iframe src="/aside" title="Sidebar player"></iframe></aside>
      <form><iframe src="/form" title="Form player"></iframe></form>
      <div role="dialog"><iframe src="/dialog" title="Dialog player"></iframe></div>
      <div class="advertisement"><iframe src="/advertisement" title="Advertised player"></iframe></div>
      <iframe hidden src="/hidden"></iframe><div inert><iframe src="/inert"></iframe></div>
      <iframe style="opacity:0" src="/transparent"></iframe>
      <details><summary>Closed recording</summary><iframe src="/closed"></iframe></details>
      <iframe src="/inactive" srcdoc="&lt;p&gt;Inline frame document&lt;/p&gt;"></iframe>
      <iframe src="javascript:void(0)"></iframe><iframe src="https://name:secret@publication.example.test/private"></iframe>
      <pre><code data-language="html">#{CGI.escapeHTML(program)}</code></pre>
      <p><a href="/written-reference">Physical reference</a> remains intact.</p></article>
    HTML
    with_url_page('https://publication.example.test/course/', html) do |page|
      before = page.evaluate('document.body.innerHTML')
      FetchUtil::Extractor.new.send(:inject_vendor_assets, page)
      page.add_script_tag(content: owned_frame_cleanup_probe)
      result = page.evaluate('ownedFrameCleanupProbe({})')
      native = Nokogiri::HTML5.fragment(result.fetch('html'))
      expect(native.css('a').map { |link| link['href'] }).to eq(['https://publication.example.test/written-reference'])
      expect(native.css('pre').map(&:text)).to eq([program])
      expect(result.fetch('markdown')).to include(program, 'The complete source description stays visible.', 'Closed recording')
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end
end
