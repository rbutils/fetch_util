require 'spec_helper'

RSpec.describe 'FetchUtil source-owned citation suffixes' do
  include_context 'extractor integration helpers'

  def citation_markdown_source
    root = File.expand_path('../../..', __dir__)
    paths = File.readlines(File.join(root, 'websieve/manifest.txt'), chomp: true)
                .reject { |line| line.empty? || line.start_with?('#') }
    source = paths.map { |path| File.read(File.join(root, 'websieve', path)) }.join("\n")
    source.sub('})(window);', <<~JAVASCRIPT)
      global.renderCitationProbe = function(html) { return markdownFor(html, false, true, true); };
      })(window);
    JAVASCRIPT
  end

  def citation_markdowns(fragments)
    with_url_page('https://publication.example.test/references', '<main>Citation rendering probe</main>') do |page|
      source = page.evaluate('document.body.outerHTML')
      inject_standalone_extractor(page, reader_mode: false)
      page.add_script_tag(content: citation_markdown_source)
      markdowns = page.evaluate("#{JSON.generate(fragments)}.map(renderCitationProbe)")
      expect(page.evaluate('document.body.outerHTML')).to eq(source)
      markdowns
    end
  end

  it 'keeps complete adjacent statutory and section suffixes on their original destination' do
    statute = 'https://references.example.test/link/uscode/15/78'
    section = 'https://references.example.test/current/title-17/section-24.15'
    samples = {
      %(<p><a href="#{statute}">78</a><em>q</em>, another reference.</p>) => "[78q](#{statute}), another reference.",
      %(<p><a href="#{statute}">78</a><!-- boundary --><i>q</i>.</p>) => "[78q](#{statute}).",
      %(<p><a href="#{section}">Section 24.15</a><em>l</em>-12.</p>) => "[Section 24.15l-12](#{section})."
    }
    expect(citation_markdowns(samples.keys)).to eq(samples.values)
  end

  it 'keeps ordinary, separated, attributed and non-letter emphasis outside links' do
    statute = 'https://references.example.test/link/uscode/15/78'
    ordinary = 'https://references.example.test/guide/78'
    samples = {
      %(<p><a href="#{ordinary}">78</a><em>q</em>.</p>) => "[78](#{ordinary})*q*.",
      %(<p><a href="#{statute}">78</a> <em>q</em>.</p>) => "[78](#{statute}) _q_.",
      %(<p><a href="#{statute}">78</a><em id="reference-note">q</em>.</p>) => "[78](#{statute})*q*.",
      %(<p><a href="#{statute}">78</a><em>q</em>ualified.</p>) => "[78](#{statute})*q*ualified.",
      %(<p><a href="#{statute}">78</a><em>ordinary</em>.</p>) => "[78](#{statute})*ordinary*.",
      '<p>This was a <em>broad</em>cast, with complete wording.</p>' => 'This was a *broad*cast, with complete wording.'
    }
    expect(citation_markdowns(samples.keys)).to eq(samples.values)
  end

  it 'preserves citation-shaped inline and fenced program values without rewriting code' do
    literal = '[78](https://references.example.test/link/uscode/15/78)*q*'
    samples = {
      "<p><code>#{literal}</code></p>" => "`#{literal}`",
      "<pre><code>#{literal}</code></pre>" => "```\n#{literal}\n```",
      '<p><code><a href="https://references.example.test/link/uscode/15/78">78</a><em>q</em></code></p>' => "`#{literal}`"
    }
    expect(citation_markdowns(samples.keys)).to eq(samples.values)
  end
end
