# frozen_string_literal: true

require 'spec_helper'
require 'support/extractor_integration_helpers'

RSpec.describe 'Physical video poster references in Markdown' do
  include_context 'extractor integration helpers'

  def video_poster_markdown_probe
    directory = File.expand_path('../../../websieve', __dir__)
    source = File.readlines(File.join(directory, 'manifest.txt'), chomp: true)
                 .reject { |line| line.empty? || line.start_with?('#') }
                 .map { |file| File.read(File.join(directory, file)) }.join("\n")
    boundary = '})(window);'
    raise 'unexpected source closure' unless source.scan(boundary).length == 1

    source.sub(boundary, <<~JS)
      window.videoPosterMarkdownProbe = withComposedDomRead(function() {
        var html = document.querySelector('article').outerHTML;
        return {ordinary: markdownFor(html, false, true),
          owned: markdownFor(html, false, true, true, turndownBlockUnits)};
      });
      })(window);
    JS
  end

  it 'retains every physical poster destination and label in source order in both conversion paths' do
    videos = (1..241).map do |number|
      %(<p>Published scene #{number}.</p><video poster="/posters/frame-#{number}.jpg" aria-label="Scene #{number}"></video>)
    end.join
    with_url_page('https://publication.example.test/course/reference', "<article>#{videos}</article>") do |page|
      before = page.evaluate('document.body.innerHTML')
      FetchUtil::Extractor.new.send(:inject_vendor_assets, page)
      page.add_script_tag(content: video_poster_markdown_probe)
      result = page.evaluate('videoPosterMarkdownProbe({})')
      result.each_value do |markdown|
        positions = (1..241).map do |number|
          image = "![Scene #{number}](https://publication.example.test/posters/frame-#{number}.jpg)"
          expect(markdown).to include("Published scene #{number}.", image)
          markdown.index(image)
        end
        expect(positions).to eq(positions.sort)
        expect(positions.uniq.length).to eq(241)
      end
      expect(result.fetch('ordinary')).to eq(result.fetch('owned'))
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end

  it 'keeps genuine programs and explicit hidden or unsupported media separate from visible fallback resources' do
    program = '<video poster="https://publication.example.test/literal-only.jpg"></video>'
    html = <<~HTML
      <article><h1>Published recording notes</h1><p>Keep every actual reference and complete program.</p>
      <video poster="/poster-only.jpg" autoplay muted loop></video>
      <video poster="/playable-poster.jpg" title="Published recording"><source src="/recording.mp4" type="video/mp4"></video>
      <video src="/direct.webm" poster="/existing-fallback.jpg"><img src="/existing-fallback.jpg" alt="Existing fallback"><source src="/alternate.mp4"><source src="/direct.webm"><a href="/alternate.mp4">Existing download</a></video>
      <video poster="/empty-fallback.jpg"><img src="/empty-fallback.jpg" alt=""></video>
      <video src="/empty-link.mp4"><a href="/empty-link.mp4"></a></video>
      <video hidden poster="/hidden-attribute.jpg"></video>
      <div style="display:none"><video poster="/hidden-ancestor.jpg"></video></div>
      <video style="visibility:hidden" poster="/hidden-visibility.jpg"></video>
      <div style="visibility:hidden"><video style="visibility:inherit" poster="/hidden-inherit.jpg"></video></div>
      <div style="visibility:hidden"><video style="visibility:visible" poster="/visible-override.jpg"></video></div>
      <video poster="javascript:alert(1)"></video><video poster="https://name:secret@publication.example.test/private.jpg"></video>
      <pre><code data-language="html">#{program.gsub("&", "&amp;").gsub("<", "&lt;")}</code></pre>
      <p>Keep <a href="/reference">the actual reference</a>.</p></article>
    HTML
    with_url_page('https://publication.example.test/course/reference', html) do |page|
      before = page.evaluate('document.body.innerHTML')
      FetchUtil::Extractor.new.send(:inject_vendor_assets, page)
      page.add_script_tag(content: video_poster_markdown_probe)
      page.evaluate('videoPosterMarkdownProbe({})').each_value do |markdown|
        expect(markdown).to include('![Video poster](https://publication.example.test/poster-only.jpg)',
                                    '![Published recording](https://publication.example.test/playable-poster.jpg)',
                                    '[Video source](https://publication.example.test/recording.mp4)',
                                    '[Video source](https://publication.example.test/direct.webm)',
                                    '[Existing download](https://publication.example.test/alternate.mp4)',
                                    '![Video poster](https://publication.example.test/empty-fallback.jpg)',
                                    '[Video source](https://publication.example.test/empty-link.mp4)',
                                    '![Video poster](https://publication.example.test/visible-override.jpg)',
                                    '![Existing fallback](https://publication.example.test/existing-fallback.jpg)',
                                    "```html\n#{program}\n```", 'https://publication.example.test/reference')
        expect(markdown.scan('https://publication.example.test/existing-fallback.jpg').length).to eq(1)
        expect(markdown.scan('https://publication.example.test/direct.webm').length).to eq(1)
        expect(markdown.scan('https://publication.example.test/alternate.mp4').length).to eq(1)
        expect(markdown.scan('https://publication.example.test/empty-fallback.jpg').length).to eq(1)
        expect(markdown).not_to include('hidden-attribute.jpg', 'hidden-ancestor.jpg', 'hidden-visibility.jpg',
                                        'hidden-inherit.jpg', 'javascript:alert', 'name:secret@')
      end
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end
end
