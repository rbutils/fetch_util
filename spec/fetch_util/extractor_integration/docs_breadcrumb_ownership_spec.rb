# frozen_string_literal: true

require 'spec_helper'
require 'support/extractor_integration_helpers'

RSpec.describe 'Documentation breadcrumb ownership' do
  include_context 'extractor integration helpers'

  def breadcrumb_predicate_probe
    directory = File.expand_path('../../../websieve', __dir__)
    source = File.readlines(File.join(directory, 'manifest.txt'), chomp: true)
                 .reject { |line| line.empty? || line.start_with?('#') }
                 .map { |file| File.read(File.join(directory, file)) }.join("\n")
    boundary = '})(window);'
    raise 'unexpected source closure' unless source.scan(boundary).length == 1

    source.sub(boundary, <<~JS)
      window.documentationBreadcrumbProbe = function(markup) {
        var holder = document.createElement('div');
        holder.innerHTML = markup;
        return breadcrumbLikeNode(holder.firstElementChild);
      };
      })(window);
    JS
  end

  it 'retains complete authored question resources while removing navigation and respecting source visibility' do
    program = "request --relay example\nrequest --archive complete"
    html = <<~HTML
      <html><head><title>Reference questions</title><meta name="generator" content="MkDocs 1.6"></head>
      <body><nav class="md-nav">Documentation navigation</nav><main class="md-main">
      <article class="md-content__inner md-typeset"><h1>Reference questions</h1>
      <div><a href="/">Home</a> / <a href="/guide/">Guide</a> / <a href="/guide/questions/">Questions</a></div>
      <h2 id="relay">Can I use a relay?</h2>
      <p>Different deployments have independent requirements, so choose the transport that fits the complete published workflow.</p>
      <ul><li>Additional resources are available in the <a href="../relay/">relay guide</a>.</li>
      <li>Connections may need further configuration; also see <a href="#limits">request limits</a>.</li></ul>
      <h2 id="limits">Request limits</h2><p>Keep every source explanation and reference in the order in which it was published.</p>
      <pre><code data-language="sh"><a id="sample-line" href="#sample-line" style="visibility:hidden"></a>#{program}</code></pre>
      <pre style="display:none"><code><a id="hidden-program-line" href="#hidden-program-line"></a>Unpublished program</code></pre>
      <div hidden><ul><li>Unpublished resources include <a href="../hidden/">hidden reference</a> and <a href="../private/">private reference</a>.</li></ul></div>
      <div style="display:none"><ul><li>Closed resources include <a href="../closed/">closed reference</a> and <a href="../draft/">draft reference</a>.</li></ul></div>
      <nav><a href="/navigation-only">Navigation only</a><a href="/other-navigation">Other navigation</a></nav>
      </article></main></body></html>
    HTML
    with_url_page('https://docs.publication.example.test/guide/questions/', html) do |page|
      before = page.evaluate('document.body.innerHTML')
      payload = extract(page)
      [payload.fetch('html'), payload.fetch('markdown')].each do |content|
        expect(content).to include('Additional resources are available in the', 'Connections may need further configuration; also see',
                                   'https://docs.publication.example.test/guide/relay/', '#limits')
        expect(content).not_to include('hidden reference', 'private reference', 'closed reference', 'draft reference',
                                       'Navigation only', 'Other navigation')
      end
      expect(payload.fetch('markdown')).to include("```sh\n#{program}\n```", '## Request limits')
      expect(payload.fetch('html')).to include('id="sample-line"', 'href="https://docs.publication.example.test/guide/questions/#sample-line"')
      expect(payload.fetch('html')).not_to include('hidden-program-line', 'Unpublished program')
      expect(payload.fetch('markdown')).not_to include('Unpublished program')
      expect(payload.fetch('html')).not_to include('>Home</a>', '>Guide</a>', '>Questions</a>')
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end

  it 'requires a flat separator-only ancestor-page chain instead of short link labels' do
    cases = {
      '<div><a href="/">Home</a> / <a href="/guide/">Guide</a> › <a href="/guide/questions/">Questions</a></div>' => true,
      '<ul><li>Additional resources are available at <a href="../relay/">Relay</a>.</li><li>Also see <a href="#limits">Limits</a>.</li></ul>' => false,
      '<ul><li><a href="../relay/">Relay</a></li><li><a href="../archive/">Archive</a></li></ul>' => false,
      '<div><a href="../relay/">Relay</a> / <a href="../archive/">Archive</a></div>' => false,
      '<div><a href="/guide/questions/">Questions</a> / <a href="/guide/">Guide</a></div>' => false,
      '<div><a href="https://other.example.test/">Home</a> / <a href="/guide/">Guide</a></div>' => false,
      '<div><a href="/">Home</a> / <a href="/guide/?view=all">Guide</a></div>' => false,
      '<div><a href="/">Home</a> / <a href="#limits">Limits</a></div>' => false,
      '<div><a href="/">Home</a> / <a href="/guide/">Guide</a><p>Published explanation belongs to this reference.</p></div>' => false,
      '<ul><li><a href="/">Home</a><ul><li><a href="/guide/">Guide</a></li></ul></li></ul>' => false
    }
    with_url_page('https://docs.publication.example.test/guide/questions/', '<h1>Reference questions</h1>') do |page|
      before = page.evaluate('document.body.innerHTML')
      page.add_script_tag(content: breadcrumb_predicate_probe)
      cases.each do |markup, expected|
        expect(page.evaluate("documentationBreadcrumbProbe(#{markup.to_json})")).to eq(expected), markup
      end
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end
end
