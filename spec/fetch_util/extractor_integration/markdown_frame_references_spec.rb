# frozen_string_literal: true

require 'spec_helper'
require 'support/extractor_integration_helpers'
require 'cgi'

RSpec.describe 'Physical iframe references in Markdown' do
  include_context 'extractor integration helpers'

  def frame_reference_markdown_probe
    directory = File.expand_path('../../../websieve', __dir__)
    source = File.readlines(File.join(directory, 'manifest.txt'), chomp: true)
                 .reject { |line| line.empty? || line.start_with?('#') }
                 .map { |file| File.read(File.join(directory, file)) }.join("\n")
    boundary = '})(window);'
    raise 'unexpected source closure' unless source.scan(boundary).length == 1

    source.sub(boundary, <<~JS)
      window.frameReferenceMarkdownProbe = withComposedDomRead(function() {
        var html = document.querySelector('article').outerHTML;
        return {ordinary: markdownFor(html, false, true),
          owned: markdownFor(html, false, true, true, turndownBlockUnits)};
      });
      window.frameReferenceContentProbe = withComposedDomRead(function() {
        var content = {html: document.querySelector('article').outerHTML, markdown: null, contentType: 'article'};
        var original = content.html;
        var markdown = contentBodyMarkdown(content);
        return {html: content.html, markdown: markdown, htmlUnchanged: content.html === original};
      });
      })(window);
    JS
  end

  it 'retains independently declared frame destinations and labels in physical order in both conversion paths' do
    html = <<~HTML
      <article><h1>Published demonstrations</h1><p>Read the complete examples in order.</p>
      <iframe src="/embed/lesson?part=1#intro" title="First demonstration"></iframe>
      <p>Compare the independent second presentation.</p>
      <iframe src="/embed/lesson?part=1#intro" aria-label="Second demonstration"></iframe>
      <iframe src="/embed/unlabelled"></iframe>
      <p><a href="/embed/lesson?part=1#intro">Authored download</a> remains independent.</p>
      <div style="visibility:hidden"><iframe style="visibility:visible" src="/embed/override" title="Visible override"></iframe></div>
      <details open><summary>Supplementary example</summary><iframe src="/embed/open" title="Open example"></iframe></details>
      </article>
    HTML
    with_url_page('https://publication.example.test/course/reference', html) do |page|
      before = page.evaluate('document.body.innerHTML')
      FetchUtil::Extractor.new.send(:inject_vendor_assets, page)
      page.add_script_tag(content: frame_reference_markdown_probe)
      result = page.evaluate('frameReferenceMarkdownProbe({})')
      result.each_value do |markdown|
        references = [
          '[First demonstration](https://publication.example.test/embed/lesson?part=1#intro)',
          '[Second demonstration](https://publication.example.test/embed/lesson?part=1#intro)',
          '[Embedded content](https://publication.example.test/embed/unlabelled)',
          '[Authored download](https://publication.example.test/embed/lesson?part=1#intro)',
          '[Visible override](https://publication.example.test/embed/override)',
          '[Open example](https://publication.example.test/embed/open)'
        ]
        expect(markdown).to include(*references, 'Read the complete examples in order.',
                                    'Compare the independent second presentation.', 'remains independent.')
        positions = references.map { |reference| markdown.index(reference) }
        expect(positions).to eq(positions.sort)
        expect(markdown.scan('https://publication.example.test/embed/lesson?part=1#intro').length).to eq(3)
      end
      expect(result.fetch('ordinary')).to eq(result.fetch('owned'))
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end

  it 'renders retained article HTML through the content-body conversion without altering source or programs' do
    program = "const example = '<iframe src=\"/literal-frame\"></iframe>';\nconsole.log(example);"
    html = <<~HTML
      <html><head><title>Recording reference</title><meta name="generator" content="MkDocs 1.6"></head>
      <body><main class="md-main"><article class="md-content__inner md-typeset">
      <h1>Recording reference</h1><p>This published explanation introduces the complete recording and its accompanying program.</p>
      <h2>Demonstration</h2><iframe src="https://media.example.test/embed/lesson" title="Complete demonstration"></iframe>
      <p>Keep the independent <a href="/reference">written reference</a> and the complete program below.</p>
      <pre><code class="language-js">#{CGI.escapeHTML(program)}</code></pre>
      </article></main></body></html>
    HTML
    with_url_page('https://documentation.example.test/recording/', html) do |page|
      before = page.evaluate('document.body.innerHTML')
      FetchUtil::Extractor.new.send(:inject_vendor_assets, page)
      page.add_script_tag(content: frame_reference_markdown_probe)
      result = page.evaluate('frameReferenceContentProbe({})')
      expect(result.fetch('htmlUnchanged')).to eq(true)
      native = Nokogiri::HTML5.fragment(result.fetch('html'))
      expect(native.css('iframe').map { |frame| frame['src'] }).to eq(['https://media.example.test/embed/lesson'])
      expect(result.fetch('markdown')).to include('[Complete demonstration](https://media.example.test/embed/lesson)',
                                                  'This published explanation introduces the complete recording and its accompanying program.',
                                                  '[written reference](https://documentation.example.test/reference)', program)
      expect(native.css('pre').map(&:text)).to eq([program])
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end

  it 'keeps hidden, closed, inactive and literal frame declarations from becoming visible resources' do
    program = '<iframe src="https://publication.example.test/literal-frame"></iframe>'
    html = <<~HTML
      <article><h1>Recording boundaries</h1><p>Only authored visible material belongs in the result.</p>
      <iframe hidden src="/hidden-attribute"></iframe><div inert><iframe src="/hidden-inert"></iframe></div>
      <div style="display:none"><iframe src="/hidden-display"></iframe></div>
      <iframe style="visibility:hidden" src="/hidden-visibility"></iframe>
      <iframe style="opacity:0" src="/hidden-opacity"></iframe>
      <details><summary>Closed example</summary><iframe src="/closed-frame"></iframe><p>Closed prose must remain closed.</p></details>
      <iframe src="/inactive-src" srcdoc="&lt;p&gt;An inline frame document&lt;/p&gt;"></iframe>
      <iframe src="about:blank"></iframe><iframe src="javascript:void(0)"></iframe>
      <iframe src="https://name:secret@publication.example.test/private-frame"></iframe>
      <pre><code data-language="html">#{CGI.escapeHTML(program)}</code></pre>
      <p>Keep the <a href="/reference">physical reference</a>.</p></article>
    HTML
    with_url_page('https://publication.example.test/course/reference', html) do |page|
      before = page.evaluate('document.body.innerHTML')
      FetchUtil::Extractor.new.send(:inject_vendor_assets, page)
      page.add_script_tag(content: frame_reference_markdown_probe)
      page.evaluate('frameReferenceMarkdownProbe({})').each_value do |markdown|
        expect(markdown).to include('Only authored visible material belongs in the result.', 'Closed example',
                                    "```html\n#{program}\n```", '[physical reference](https://publication.example.test/reference)')
        expect(markdown).not_to include('hidden-attribute', 'hidden-inert', 'hidden-display', 'hidden-visibility',
                                        'hidden-opacity', 'closed-frame', 'Closed prose', 'inactive-src',
                                        'inline frame document', 'about:blank', 'javascript:', 'name:secret@')
        expect(markdown.scan('https://publication.example.test/literal-frame').length).to eq(1)
      end
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end
end
