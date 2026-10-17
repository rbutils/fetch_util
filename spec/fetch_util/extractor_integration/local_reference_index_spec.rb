# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Authored local reference indexes', :integration do
  include_context 'extractor integration helpers'

  def local_reference_markup(groups: 67, entries: 9)
    records = (1..(groups * entries)).to_a
    categories = records.each_slice(entries).map.with_index do |indices, index|
      links = indices.map { |number| %(<li><a href="#record-#{number}"><code>Record#{number}</code></a></li>) }.join
      "<li>Category #{index + 1}<ul>#{links}</ul></li>"
    end.join
    sections = records.map do |number|
      <<~HTML
        <h3 id="record-#{number}">Record#{number}</h3>
        <p>The independently authored description for record #{number} explains its complete public properties and limitations.</p>
      HTML
    end.join
    <<~HTML
      <div><h2>A source collection</h2><p>Jump to a specific source:</p><ul>#{categories}</ul>
      #{sections}<pre><code>complete_reference_program()
      preserve_all_values</code></pre></div>
    HTML
  end

  def install_local_reference_probe(page)
    extract(page)
    paths = File.read(File.expand_path('../../../websieve/manifest.txt', __dir__)).lines.map(&:strip)
                .reject { |line| line.empty? || line.start_with?('#') }
    source = paths.map { |path| File.read(File.expand_path("../../../websieve/#{path}", __dir__)) }.join("\n")
    boundary = '})(window);'
    expect(source.scan(boundary).length).to eq(1)
    expose = <<~JS
      global.localReferenceMarkdown = function(html) { return markdownFor(html); };
      global.localReferenceEvidence = function(html, change) {
        var root = document.createElement('div');
        root.innerHTML = html;
        if (change) change(root);
        var reader = authoredLocalReferenceIndexReader(root);
        return Array.from(root.querySelectorAll('ul, ol')).some(reader);
      };
    JS
    page.evaluate(source.sub(boundary, "#{expose}\n#{boundary}"))
  end

  def local_reference_page
    <<~HTML
      <!doctype html><html lang="en"><head><title>A reference collection</title></head>
      <body><main><h1>A reference collection</h1>
      <p>Independent public information provides complete source context for the current reference collection and its limitations.</p>
      </main></body></html>
    HTML
  end

  it 'retains every authored local reference, inline label and program in source order without a cap' do
    with_url_page('https://reference.example.test/guide', local_reference_page) do |page|
      install_local_reference_probe(page)
      before = page.evaluate('document.body.innerHTML')
      markdown = page.evaluate('window.localReferenceMarkdown(arguments[0])', local_reference_markup)
      expect(markdown.scan(%r{\]\(https://reference\.example\.test/guide#record-(\d+)\)}).flatten.map(&:to_i))
        .to eq((1..603).to_a)
      (1..603).each do |number|
        expect(markdown).to include("[`Record#{number}`](https://reference.example.test/guide#record-#{number})")
      end
      expect(markdown).to include('complete_reference_program()', 'preserve_all_values')
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end

  it 'keeps unresolved stated references without inventing targets when independent sections prove the index' do
    with_url_page('https://reference.example.test/guide', local_reference_page) do |page|
      install_local_reference_probe(page)
      markup = local_reference_markup(groups: 1)
               .sub('<li><a href="#record-1">', '<li><a href="#unresolved-source">')
      markdown = page.evaluate('window.localReferenceMarkdown(arguments[0])', markup)
      expect(markdown).to include('[`Record1`](https://reference.example.test/guide#unresolved-source)')
      expect(markdown.scan(%r{\]\(https://reference\.example\.test/guide#record-\d+\)}).length).to eq(8)
      expect(markdown).to include('### Record1')
      expect(markdown).not_to include('id="unresolved-source"')
    end
  end

  it 'rejects navigation, foreign, ambiguous and nonnarrative evidence and refreshes after source changes' do
    with_url_page('https://reference.example.test/guide', local_reference_page) do |page|
      install_local_reference_probe(page)
      actual = page.evaluate(<<~JS, local_reference_markup(groups: 1))
        ((html) => {
          const changes = [
            root => root.querySelector('ul').setAttribute('role', 'navigation'),
            root => root.querySelector('ul > li').setAttribute('role', 'menuitem'),
            root => root.querySelectorAll('ul a').forEach(a => a.href = '/different-page' + new URL(a.href).hash),
            root => root.querySelectorAll('h3').forEach(h => h.replaceWith(Object.assign(document.createElement('div'), {id: h.id}))),
            root => root.querySelectorAll('h3').forEach(h => h.after(h.cloneNode(true))),
            root => root.querySelector('ul').previousElementSibling.remove(),
            root => root.querySelectorAll('h3 + p').forEach(p => p.innerHTML = '<a href="/control">A long control label has no independently authored prose outside the control destination.</a>')
          ];
          return {
            ordinary: window.localReferenceEvidence(html),
            outcomes: changes.map(change => window.localReferenceEvidence(html, change)),
            restored: window.localReferenceEvidence(html)
          };
        })(arguments[0])
      JS
      expect(actual.fetch('ordinary')).to be(true)
      expect(actual.fetch('outcomes')).to eq([false] * 7)
      expect(actual.fetch('restored')).to be(true)
    end
  end
end
