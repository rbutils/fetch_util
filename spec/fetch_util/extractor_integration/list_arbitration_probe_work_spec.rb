# frozen_string_literal: true

require 'spec_helper'
require 'open3'

RSpec.describe 'Read-only list arbitration probe work' do
  include_context 'extractor integration helpers'

  def list_probe_work_script
    directory = File.expand_path('../../../websieve', __dir__)
    source = File.readlines(File.join(directory, 'manifest.txt'), chomp: true)
                 .reject { |line| line.empty? || line.start_with?('#') }
                 .map { |file| File.read(File.join(directory, file)) }.join("\n")
    source.sub('})(window);', <<~JS)
      window.listProbeWork = function(mode, selectedHtml) {
        return withComposedDomRead(function() {
          var sourceBefore = document.body.outerHTML;
          var host = document.querySelector('#shadow-owner');
          var shadowBefore = host && host.shadowRoot && host.shadowRoot.innerHTML;
          var content = {contentType: mode === 'lazy' ? 'list' : 'article', readerMode: false,
            title: document.title, html: selectedHtml, markdown: 'Complete selected reference',
            textContent: 'Complete selected reference'};
          var contentBefore = JSON.stringify(content), original = pageContentProbe, probes = [];
          pageContentProbe = function(candidate) {
            var root = original.apply(null, arguments);
            probes.push({root: root, before: root.outerHTML, selected: !!candidate});
            return root;
          };
          var selected, dominant, probable;
          try {
            if (mode === 'standalone') {
              dominant = dominantIndexListPage(content);
              probable = isProbablyListPage(content);
              selected = content;
            } else {
              selected = selectIndexListCandidate(content, {title: document.title}, {}).content;
            }
            return {probeCount: probes.length, sameContent: selected === content,
              contentUnchanged: contentBefore === JSON.stringify(content),
              bodyUnchanged: sourceBefore === document.body.outerHTML,
              shadowUnchanged: shadowBefore === (host && host.shadowRoot && host.shadowRoot.innerHTML),
              probesUnchanged: probes.every(function(probe) { return probe.before === probe.root.outerHTML; }),
              dominant: dominant === true, probable: probable === true,
              snapshots: probes.map(function(probe) {
                return {selected: probe.selected,
                  markers: Array.from(probe.root.querySelectorAll('[data-proof]')).map(function(node) {
                    return node.getAttribute('data-proof');
                  }),
                  shadowVisible: probe.root.textContent.indexOf('Visible shadow reference') !== -1,
                  shadowHidden: probe.root.textContent.indexOf('Unpublished shadow reference') !== -1};
              })};
          } finally {
            pageContentProbe = original;
            probes.forEach(function(probe) { probe.root.replaceChildren(); });
          }
        })({});
      };
      })(window);
    JS
  end

  def probe_document(marker)
    explanation = 'This complete published explanation retains the independently authored details, ' \
                  'the original reading order and every declared resource without a collection of records.'
    paragraphs = (1..3).map do |number|
      "<p>#{explanation} Reference #{number}: <a href='/reference/#{number}?version=2#part'>full destination #{number}</a>.</p>"
    end.join
    "<main data-proof='#{marker}'><h1>Published reference</h1>#{paragraphs}</main>"
  end

  def with_probe_page
    html = "<title>Published reference</title>#{probe_document("physical")}<div id='shadow-owner'></div>"
    with_url_page('https://publication.example.test/category/reference/', html) do |page|
      page.add_script_tag(content: list_probe_work_script)
      yield page
    end
  end

  def expect_immutable_probes(result)
    expect(result).to include('sameContent' => true, 'contentUnchanged' => true,
                              'bodyUnchanged' => true, 'probesUnchanged' => true, 'shadowUnchanged' => true)
  end

  it 'constructs each of the two distinct read-only probe roles once per arbitration' do
    with_probe_page do |page|
      result = page.evaluate("listProbeWork('select', #{probe_document("selected").to_json})")
      expect_immutable_probes(result)
      expect(result.fetch('snapshots').map { |row| row.fetch('markers') }.uniq).to contain_exactly(['physical'], ['selected'])
      expect(result.fetch('probeCount')).to eq(2)
      expect(result.fetch('snapshots').map { |row| row.fetch('selected') }).to contain_exactly(false, true)
    end
  end

  it 'keeps standalone classifier calls fresh and preserves their complete read-only decisions' do
    with_probe_page do |page|
      result = page.evaluate("listProbeWork('standalone', #{probe_document("selected").to_json})")
      expect_immutable_probes(result)
      expect(result).to include('probeCount' => 4, 'dominant' => false, 'probable' => false)
      expect(result.fetch('snapshots').map { |row| row.fetch('markers') }).to eq(
        [['physical'], ['selected'], ['physical'], ['selected']]
      )
    end
  end

  it 'takes fresh physical and selected snapshots on the next invocation after either changes' do
    with_probe_page do |page|
      first = page.evaluate("listProbeWork('select', #{probe_document("selected").to_json})")
      page.evaluate("document.querySelector('main').setAttribute('data-proof', 'updated-physical')")
      second = page.evaluate("listProbeWork('select', #{probe_document("updated-selected").to_json})")
      expect_immutable_probes(first)
      expect_immutable_probes(second)
      expect(first.fetch('probeCount')).to eq(2)
      expect(second.fetch('probeCount')).to eq(2)
      expect(second.fetch('snapshots').map { |row| row.fetch('markers') }).to eq([['updated-physical'], ['updated-selected']])
    end
  end

  it 'preserves current composed-shadow visibility and the distinct selected-content role' do
    with_probe_page do |page|
      page.evaluate(<<~JS)
        document.querySelector('#shadow-owner').attachShadow({mode: 'open'}).innerHTML =
          '<p>Visible shadow reference</p><p style="display:none">Unpublished shadow reference</p>';
      JS
      result = page.evaluate("listProbeWork('select', #{probe_document("selected").to_json})")
      expect_immutable_probes(result)
      physical = result.fetch('snapshots').reject { |row| row.fetch('selected') }
      selected = result.fetch('snapshots').select { |row| row.fetch('selected') }
      expect(physical).to all(include('shadowVisible' => true, 'shadowHidden' => false))
      expect(selected).to all(include('shadowVisible' => false, 'shadowHidden' => false))
      expect(result.fetch('probeCount')).to eq(2)
    end
  end

  it 'does no eager probe work when index arbitration is ineligible' do
    with_probe_page do |page|
      result = page.evaluate("listProbeWork('lazy', #{probe_document("selected").to_json})")
      expect_immutable_probes(result)
      expect(result).to include('probeCount' => 0, 'snapshots' => [])
    end
  end

  it 'conserves complete compiled prose, literal programs and full reference values' do
    program = "first_value('<kept>')\n\nlast_value('&complete')"
    html = <<~HTML
      <title>Complete primary reference</title>
      <link rel='canonical' href='https://publication.example.test/reference.html'>
      <article><h1>Complete primary reference</h1>
      <p>Complete published prose retains every authored word and the
      <a href='/reference?group=all&amp;variant=2#complete'>complete declared reference</a>.</p>
      <pre><code>first_value('&lt;kept&gt;')

      last_value('&amp;complete')</code></pre>
      <p>Independent closing prose retains <strong>its complete emphasis</strong>.</p></article>
    HTML
    with_url_page('https://publication.example.test/reference.html', html) do |page|
      before = page.evaluate('document.body.outerHTML')
      payload = extract_payload(page, reader_mode: true)
      expect(page.evaluate('document.body.outerHTML')).to eq(before)
      parser = 'import sys; from markdown_it import MarkdownIt; print(MarkdownIt("commonmark").render(sys.stdin.read()))'
      markdown_html, error, status = Open3.capture3('python3', '-c', parser, stdin_data: payload.fetch('markdown'))
      expect(status.success?).to be(true), error
      [[Nokogiri::HTML.fragment(payload.fetch('html')), program],
       [Nokogiri::HTML.fragment(markdown_html), "#{program}\n"]].each do |root, expected_program|
        expect(root.css('pre').map(&:text)).to eq([expected_program])
        expect(root.css('a').map { |link| [link.text, link['href']] }).to eq(
          [['complete declared reference', 'https://publication.example.test/reference?group=all&variant=2#complete']]
        )
        expect(root.css('p').map { |node| node.text.gsub(/\s+/, ' ').strip }).to eq(
          ['Complete published prose retains every authored word and the complete declared reference.',
           'Independent closing prose retains its complete emphasis.']
        )
        expect(root.css('strong').map(&:text)).to eq(['its complete emphasis'])
      end
    end
  end
end
