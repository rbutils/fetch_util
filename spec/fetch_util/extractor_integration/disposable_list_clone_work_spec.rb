# frozen_string_literal: true

require 'spec_helper'
require 'cgi'
require 'open3'

RSpec.describe 'Consuming disposable list cleanup' do
  include_context 'extractor integration helpers'

  def complete_clone_program
    "first_value('<kept>')\n\nlast_value('&complete')"
  end

  def complete_clone_page(frame: false)
    rows = (1..12).map do |number|
      "<tr><td>#{number}</td><td><a href='/entry/#{number}'>Published entry #{number}</a></td>" \
        "<td><a href='/evidence/#{number}?view=complete#record'>Evidence #{number}</a></td>" \
        "<td><strong>Complete</strong> retained value #{number}</td></tr>"
    end.join
    resource = frame ? <<~HTML : ''
      <h2>Declared resource</h2><p>The complete narrative retains this independently declared resource.</p>
      <iframe title="Declared recording" src="https://media.example.test/embed/record?view=full&amp;part=2#start"></iframe>
    HTML
    <<~HTML
      <title>Complete published ledger</title>
      <link rel="canonical" href="https://publication.example.test/ledger.html">
      <main><article id="work-ledger"><h1>Complete published ledger</h1>
      <p>The complete ledger preserves every source row, value and independent reference.</p>
      <table><thead><tr><th>Number</th><th>Entry</th><th>Evidence</th><th>Value</th></tr></thead>
      <tbody>#{rows}<tr hidden><td>Private row</td><td>Private entry</td><td>Private evidence</td><td>Private value</td></tr></tbody></table>
      <pre id="literal-program"><code>#{CGI.escapeHTML(complete_clone_program)}</code></pre>
      #{resource}<details><summary>Deferred record</summary><p>Private closed record</p></details>
      </article></main>
    HTML
  end

  def disposable_list_clone_probe
    directory = File.expand_path('../../../websieve', __dir__)
    source = File.readlines(File.join(directory, 'manifest.txt'), chomp: true)
                 .reject { |line| line.empty? || line.start_with?('#') }
                 .map { |file| File.read(File.join(directory, file)) }.join("\n")
    source.sub('})(window);', <<~'JS')
      window.disposableListCloneProbe = function(mode) {
        return withInertDomWork(function() {
          return withComposedDomRead(function() {
            var source = document.getElementById('work-ledger'), before = document.body.outerHTML;
            if (mode === 'boundaries') {
              var physical = cleanDisposableClone(source);
              var owner = document.createElement('section'), child = safeDeepClone(source, document);
              owner.appendChild(child);
              var ownedBefore = owner.outerHTML, copied = cleanDisposableClone(child);
              var result = {physicalCopied: physical !== source, ownedChildCopied: copied !== child,
                ownedTreeUnchanged: owner.outerHTML === ownedBefore, sourceUnchanged: document.body.outerHTML === before};
              physical.replaceChildren(); copied.replaceChildren(); owner.replaceChildren();
              return result;
            }
            var originalImport = Document.prototype.importNode, copies = 0, active = true, cleaned;
            var map = mode === 'mapped' ? new Map() : null;
            Document.prototype.importNode = function(node, deep) {
              if (active && deep && node.nodeType === 1 && node.id === 'work-ledger') copies++;
              return originalImport.apply(this, arguments);
            };
            try { cleaned = visibleListClone(source, null, map); }
            finally { active = false; Document.prototype.importNode = originalImport; }
            var frame = source.querySelector('iframe');
            var mappedParagraphs = !!map && Array.from(source.querySelectorAll('p')).filter(function(node) {
              return !node.closest('details:not([open])');
            }).every(function(node) {
              var mapped = map.get(node);
              return mapped && cleaned.contains(mapped) && mapped.tagName === node.tagName && mapped.textContent === node.textContent;
            });
            var resources = Array.from(cleaned.querySelectorAll('a[href]')).filter(function(node) {
              return node.getAttribute('href') === 'https://media.example.test/embed/record?view=full&part=2#start';
            }).map(function(node) { return [node.tagName, node.getAttribute('href'), node.textContent]; });
            var result = {
              copies: copies, html: cleaned.outerHTML,
              programs: Array.from(cleaned.querySelectorAll('pre')).map(function(node) { return node.textContent; }),
              mappedRoot: !!map && map.get(source) === cleaned,
              mappedParagraphs: mappedParagraphs, retainedResources: resources,
              originalFrameStillPresent: !!frame && frame.tagName === 'IFRAME' && source.contains(frame),
              sourceUnchanged: document.body.outerHTML === before
            };
            cleaned.replaceChildren();
            return result;
          })({});
        })({});
      };
      })(window);
    JS
  end

  def expect_complete_clone_table(html)
    root = Nokogiri::HTML.fragment(html)
    expect(root.css('tbody tr').length).to eq(12)
    expect(root.css('td').map { |node| node.text.strip }).to eq((1..12).flat_map do |number|
      [number.to_s, "Published entry #{number}", "Evidence #{number}", "Complete retained value #{number}"]
    end)
    references = root.css('a[href]').select do |node|
      node['href'].include?('/entry/') || node['href'].include?('/evidence/')
    end
    expect(references.map { |node| node['href'] }).to eq((1..12).flat_map do |number|
      ["https://publication.example.test/entry/#{number}", "https://publication.example.test/evidence/#{number}?view=complete#record"]
    end)
    expect(root.css('strong').map(&:text)).to eq(Array.new(12, 'Complete'))
    expect(root.text).not_to include('Private row')
  end

  it 'imports the complete caller-owned list root only once while conserving all material' do
    with_url_page('https://publication.example.test/ledger.html', complete_clone_page) do |page|
      page.add_script_tag(content: disposable_list_clone_probe)
      result = page.evaluate("disposableListCloneProbe('plain')")
      expect_complete_clone_table(result.fetch('html'))
      expect(result.fetch('programs')).to eq([complete_clone_program])
      expect(result.fetch('sourceUnchanged')).to be(true)
      expect(result.fetch('copies')).to eq(1)
    end
  end

  it 'retains original source mappings and the complete independently declared frame resource' do
    with_url_page('https://publication.example.test/ledger.html', complete_clone_page(frame: true)) do |page|
      page.add_script_tag(content: disposable_list_clone_probe)
      result = page.evaluate("disposableListCloneProbe('mapped')")
      expect_complete_clone_table(result.fetch('html'))
      expect(result.fetch('programs')).to eq([complete_clone_program])
      expect(result).to include('mappedRoot' => true, 'mappedParagraphs' => true, 'originalFrameStillPresent' => true, 'sourceUnchanged' => true)
      expect(result.fetch('retainedResources')).to eq(
        [['A', 'https://media.example.test/embed/record?view=full&part=2#start', 'Declared recording']]
      )
    end
  end

  it 'copies physical source and children still owned by another inert tree' do
    with_url_page('https://publication.example.test/ledger.html', complete_clone_page) do |page|
      page.add_script_tag(content: disposable_list_clone_probe)
      expect(page.evaluate("disposableListCloneProbe('boundaries')")).to eq(
        'physicalCopied' => true, 'ownedChildCopied' => true, 'ownedTreeUnchanged' => true, 'sourceUnchanged' => true
      )
    end
  end

  it 'preserves complete compiled table output, literal programs and hidden or closed boundaries' do
    with_url_page('https://publication.example.test/ledger.html', complete_clone_page) do |page|
      before = page.evaluate('document.body.outerHTML')
      result = extract_payload(page, reader_mode: true)
      script = "import sys,json;from markdown_it import MarkdownIt;print(json.dumps(MarkdownIt('commonmark').enable('table').render(sys.stdin.read())))"
      output, error, status = Open3.capture3('python3', '-c', script, stdin_data: result.fetch('markdown'))
      expect(status.success?).to be(true), error
      [result.fetch('html'), JSON.parse(output)].each do |html|
        expect_complete_clone_table(html)
        expect(Nokogiri::HTML.fragment(html).css('pre').map { |node| node.text.delete_suffix("\n") }).to eq([complete_clone_program])
      end
      expect(result.fetch('markdown')).to include('Deferred record')
      expect(result.fetch('markdown')).not_to include('Private closed record', 'Private row')
      expect(page.evaluate('document.body.outerHTML')).to eq(before)
    end
  end
end
