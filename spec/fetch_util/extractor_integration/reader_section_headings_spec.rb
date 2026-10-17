# frozen_string_literal: true

require 'spec_helper'
require 'nokogiri'

RSpec.describe 'Source-owned reader section headings', :integration do
  include_context 'extractor integration helpers'

  def section_heading_page(sections: 53)
    body = (1..sections).map do |index|
      <<~HTML
        <h2 id="foot-section-#{index}"><a href="/records/#{index}"><code>Dataset #{index}</code></a></h2>
        <p id="paragraph-#{index}">This independently authored explanation #{index} describes the complete dataset,
        its observable properties, use and limitations. <a href="/details/#{index}">Read source #{index}</a>.</p>
      HTML
    end.join
    <<~HTML
      <!doctype html><html lang="en"><head><title>A public source guide - Example Review</title></head>
      <body><div class="post"><h1>A public source guide</h1>
      <p>Independent reporting introduces the current source collection and explains its scope with complete authored context.</p>
      #{body}
      <h3 id="share-own-sources"><em>Contribute your own sources</em></h3>
      <p id="contribution">The author invites readers to contribute additional public sources and corrections to this published guide.</p>
      <pre><code class="language-text">complete_program(value)
      preserve_every_instruction</code></pre>
      <h3 id="share-controls">Network sharing controls</h3>
      <p><a href="/network">A sufficiently long network-control label has no independent authored paragraph around its link.</a></p>
      <h2 id="foot-hidden" style="display:none">Unpublished hidden section</h2>
      <p>A published paragraph remains readable while its separate unpublished heading stays hidden throughout extraction.</p>
      </div></body></html>
    HTML
  end

  def reader_section_probe_script
    paths = File.read(File.expand_path('../../../websieve/manifest.txt', __dir__)).lines.map(&:strip)
                .reject { |line| line.empty? || line.start_with?('#') }
    source = paths.map { |path| File.read(File.expand_path("../../../websieve/#{path}", __dir__)) }.join("\n")
    boundary = '})(window);'
    expect(source.scan(boundary).length).to eq(1)
    expose = <<~JS
      global.readerSectionProbe = function() {
        return withComposedDomRead(function() {
          var clone = safeReadableDocumentClone();
          var mappings = new Map();
          pruneHiddenClone(document.documentElement, clone.documentElement, null, null, null, mappings);
          var identities = markReadabilitySourceNodeProvenance(clone, mappings, 'section-probe');
          var snapshots = readerSectionHeadingSnapshots(clone, {title: document.title}, mappings, identities, 'section-probe');
          return snapshots ? snapshots.headings.map(function(heading) { return heading.id; }) : [];
        })({});
      };
    JS
    source.sub(boundary, "#{expose}\n#{boundary}")
  end

  it 'retains every identified section, inline label, destination and following paragraph in source order' do
    with_url_page('https://reference.example.test/guide', section_heading_page) do |page|
      before = page.evaluate('document.body.innerHTML')
      result = extract(page)
      html = Nokogiri::HTML5.fragment(result.fetch('html'))
      headings = html.css('h2[id^="foot-section-"]')
      expect(headings.map { |node| node['id'] }).to eq((1..53).map { |index| "foot-section-#{index}" })
      headings.each_with_index do |heading, offset|
        index = offset + 1
        expect(heading.at_css('a')['href']).to eq("https://reference.example.test/records/#{index}")
        expect(heading.at_css('code').text).to eq("Dataset #{index}")
        expect(heading.next_element['id']).to eq("paragraph-#{index}")
        expect(result.fetch('markdown')).to include("## [`Dataset #{index}`](https://reference.example.test/records/#{index})")
      end
      expect(html.at_css('#share-own-sources').name).to eq('h3')
      expect(html.at_css('#share-own-sources em').text).to eq('Contribute your own sources')
      expect(html.at_css('#contribution').previous_element['id']).to eq('share-own-sources')
      expect(result.fetch('markdown')).to match(/^### [*_]Contribute your own sources[*_]$/)
      expect(result.fetch('markdown')).to include('complete_program(value)', 'preserve_every_instruction')
      expect(html.at_css('#share-controls')).to be_nil
      expect(result.fetch('markdown')).not_to include('Unpublished hidden section')
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end

  it 'records every physical section in a complete large article without changing the source' do
    with_url_page('https://reference.example.test/guide', section_heading_page(sections: 603)) do |page|
      page.evaluate(reader_section_probe_script)
      before = page.evaluate('document.body.innerHTML')
      actual = page.evaluate('window.readerSectionProbe()')
      expect(actual).to eq((1..603).map { |index| "foot-section-#{index}" } + ['share-own-sources'])
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end

  it 'declines duplicate, hidden, unbounded and control-only sources while refreshing restored ownership' do
    with_url_page('https://reference.example.test/guide', section_heading_page(sections: 3)) do |page|
      page.evaluate(reader_section_probe_script)
      before = page.evaluate('document.body.innerHTML')
      evidence = page.evaluate(<<~JS)
        (() => {
          const original = document.body.innerHTML;
          const ordinary = window.readerSectionProbe();
          const outcomes = [];
          const changes = [
            () => document.querySelector('#foot-section-2').id = 'foot-section-1',
            () => document.querySelector('#foot-section-1').style.display = 'none',
            () => document.querySelector('#foot-section-1').removeAttribute('id'),
            () => document.querySelector('#paragraph-1').innerHTML = '<a href="/control">A long control label without independent prose surrounding the active control destination.</a>',
            () => document.querySelector('.post').before(document.querySelector('h1')),
            () => document.querySelector('h1').textContent = 'A conflicting publication heading'
          ];
          for (const change of changes) {
            change();
            outcomes.push(!window.readerSectionProbe().includes('foot-section-1'));
            document.body.innerHTML = original;
          }
          return {ordinary, outcomes, restored: window.readerSectionProbe(), unchanged: document.body.innerHTML === original};
        })()
      JS
      expect(evidence.fetch('ordinary')).to eq(%w[foot-section-1 foot-section-2 foot-section-3 share-own-sources])
      expect(evidence.fetch('outcomes')).to eq([true] * 6)
      expect(evidence.fetch('restored')).to eq(evidence.fetch('ordinary'))
      expect(evidence.fetch('unchanged')).to be(true)
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end
end
