# frozen_string_literal: true

require 'spec_helper'
require 'cgi'

RSpec.describe 'Retained physical Reader headline roles' do
  include_context 'extractor integration helpers'

  def role_program
    "const report = '<h1>not a heading</h1>';\nconst exact = '  preserved';"
  end

  def role_paragraphs
    (1..6).map do |index|
      "<p>Measured record #{index} preserves the complete river observations, original sampling methodology, " \
        "independent laboratory measurements and all recorded downstream results in their source order.</p>"
    end.join
  end

  def role_page(title:, heading: '<h1 id="physical-headline">Observed <em>River</em> Measurements</h1>', outside: '')
    <<~HTML
      <!doctype html><html><head><title>#{title}</title></head><body>
      #{outside}<main><header>#{heading}</header>#{role_paragraphs}
      <h2 id="method">Measurement method</h2>
      <p>Use the <a href="/sampling-reference">complete sampling reference</a> for the original protocol.</p>
      <pre><code>#{CGI.escapeHTML(role_program)}</code></pre>
      <img src="/river.jpg" alt="Observed river channel">
      </main></body></html>
    HTML
  end

  def reader_role_result(page)
    extract_payload(page)
    root = File.expand_path('../../..', __dir__)
    source = File.readlines(File.join(root, 'websieve/manifest.txt'), chomp: true)
                 .reject { |path| path.empty? || path.start_with?('#') }
                 .map { |path| File.read(File.join(root, 'websieve', path)) }.join("\n")
    page.add_script_tag(content: source.sub('})(window);', 'window.__readerRoleContent = readabilityContent; })(window);'))
    page.evaluate(<<~JS)
      (() => {
        const before = document.body.innerHTML;
        const result = window.__readerRoleContent({title: document.title, siteName: 'Research Library'});
        const template = document.createElement('template');
        template.innerHTML = result.html;
        return {
          result,
          declaredTitle: document.title,
          headings: Array.from(template.content.querySelectorAll('h1,h2')).map(node => [node.localName, node.textContent]),
          paragraphs: Array.from(template.content.querySelectorAll('p')).map(node => node.textContent),
          programs: Array.from(template.content.querySelectorAll('pre')).map(node => node.textContent),
          references: Array.from(template.content.querySelectorAll('a[href]')).map(node => [node.textContent, node.getAttribute('href')]),
          images: Array.from(template.content.querySelectorAll('img')).map(node => [node.getAttribute('alt'), node.getAttribute('src')]),
          before, after: document.body.innerHTML
        };
      })()
    JS
  end

  def expect_complete_reader_role_material(result)
    (1..6).each do |index|
      expect(result.fetch('paragraphs').count do |text|
        text == "Measured record #{index} preserves the complete river observations, original sampling methodology, " \
                'independent laboratory measurements and all recorded downstream results in their source order.'
      end).to eq(1)
    end
    expect(result.fetch('headings')).to include(['h2', 'Measurement method'])
    expect(result.fetch('programs')).to eq([role_program])
    expect(result.fetch('references')).to eq([['complete sampling reference', 'https://publication.example.test/sampling-reference']])
    expect(result.fetch('images')).to eq([['Observed river channel', 'https://publication.example.test/river.jpg']])
    expect(result.fetch('after')).to eq(result.fetch('before'))
  end

  it 'keeps an already retained source H1 without replacing a different declared title' do
    title = 'Independent catalogue reference for measurement data'
    with_url_page('https://publication.example.test/data/reference', role_page(title: title)) do |page|
      result = reader_role_result(page)
      expect(result.fetch('headings').count { |heading| heading == ['h1', 'Observed River Measurements'] }).to eq(1)
      expect(result.fetch('headings')).not_to include(['h2', 'Observed River Measurements'])
      expect(result.fetch('result').fetch('title')).to be_nil
      expect(result.fetch('declaredTitle')).to eq(title)
      expect_complete_reader_role_material(result)
    end
  end

  it 'keeps the physical H1 in semantic main ownership without requiring class-name heuristics' do
    title = 'Observed River Measurements | Independent Data Publishing Research Archive'
    with_url_page('https://publication.example.test/data/reference', role_page(title: title)) do |page|
      result = reader_role_result(page)
      expect(result.fetch('headings').count { |heading| heading == ['h1', 'Observed River Measurements'] }).to eq(1)
      expect(result.fetch('headings')).not_to include(['h2', 'Observed River Measurements'])
      expect(result.fetch('result').fetch('title')).to be_nil
      expect(result.fetch('declaredTitle')).to eq(title)
      expect_complete_reader_role_material(result)
    end
  end

  it 'leaves foreign, competing and hidden source headlines conservative and all literal material intact' do
    variants = [
      role_page(title: 'Independent catalogue reference for measurement data',
                heading: '<h2>Observed River Measurements</h2>', outside: '<header><h1>Foreign publication title</h1></header>'),
      role_page(title: 'Independent catalogue reference for measurement data',
                heading: '<h1>Observed River Measurements</h1><h1>Independent second record</h1>'),
      role_page(title: 'Independent catalogue reference for measurement data',
                heading: '<h1 hidden>Private hidden record</h1><h2>Observed River Measurements</h2>')
    ]
    variants.each do |html|
      with_url_page('https://publication.example.test/data/reference', html) do |page|
        result = reader_role_result(page)
        expect(result.fetch('headings').none? { |heading| heading.first == 'h1' }).to be(true)
        expect(result.fetch('result').fetch('html')).not_to include('Private hidden record')
        expect_complete_reader_role_material(result)
      end
    end
  end
end
