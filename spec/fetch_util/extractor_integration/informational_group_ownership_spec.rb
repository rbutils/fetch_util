# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'FetchUtil source-owned information during list cleanup' do
  include_context 'extractor integration helpers'

  def information_cleanup_probe
    root = ENV.fetch('FETCH_UTIL_BOUND_SOURCE_ROOT') { File.expand_path('../../..', __dir__) }
    directory = File.join(root, 'websieve')
    source = File.readlines(File.join(directory, 'manifest.txt'), chomp: true)
                 .reject { |name| name.empty? || name.start_with?('#') }
                 .map { |name| File.read(File.join(directory, name)) }.join("\n")
    raise 'private closure changed' unless source.scan('})(window);').length == 1

    source.sub('})(window);', <<~JS)
      window.informationCleanupProbe = function(mode) {
        return withInertDomWork(function() {
          return withComposedDomRead(function() {
            var source = document.getElementById('publication'), before = source.outerHTML;
            if (mode === 'classify') {
              var classifications = Array.from(source.querySelectorAll('[data-probe]')).map(function(node) {
                return [node.getAttribute('data-probe'), listChromeNode(node)];
              });
              return {classifications: classifications, sourceUnchanged: source.outerHTML === before};
            }
            var clone = visibleListClone(source);
            var beforeCleanup = clone.outerHTML;
            cleanupListRoot(clone);
            var result = {
              before: beforeCleanup,
              after: clone.outerHTML,
              headings: Array.from(clone.querySelectorAll('h2, h3')).map(function(node) {
                return [node.tagName, node.textContent];
              }),
              paragraphs: Array.from(clone.querySelectorAll('p')).map(function(node) { return node.textContent; }),
              references: Array.from(clone.querySelectorAll('a[href]')).map(function(node) {
                return [node.textContent, node.getAttribute('href')];
              }),
              programs: Array.from(clone.querySelectorAll('pre')).map(function(node) { return node.textContent; }),
              sourceUnchanged: source.outerHTML === before
            };
            clone.replaceChildren();
            return result;
          })({});
        })({});
      };
      })(window);
    JS
  end

  def assessment_group(identifier, verdict)
    <<~HTML
      <div class="assessment" id="#{identifier}">
        <div class="assessment__header"><h3 class="assessment__header-title">Declared scope</h3><p class="assessment__header-text">Complete physical statement.</p></div>
        <div class="assessment__subject"><a href="https://inspection.example.test/report?subject=publication&amp;edition=2#evidence">Publication record</a></div>
        <div class="assessment__footer"><h3 class="assessment__footer-title">#{verdict}</h3><p class="assessment__footer-text">Checked by <a class="assessment__footer-link" href="https://inspection.example.test/">Independent inspection</a>.</p></div>
        <p>2026 assessment edition.</p>
      </div>
    HTML
  end

  def with_information_cleanup(material)
    html = <<~HTML
      <title>Reference publication</title><div id="publication"><h2>Independent reference assessments</h2>
      #{material}<pre><code>verify("&lt;complete&gt;")

      finish("a&amp;b")</code></pre><p>The final authored limitations remain complete.</p></div>
    HTML
    with_url_page('https://publication.example.test/', html) do |page|
      before = page.evaluate('document.body.outerHTML')
      page.add_script_tag(content: information_cleanup_probe)
      result = page.evaluate('informationCleanupProbe()')
      expect(result.fetch('sourceUnchanged')).to eq(true)
      expect(page.evaluate('document.body.outerHTML')).to eq(before)
      expect(result.fetch('programs')).to eq(["verify(\"<complete>\")\n\nfinish(\"a&b\")"])
      expect(result.fetch('paragraphs')).to include('The final authored limitations remain complete.')
      yield result
    end
  end

  it 'keeps complete informational heading and paragraph owners despite header and footer class tokens' do
    with_information_cleanup(assessment_group('assessment-one', 'Complete and checked')) do |result|
      expect(result.fetch('headings')).to eq(
        [
          ['H2', 'Independent reference assessments'], ['H3', 'Declared scope'], ['H3', 'Complete and checked']
        ]
      )
      expect(result.fetch('paragraphs')).to eq(
        [
          'Complete physical statement.', 'Checked by Independent inspection.', '2026 assessment edition.',
          'The final authored limitations remain complete.'
        ]
      )
      expect(result.fetch('references')).to eq(
        [
          ['Publication record', 'https://inspection.example.test/report?subject=publication&edition=2#evidence'],
          ['Independent inspection', 'https://inspection.example.test/']
        ]
      )
    end
  end

  it 'preserves independent information owners and repeated destinations in physical source order' do
    material = assessment_group('first-assessment', 'First complete assessment') +
               assessment_group('second-assessment', 'Second complete assessment')
    with_information_cleanup(material) do |result|
      expect(result.fetch('headings')).to eq(
        [
          ['H2', 'Independent reference assessments'], ['H3', 'Declared scope'], ['H3', 'First complete assessment'],
          ['H3', 'Declared scope'], ['H3', 'Second complete assessment']
        ]
      )
      expect(result.fetch('references')).to eq(
        [
          ['Publication record', 'https://inspection.example.test/report?subject=publication&edition=2#evidence'],
          ['Independent inspection', 'https://inspection.example.test/'],
          ['Publication record', 'https://inspection.example.test/report?subject=publication&edition=2#evidence'],
          ['Independent inspection', 'https://inspection.example.test/']
        ]
      )
      expect(result.fetch('paragraphs').count('Complete physical statement.')).to eq(2)
    end
  end

  it 'requires complete physical ownership and keeps actual interface and hidden boundaries' do
    group = assessment_group('control', 'Complete and checked')
    variants = {
      'missing-peer' => group.sub(%r{<div class="assessment__footer">.*?</div>}, ''),
      'missing-subject' => group.sub(%r{<div class="assessment__subject">.*?</div>}, ''),
      'unsafe-subject' => group.sub('https://inspection.example.test/report?subject=publication&amp;edition=2#evidence', 'javascript:void(0)'),
      'linked-heading' => group.sub('Declared scope</h3>', '<a href="/other">Declared scope</a></h3>'),
      'links-only-prose' => group.sub('Complete physical statement.', '<a href="/menu">Only a destination</a>'),
      'navigation' => "<nav>#{group}</nav>",
      'toolbar' => "<div role=\"toolbar\">#{group}</div>",
      'form' => "<form>#{group}</form>",
      'control' => group.sub('<p>2026', '<button>Choose</button><p>2026'),
      'hidden' => "<div hidden>#{group}</div>",
      'closed' => "<details><summary>Assessment</summary>#{group}</details>"
    }
    markup = variants.map do |name, value|
      value.gsub('id="control"', "id=\"#{name}\"")
           .sub('class="assessment__header"', "class=\"assessment__header\" data-probe=\"#{name}\"")
    end.join
    positive = assessment_group('complete', 'Complete and checked').sub(
      'class="assessment__header"', 'class="assessment__header" data-probe="complete"'
    )
    html = "<title>Information boundary controls</title><div id=\"publication\">#{markup}#{positive}</div>"
    with_url_page('https://publication.example.test/', html) do |page|
      before = page.evaluate('document.body.outerHTML')
      page.add_script_tag(content: information_cleanup_probe)
      result = page.evaluate("informationCleanupProbe('classify')")
      expect(result.fetch('classifications')).to eq(variants.keys.map { |name| [name, true] } + [['complete', false]])
      expect(result.fetch('sourceUnchanged')).to eq(true)
      expect(page.evaluate('document.body.outerHTML')).to eq(before)
    end
  end
end
