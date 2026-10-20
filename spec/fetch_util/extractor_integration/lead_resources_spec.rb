# frozen_string_literal: true

require 'cgi'
require 'spec_helper'
require 'support/extractor_integration_helpers'

RSpec.describe 'Source-owned leading publication resources' do
  include_context 'extractor integration helpers'

  def leading_resource_reparse(page, mutation = nil)
    root = File.expand_path('../..', File.dirname(FetchUtil::Extractor.instance_method(:extract).source_location.first))
    source = File.readlines(File.join(root, 'websieve/manifest.txt'), chomp: true)
                 .reject { |path| path.empty? || path.start_with?('#') }
                 .map { |path| File.read(File.join(root, 'websieve', path)) }.join("\n")
    probe = <<~JS
      window.__leadingResourceReparseProof = function(mutation) {
        var clone = safeReadableDocumentClone(), sourceClones = new Map();
        pruneHiddenClone(document.documentElement, clone.documentElement, null, null, null, sourceClones);
        var marker = markReadabilityExcerptSources(clone);
        var identities = markReadabilitySourceNodeProvenance(clone, sourceClones, marker);
        var reader = new Readability(clone);
        preserveReadabilityOwnedResources(reader, clone, sourceClones, marker);
        reader._cleanConditionally(clone.body, 'div');
        var firstHtml = clone.body.innerHTML;
        clone.body.innerHTML = firstHtml;
        var sameMarkup = clone.body.innerHTML === firstHtml;
        var block = clone.querySelector('div[data-fetchutil-reader-source-resource]');
        if (mutation === 'destination') block.querySelector('a').setAttribute('href', '../unowned/');
        if (mutation === 'duplicate') block.after(block.cloneNode(true));
        if (mutation === 'foreign') block.setAttribute('data-fetchutil-reader-source-resource', 'foreign:0');
        if (mutation === 'image') clone.querySelector('img').setAttribute('src', 'https://assets.example.test/unowned.png');
        reader._cleanConditionally(clone.body, 'div');
        var html = stripReadabilityExcerptMarkers(clone.body.innerHTML, marker);
        html = stripReadabilitySourceNodeMarkers(html, marker, identities);
        html = stripReadabilityLeadResourceMarkers(html, marker);
        return {html: html, markdown: markdownFor(html), firstHtml: firstHtml, sameMarkup: sameMarkup};
      };
    JS
    raise 'extractor closure boundary changed' unless source.scan('})(window);').size == 1

    page.add_script_tag(content: source.sub('})(window);', "#{probe}\n})(window);"))
    page.evaluate("window.__leadingResourceReparseProof(#{mutation.to_json})")
  end

  def resource_report(lead, extra = '')
    paragraphs = [
      'The published inspector explains how independent observations are collected and interpreted. ' \
      'Its complete introduction describes the available resources and the limits of the recorded evidence.',
      'The following procedure keeps the original sequence of measurements and their accompanying explanation. ' \
      'Readers can compare every physical record with the complete procedure and review its supporting reference.',
      'The final discussion distinguishes directly recorded values from later interpretations. ' \
      'Every independent observation remains attached to its original explanation and published resource.'
    ]
    <<~HTML
      <html><head><title>Published inspector report</title><meta property="og:type" content="article"></head>
      <body><main><section><h1>Published inspector report</h1><p>#{paragraphs[0]}</p>#{lead}</section>
      <section><h2>Complete procedure</h2><p>#{paragraphs[1]}</p><pre><code>#{CGI.escapeHTML("const sample = 'original';\nconsole.log(sample);  ")}</code></pre></section>
      <section><h2>Complete discussion</h2><p>#{paragraphs[2]} <a href="../evidence/">Supporting observations</a>.</p></section>
      #{extra}</main></body></html>
    HTML
  end

  it 'keeps the complete independent resource group and its captured-visible product image' do
    lead = <<~HTML
      <div><a href="../console/">Public console</a><a href="../download/">Download inspector</a><a href="https://reference.example.test/inspector/">Read reference</a></div>
      <div class="preview-media"><div><img src="https://assets.example.test/inspector.png" alt="Inspector view"></div></div>
    HTML
    with_url_page('https://publication.example.test/reports/inspector/', resource_report(lead)) do |page|
      before = page.evaluate('document.body.innerHTML')
      payload = extract(page)
      markdown = payload.fetch('markdown')
      expect(markdown).to include('[Public console](https://publication.example.test/reports/console/)',
                                  '[Download inspector](https://publication.example.test/reports/download/)',
                                  '[Read reference](https://reference.example.test/inspector/)',
                                  '![Inspector view](https://assets.example.test/inspector.png)',
                                  '[Supporting observations](https://publication.example.test/reports/evidence/)')
      expect(markdown.index('[Public console]')).to be < markdown.index('[Download inspector]')
      expect(markdown.index('[Download inspector]')).to be < markdown.index('![Inspector view]')
      expect(payload.fetch('html')).to include("console.log(sample);  ")
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end

  it 'keeps independent repeated destinations and complete literal programs' do
    lead = <<~HTML
      <div><a href="../resources/">Research edition</a><a href="../resources/">Archive edition</a><a href="../history/">Complete history</a></div>
      <div class="preview-media"><img src="https://assets.example.test/history.png" alt="Published history"></div>
    HTML
    with_url_page('https://publication.example.test/reports/history/', resource_report(lead)) do |page|
      before = page.evaluate('document.body.innerHTML')
      payload = extract(page)
      markdown = payload.fetch('markdown')
      expect(markdown).to include('[Research edition](https://publication.example.test/reports/resources/)',
                                  '[Archive edition](https://publication.example.test/reports/resources/)',
                                  '[Complete history](https://publication.example.test/reports/history/)',
                                  '![Published history](https://assets.example.test/history.png)')
      expect(markdown.scan('https://publication.example.test/reports/resources/').length).to eq(2)
      expect(markdown.index('[Research edition]')).to be < markdown.index('[Archive edition]')
      program = page.evaluate(<<~JS)
        (function() { var root = document.createElement('div'); root.innerHTML = #{payload.fetch("html").to_json};
          return Array.from(root.querySelectorAll('pre code')).map(function(node) { return node.textContent; }); })()
      JS
      expect(program).to eq(["const sample = 'original';\nconsole.log(sample);  "])
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end

  it 'keeps physical navigation, hidden resources and closed disclosures excluded' do
    lead = <<~HTML
      <nav><div><a href="../account/">Account settings</a><a href="../logout/">Leave account</a></div></nav>
      <div hidden><a href="../hidden/">Hidden resource</a><img src="https://assets.example.test/hidden.png" alt="Hidden image"></div>
      <details><summary>Optional material</summary><div><a href="../closed/">Closed resource</a></div><pre><code>secret_closed_program();</code></pre></details>
    HTML
    with_url_page('https://publication.example.test/reports/visibility/', resource_report(lead)) do |page|
      before = page.evaluate('document.body.innerHTML')
      payload = extract(page)
      markdown = payload.fetch('markdown')
      expect(markdown).not_to include('Account settings', 'Leave account', 'Hidden resource', 'Hidden image',
                                      'Closed resource', 'secret_closed_program();')
      expect(markdown).to include('Complete procedure', 'Complete discussion', 'Supporting observations')
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end

  it 'binds reparsed resources to complete unique source markup and rejects changed or copied owners' do
    lead = <<~HTML
      <div><a href="../console/">Public console</a><a href="../download/">Download inspector</a><a href="../reference/">Read reference</a></div>
      <div class="preview-media"><div><img src="https://assets.example.test/inspector.png" alt="Inspector view"></div></div>
    HTML
    with_url_page('https://publication.example.test/reports/reparse/', resource_report(lead)) do |page|
      before = page.evaluate('document.body.innerHTML')
      expect(extract(page).fetch('markdown')).to include('[Public console]', '![Inspector view]')
      result = leading_resource_reparse(page)
      expect(result.fetch('sameMarkup')).to be(true)
      expect(result.fetch('firstHtml')).to include('Public console', 'Download inspector', 'Inspector view')
      expect(result.fetch('markdown')).to include(
        '[Public console]', '[Download inspector]', '[Read reference]',
        '![Inspector view](https://assets.example.test/inspector.png)'
      )
      expect(result.fetch('html')).not_to include('data-fetchutil-reader-source-resource')
      %w[destination duplicate foreign].each do |mutation|
        changed = leading_resource_reparse(page, mutation)
        expect(changed.fetch('markdown')).not_to include('Public console', 'Download inspector', 'Read reference')
        expect(changed.fetch('markdown')).to include('![Inspector view](https://assets.example.test/inspector.png)')
        expect(changed.fetch('html')).to include("console.log(sample);  ")
      end
      changed_image = leading_resource_reparse(page, 'image')
      expect(changed_image.fetch('markdown')).not_to include('https://assets.example.test/unowned.png')
      expect(changed_image.fetch('markdown')).to include('[Public console]', '[Download inspector]', '[Read reference]')
      expect(changed_image.fetch('html')).to include("console.log(sample);  ")
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end

  it 'retains each independent resource in later authored sections' do
    extra = <<~HTML
      <section><h2>Independent tools</h2><p>The published tools supplement the complete procedure and retain their own reference destination for readers.</p>
      <div><a href="../tools/">Published tools</a></div></section>
      <section><h2>Independent repository</h2><p>The independent repository contains complete source material and preserves a separate authored reference.</p>
      <div><a href="../tools/">Repository edition</a></div></section>
    HTML
    with_url_page('https://publication.example.test/reports/sections/', resource_report('', extra)) do |page|
      before = page.evaluate('document.body.innerHTML')
      payload = extract(page)
      markdown = payload.fetch('markdown')
      expect(markdown).to include('[Published tools](https://publication.example.test/reports/tools/)',
                                  '[Repository edition](https://publication.example.test/reports/tools/)')
      expect(markdown.scan('https://publication.example.test/reports/tools/').size).to eq(2)
      expect(markdown.index('[Published tools]')).to be < markdown.index('[Repository edition]')
      expect(payload.fetch('html')).to include("console.log(sample);  ")
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end

  it 'keeps later resources source-bound across reparsing and excludes hidden navigation and closed content' do
    extra = <<~HTML
      <section><h2>Independent resources</h2><p>These published resources supplement the complete procedure with individually declared supporting destinations.</p>
      <div><a href="../tools/">Published tools</a></div>
      <div hidden><a href="../hidden/">Hidden later resource</a></div>
      <nav><div><a href="../account/">Account settings</a></div></nav>
      <details><summary>Optional evidence</summary><div><a href="../closed/">Closed later resource</a></div><pre><code>secret_later_program();</code></pre></details></section>
    HTML
    with_url_page('https://publication.example.test/reports/reparsed-sections/', resource_report('', extra)) do |page|
      before = page.evaluate('document.body.innerHTML')
      payload = extract(page)
      expect(payload.fetch('markdown')).to include('[Published tools]')
      expect(payload.fetch('markdown')).not_to include('Hidden later resource', 'Account settings', 'Closed later resource', 'secret_later_program();')
      exact = leading_resource_reparse(page)
      expect(exact.fetch('sameMarkup')).to be(true)
      expect(exact.fetch('markdown')).to include('[Published tools]')
      %w[destination duplicate foreign].each do |mutation|
        changed = leading_resource_reparse(page, mutation)
        expect(changed.fetch('markdown')).not_to include('Published tools')
        expect(changed.fetch('html')).to include("console.log(sample);  ")
      end
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end
end
