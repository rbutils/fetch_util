# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Source-owned terminal article furniture' do
  include_context 'extractor integration helpers'

  def article_with_terminal_furniture(furniture)
    <<~HTML
      <!doctype html>
      <html><head><title>Regional transport funding report</title></head><body><main><article>
        <h1>Regional transport funding report</h1>
        <p>The report explains the approved funding, the affected clinics, and the implementation timetable for the next fiscal year.</p>
        <p>Officials documented the public consultation and the evidence used to select the regional projects.</p>
        #{furniture}
      </article></main></body></html>
    HTML
  end

  def terminal_furniture_probe(page, inject_unowned_paragraph: false)
    project_root = File.expand_path('../../..', __dir__)
    source_root = File.join(project_root, 'websieve')
    sources = File.readlines(File.join(source_root, 'manifest.txt'), chomp: true)
                  .reject { |path| path.empty? || path.start_with?('#') }
                  .map { |path| File.read(File.join(source_root, path)) }.join("\n")
    outro = File.read(File.join(source_root, '99_outro.js'))
    sources = sources.delete_suffix(outro) + <<~JS + outro
      window.__terminalArticleFurnitureProbe = function(injectUnownedParagraph) {
        var source = document.querySelector('article');
        var before = source.outerHTML;
        var selected = source.cloneNode(true);
        var sourceClones = new WeakMap();
        function mapClone(original, clone) {
          sourceClones.set(original, clone);
          Array.from(original.childNodes).forEach(function(child, index) {
            mapClone(child, clone.childNodes[index]);
          });
        }
        mapClone(source, selected);
        if (injectUnownedParagraph) {
          var paragraph = document.createElement('p');
          paragraph.textContent = 'An unmapped sentence was added to the selected article root.';
          selected.appendChild(paragraph);
        }
        stripSourceOwnedTerminalArticleFurniture(selected, sourceClones);
        return {html: selected.outerHTML, sourceUnchanged: source.outerHTML === before};
      };
    JS
    page.add_script_tag(content: sources)
    page.evaluate("window.__terminalArticleFurnitureProbe(#{inject_unowned_paragraph})")
  end

  def expect_authored_context_preserved(furniture, html_material:, markdown_material:)
    html = article_with_terminal_furniture(furniture)
    with_url_page('https://journal.example/reports/funding', html) do |page|
      before = page.evaluate("document.querySelector('article').outerHTML")
      payload = extract_payload(page, reader_mode: false)
      body_material = [
        'The report explains the approved funding, the affected clinics, and the implementation timetable for the next fiscal year.',
        'Officials documented the public consultation and the evidence used to select the regional projects.'
      ]
      expect(payload['contentType']).to eq('article')
      expect(payload['html']).to include(*body_material, *html_material)
      expect(payload['markdown']).to include(*body_material, *markdown_material)
      expect(payload['textContent']).to include(*body_material)
      expect(page.evaluate("document.querySelector('article').outerHTML")).to eq(before)
    end
  end

  it 'removes only a complete linked recommendation group before later article prose' do
    furniture = <<~HTML
      <h2>LEIA MAIS</h2>
      <ul>
        <li><a href="/reports/first">First independent report</a></li>
        <li><a href="/reports/second">Second independent report</a></li>
      </ul>
      <p>The focal report continues with its published evidence after the recommendation links.</p>
    HTML

    with_url_page('https://journal.example/reports/funding', article_with_terminal_furniture(furniture)) do |page|
      result = terminal_furniture_probe(page)

      expect(result.fetch('sourceUnchanged')).to be(true)
      expect(result.fetch('html')).not_to include('LEIA MAIS', 'First independent report', 'Second independent report')
      expect(result.fetch('html')).to include('The focal report continues with its published evidence')
    end
  end

  it 'removes a generic recirculation role paired with its own terminal heading and list on an unknown host' do
    furniture = <<~HTML
      <p class="feature-recirculation-panel">A separate collection entry introduces this recommendation panel.</p>
      <h2>Recently highlighted</h2>
      <ul><li>Independent recommendation text</li></ul>
    HTML

    with_url_page('https://journal.example/reports/funding', article_with_terminal_furniture(furniture)) do |page|
      result = terminal_furniture_probe(page)

      expect(result.fetch('sourceUnchanged')).to be(true)
      expect(result.fetch('html')).not_to include('feature-recirculation-panel', 'Recently highlighted', 'Independent recommendation text')
      expect(result.fetch('html')).to include('approved funding', 'public consultation')
    end
  end

  it 'preserves a heading and unlinked list without a structural recirculation role' do
    furniture = '<h2>EM ALTA</h2><ul><li>First trending story</li></ul>'

    with_url_page('https://journal.example/reports/funding', article_with_terminal_furniture(furniture)) do |page|
      result = terminal_furniture_probe(page)

      expect(result.fetch('sourceUnchanged')).to be(true)
      expect(result.fetch('html')).to include('EM ALTA', 'First trending story')
    end
  end

  it 'preserves mixed recirculation records and article prose after their list' do
    furniture = <<~HTML
      <p class="feature-recirculation-panel">A separate collection entry introduces this recommendation panel.</p>
      <h2>Recently highlighted</h2>
      <ul><li><a href="/reports/first">A linked recommendation</a></li></ul>
      <p>The author explains why this supporting citation remains in the report.</p>
    HTML

    with_url_page('https://journal.example/reports/funding', article_with_terminal_furniture(furniture)) do |page|
      result = terminal_furniture_probe(page)

      expect(result.fetch('sourceUnchanged')).to be(true)
      expect(result.fetch('html')).to include('feature-recirculation-panel', 'Recently highlighted',
                                              'A linked recommendation', 'supporting citation')
    end
  end

  it 'removes repeated terminal related-story leaf roles without requiring destinations' do
    furniture = <<~HTML
      <div class="related-story">Independent public report about the first project</div>
      <div class="related-story">Independent public report about the second project</div>
    HTML

    with_url_page('https://journal.example/reports/funding', article_with_terminal_furniture(furniture)) do |page|
      result = terminal_furniture_probe(page)

      expect(result.fetch('sourceUnchanged')).to be(true)
      expect(result.fetch('html')).not_to include('Independent public report about the first project',
                                                  'Independent public report about the second project')
      expect(result.fetch('html')).to include('approved funding', 'public consultation')
    end
  end

  it 'preserves mixed related-story descendants and refuses an unmapped selected paragraph' do
    furniture = <<~HTML
      <div class="related-story">Independent public report about the first project</div>
      <div class="related-story"><p>A source citation <a href="/sources/record">remains linked</a>.</p></div>
    HTML

    with_url_page('https://journal.example/reports/funding', article_with_terminal_furniture(furniture)) do |page|
      result = terminal_furniture_probe(page)
      expect(result.fetch('sourceUnchanged')).to be(true)
      expect(result.fetch('html')).to include('Independent public report about the first project',
                                              'A source citation', 'href="/sources/record"')
    end

    plain_leaves = <<~HTML
      <div class="related-story">Independent public report about the first project</div>
      <div class="related-story">Independent public report about the second project</div>
    HTML
    with_url_page('https://journal.example/reports/funding', article_with_terminal_furniture(plain_leaves)) do |page|
      result = terminal_furniture_probe(page, inject_unowned_paragraph: true)
      expect(result.fetch('sourceUnchanged')).to be(true)
      expect(result.fetch('html')).to include('Independent public report about the first project',
                                              'Independent public report about the second project',
                                              'unmapped sentence was added')
    end
  end

  it 'preserves a complete linked heading group inside an authored blockquote' do
    furniture = <<~HTML
      <blockquote>
        <h2>LEIA MAIS</h2>
        <ul>
          <li><a href="https://evidence.example/reports/first">First quoted reference</a></li>
          <li><a href="https://evidence.example/reports/second">Second quoted reference</a></li>
        </ul>
        <p>Quoted source note <a href="https://evidence.example/quotation">original citation</a>.</p>
        <figure><img src="https://media.example/quoted-map.png" alt="Quoted map">
          <figcaption>Quoted map caption remains authored material.</figcaption>
        </figure>
      </blockquote>
    HTML

    expect_authored_context_preserved(
      furniture,
      html_material: [
        '<blockquote', 'LEIA MAIS', 'First quoted reference', 'Second quoted reference',
        'href="https://evidence.example/quotation"', 'https://media.example/quoted-map.png',
        'Quoted map caption remains authored material'
      ],
      markdown_material: [
        'First quoted reference', 'Second quoted reference', '[original citation](https://evidence.example/quotation)',
        '![Quoted map](https://media.example/quoted-map.png)', 'Quoted map caption remains authored material'
      ]
    )
  end

  it 'preserves a recirculation-shaped group inside an authored list item' do
    furniture = <<~HTML
      <ul><li>
        <a href="https://evidence.example/list-record">The authored list citation</a>
        <p class="feature-recirculation-panel">A separate collection entry introduces this recommendation panel.</p>
        <h2>Recently highlighted</h2>
        <ul><li>Independent recommendation text</li></ul>
      </li></ul>
    HTML

    expect_authored_context_preserved(
      furniture,
      html_material: [
        '<li>', 'The authored list citation', 'feature-recirculation-panel', 'Recently highlighted',
        'Independent recommendation text', 'href="https://evidence.example/list-record"'
      ],
      markdown_material: [
        '[The authored list citation](https://evidence.example/list-record)',
        'Recently highlighted', 'Independent recommendation text'
      ]
    )
  end

  it 'preserves repeated related-story leaves inside an authored figure caption' do
    furniture = <<~HTML
      <figure>
        <img src="https://media.example/region.png" alt="Regional map">
        <figcaption>
          Regional map caption with <a href="https://evidence.example/maps/source">the original map source</a>.
          <div class="related-story">A captioned historical note from the first map sheet.</div>
          <div class="related-story">A captioned historical note from the second map sheet.</div>
        </figcaption>
      </figure>
    HTML

    expect_authored_context_preserved(
      furniture,
      html_material: [
        '<figcaption>', 'A captioned historical note from the first map sheet',
        'A captioned historical note from the second map sheet',
        'href="https://evidence.example/maps/source"', 'https://media.example/region.png'
      ],
      markdown_material: [
        '![Regional map](https://media.example/region.png)', 'Regional map caption',
        '[the original map source](https://evidence.example/maps/source)',
        'A captioned historical note from the first map sheet',
        'A captioned historical note from the second map sheet'
      ]
    )
  end
end
