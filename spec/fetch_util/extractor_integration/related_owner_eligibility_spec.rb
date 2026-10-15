# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Related article cleanup eligibility' do
  include_context 'extractor integration helpers'

  def ownership_probe
    directory = File.expand_path('../../../websieve', __dir__)
    source = File.readlines(File.join(directory, 'manifest.txt'), chomp: true)
                 .reject { |line| line.empty? || line.start_with?('#') }
                 .map { |file| File.read(File.join(directory, file)) }.join("\n")
    export = <<~JS
      window.relatedOwnerProbe = withComposedDomRead(function(options) {
        var reads = 0;
        var original = relatedRailSourceArticle;
        relatedRailSourceArticle = function() { reads++; return original.apply(null, arguments); };
        var results = [];
        try {
          options.fragments.forEach(function(html) {
            var root = document.createElement('div');
            root.innerHTML = html;
            if (options.stripSections) {
              stripRelatedSectionsByHeading(root);
              results.push(root.innerHTML);
            } else {
              results.push(relatedRailRootOwnsArticle(root));
            }
          });
          return { reads: reads, results: results };
        } finally {
          relatedRailSourceArticle = original;
        }
      });
      })(window);
    JS
    source.sub('})(window);', export)
  end

  it 'avoids source-wide article work for every ineligible fragment' do
    prose = (1..240).map { |index| "<p>Published evidence #{index} records complete measurements and references.</p>" }.join
    html = "<html><head><title>Published field report</title></head><body><article><h1>Published field report</h1>#{prose}</article></body></html>"

    with_url_page('https://publication.example.test/report', html) do |page|
      before = page.evaluate('document.body.innerHTML')
      page.add_script_tag(content: ownership_probe)
      fragments = (1..240).map { |index| "<section><h2>Authored section #{index}</h2><p>Complete independent context.</p></section>" }
      fragments << '<article hidden><h1>Published field report</h1><p>Hidden material.</p></article>'
      result = page.evaluate("window.relatedOwnerProbe(#{JSON.generate(fragments: fragments)})")

      expect(result.fetch('reads')).to eq(0)
      expect(result.fetch('results')).to eq(Array.new(241, false))
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end

  it 'retains positive, foreign and incomplete selected-article ownership decisions' do
    article = <<~HTML
      <article><h1>Published field report</h1>
      <p>The complete report records independent measurements, the published methodology, and the sources used by investigators.</p>
      <p>Residents can inspect all original evidence and compare the complete public findings with earlier measurements.</p></article>
    HTML

    with_url_page('https://publication.example.test/report', "<html><head><title>Published field report</title></head><body>#{article}</body></html>") do |page|
      before = page.evaluate('document.body.innerHTML')
      page.add_script_tag(content: ownership_probe)
      fragments = [article, article.sub('Published field report', 'Independent foreign report'), '<article><h1>Published field report</h1></article>']
      result = page.evaluate("window.relatedOwnerProbe(#{JSON.generate(fragments: fragments)})")

      expect(result.fetch('reads')).to eq(3)
      expect(result.fetch('results')).to eq([true, false, false])
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end

  it 'retains complete ordinary article sections without source ownership reconstruction' do
    sections = (1..240).map do |number|
      "<section><h2>Published section #{number}</h2><p>Complete published evidence #{number} explains the source, " \
        "its measurements and all independently authored conclusions.</p><pre><code>complete_example_#{number}();</code></pre></section>"
    end.join
    article = "<article><h1>Published reference manual</h1>#{sections}</article>"
    with_url_page('https://publication.example.test/reference/manual', article) do |page|
      before = page.evaluate('document.body.innerHTML')
      page.add_script_tag(content: ownership_probe)
      result = page.evaluate("relatedOwnerProbe(#{JSON.generate(fragments: [article], stripSections: true)})")
      expect(result.fetch('reads')).to eq(0)
      expect(result.fetch('results')).to eq([article])
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end

  it 'continues proving and removing source-owned related-record sections' do
    reporting = '<h1>Published field report</h1>' \
                '<p>The complete report records independent measurements and all evidence supporting the published findings.</p>' \
                '<p>Residents can inspect the source methodology and compare the complete findings with earlier measurements.</p>'
    cards = (1..3).map { |number| "<article><h3>Separate related report #{number}</h3><time>2026-10-0#{number}</time></article>" }.join
    article = "<article>#{reporting}<section><h2>Related:</h2>#{cards}</section></article>"
    with_url_page('https://publication.example.test/report', article) do |page|
      before = page.evaluate('document.body.innerHTML')
      page.add_script_tag(content: ownership_probe)
      result = page.evaluate("relatedOwnerProbe(#{JSON.generate(fragments: [article], stripSections: true)})")
      expect(result.fetch('reads')).to be_positive
      expect(result.fetch('results')).to eq(["<article>#{reporting}</article>"])
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end

  it 'shares ancestor rail decisions only within a read and observes later clone changes' do
    sections = (1..240).map do |number|
      "<section><h2>Published section #{number}</h2><div><p>Complete authored evidence #{number} records all measurements.</p>" \
        "<p>Independent explanation #{number} retains the complete methodology and its conclusions.</p>" \
        '<h3>References</h3><p>These independently published references remain part of the original work.</p></div></section>'
    end.join
    article = "<article><h1>Published reference manual</h1>#{sections}</article>"
    with_url_page('https://publication.example.test/reference/manual', article) do |page|
      before = page.evaluate('document.body.innerHTML')
      probe = ownership_probe.sub('var reads = 0;', <<~JS)
        var reads = 0, railReads = 0, originalRail = relatedHeadingRecordRail;
        relatedHeadingRecordRail = function(node) { railReads++; return originalRail(node); };
      JS
      probe = probe.sub('return { reads: reads, results: results };', <<~JS)
        return {reads: reads, results: results, railReads: railReads,
          ownerCount: document.querySelector('article').querySelectorAll('div, section').length};
      JS
      probe = probe.sub('relatedRailSourceArticle = original;', 'relatedRailSourceArticle = original; relatedHeadingRecordRail = originalRail;')
      page.add_script_tag(content: probe)
      result = page.evaluate("relatedOwnerProbe(#{JSON.generate(fragments: [article])})")
      expect(result.fetch('railReads')).to be <= result.fetch('ownerCount') * 2
      # Repeated published references are intentionally ambiguous for exact
      # paragraph ownership; that original decision is not relaxed by reuse.
      expect(result.fetch('results')).to eq([false])
      changed = article.sub('Published reference manual', 'Independent foreign work')
      result = page.evaluate("relatedOwnerProbe(#{JSON.generate(fragments: [changed, article])})")
      expect(result.fetch('results')).to eq([false, false])
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end

  it 'rechecks the same selected tree after ownership and related-label mutations' do
    article = '<article><h1>Published field report</h1><section><h2>Published section</h2>' \
              '<p>The complete report records independent measurements and all supporting evidence.</p>' \
              '<p>The complete methodology explains every measurement and independently authored conclusion.</p></section></article>'
    with_url_page('https://publication.example.test/report', article) do |page|
      before = page.evaluate('document.body.innerHTML')
      probe = ownership_probe.sub('options.fragments.forEach(function(html) {', <<~JS)
        if (options.mutateSelected) {
          var selected = document.querySelector('article').cloneNode(true);
          var first = relatedRailRootOwnsArticle(selected);
          selected.querySelector('h1').textContent = 'Independent foreign work';
          var foreign = relatedRailRootOwnsArticle(selected);
          selected.querySelector('h1').textContent = 'Published field report';
          var restored = relatedRailRootOwnsArticle(selected);
          selected.querySelector('h2').textContent = 'Related';
          var relabeled = relatedRailRootOwnsArticle(selected);
          return {first: first, foreign: foreign, restored: restored, relabeled: relabeled};
        }
        options.fragments.forEach(function(html) {
      JS
      page.add_script_tag(content: probe)
      expect(page.evaluate('relatedOwnerProbe({mutateSelected: true})')).to eq('first' => true, 'foreign' => false, 'restored' => true, 'relabeled' => true)
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end
end
