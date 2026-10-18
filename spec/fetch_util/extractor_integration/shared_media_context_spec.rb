# frozen_string_literal: true

require 'spec_helper'
require 'support/extractor_integration_helpers'

RSpec.describe 'Physical shared media contexts' do
  include_context 'extractor integration helpers'

  def media_collection_html(shared_image: false)
    entries = 4.times.map do |index|
      image = shared_image && index < 2 ? 'shared' : "record-#{index}"
      <<~HTML
        <div class="exhibit-unit">
          <div><picture><img src="/images/#{image}.jpg" alt=""></picture></div>
          <div><p>Published date #{index + 1} March 2027</p>
            <h2>Complete independent exhibition #{index}</h2>
            <p>The complete authored explanation belongs to physical exhibition #{index}.</p></div>
          <a id="record-#{index}" href="/exhibitions/#{index}"><span>Read about complete exhibition #{index}</span></a>
        </div>
      HTML
    end.join
    <<~HTML
      <html><head><title>Independent exhibitions and complete resources</title></head><body><main>
      <h1>Independent exhibitions and complete resources</h1>
      <p>The complete introduction precedes every independently published exhibition and its original resource.</p>
      <section id="collection" class="cards"><div class="exhibit-flow">#{entries}</div>
        <div hidden><img src="/images/hidden.jpg" alt="Hidden preview">Hidden exhibition</div>
      </section>
      <p>The complete closing explanation follows every exhibition and its recorded resources.</p>
      </main></body></html>
    HTML
  end

  def selected_media_markdown(page, sectioned: false)
    root = File.expand_path('../..', File.dirname(FetchUtil::Extractor.instance_method(:extract).source_location.first))
    paths = File.readlines(File.join(root, 'websieve/manifest.txt'), chomp: true).reject do |line|
      line.empty? || line.start_with?('#')
    end
    source = paths.map { |path| File.read(File.join(root, 'websieve', path)) }.join("\n")
    outro = File.read(File.join(root, 'websieve/99_outro.js'))
    raise 'source-module test boundary changed' unless source.scan(outro).size == 1

    source = source.sub(outro, <<~JS)
      window.__selectedMediaMarkdown = function() {
        var root = visibleListClone(document.body);
        var card = root.querySelector('#collection');
        var items = [0, 1, 2].map(function(index) {
          var link = root.querySelector('#record-' + index);
          return {sourceNode: link, card: card, url: link.href, text: link.textContent};
        });
        if (!#{sectioned}) return listMarkdown(items);
        var regions = items.map(function(item) {
          var heading = item.sourceNode.parentElement.querySelector('h2');
          return {node: item.sourceNode.parentElement, cards: [item], headingNode: heading, label: heading.textContent};
        });
        var introduction = root.querySelector('main > p');
        var unselectedHeading = root.querySelector('#record-3').parentElement.querySelector('h2');
        return sectionedListMarkdownWithDescriptions({regions: regions}, [
          {node: introduction, markdown: markdownFor(introduction.outerHTML)},
          {node: unselectedHeading, markdown: markdownFor(unselectedHeading.outerHTML)}
        ]);
      };
      })(window);
    JS
    inject_standalone_extractor(page)
    page.add_script_tag(content: source)
    page.evaluate('window.__selectedMediaMarkdown()')
  end

  it 'renders each physical media record once and retains an unselected peer in source order' do
    with_url_page('https://publication.example.test/', media_collection_html) do |page|
      before = page.evaluate('document.body.innerHTML')
      markdown = selected_media_markdown(page)
      expect(markdown.scan(%r{!\[\]\(https://publication\.example\.test/images/record-\d\.jpg\)})).to eq(
        4.times.map { |index| "![](https://publication.example.test/images/record-#{index}.jpg)" }
      )
      4.times do |index|
        expect(markdown.scan("The complete authored explanation belongs to physical exhibition #{index}.").size).to eq(1)
        expect(markdown).to include("](https://publication.example.test/exhibitions/#{index})")
      end
      expect(markdown).not_to include('Hidden exhibition', '/images/hidden.jpg')
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end

  it 'preserves independent physical occurrences of the same image URL' do
    with_url_page('https://publication.example.test/', media_collection_html(shared_image: true)) do |page|
      before = page.evaluate('document.body.innerHTML')
      markdown = selected_media_markdown(page)
      expect(markdown.scan('![](https://publication.example.test/images/shared.jpg)').size).to eq(2)
      expect(markdown.scan('![](https://publication.example.test/images/record-2.jpg)').size).to eq(1)
      expect(markdown.scan('![](https://publication.example.test/images/record-3.jpg)').size).to eq(1)
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end

  it 'keeps each physical heading with its image and prose when several regions share the context' do
    with_url_page('https://publication.example.test/', media_collection_html) do |page|
      before = page.evaluate('document.body.innerHTML')
      markdown = selected_media_markdown(page, sectioned: true)
      tokens = 4.times.flat_map do |index|
        ["![](https://publication.example.test/images/record-#{index}.jpg)",
         "Published date #{index + 1} March 2027",
         "## Complete independent exhibition #{index}",
         "The complete authored explanation belongs to physical exhibition #{index}.",
         "](https://publication.example.test/exhibitions/#{index})"]
      end
      positions = tokens.map { |token| markdown.index(token) }
      expect(positions).not_to include(nil)
      expect(positions).to eq(positions.sort)
      4.times do |index|
        expect(markdown.scan("## Complete independent exhibition #{index}").size).to eq(1)
        expect(markdown.scan("The complete authored explanation belongs to physical exhibition #{index}.").size).to eq(1)
      end
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end

  it 'keeps every line and inline format of a physical media heading in the same heading role' do
    html = media_collection_html.sub(
      '<h2>Complete independent exhibition 0</h2>',
      '<h2>Complete independent exhibition 0<br><em>Complete subtitle</em></h2>'
    )
    with_url_page('https://publication.example.test/', html) do |page|
      before = page.evaluate('document.body.innerHTML')
      markdown = selected_media_markdown(page, sectioned: true)
      expect(markdown).to include("## Complete independent exhibition 0 _Complete subtitle_\n")
      expect(markdown.scan('_Complete subtitle_').size).to eq(1)
      4.times do |index|
        expect(markdown).to include("The complete authored explanation belongs to physical exhibition #{index}.")
        expect(markdown).to include("https://publication.example.test/exhibitions/#{index}")
      end
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end

  it 'retains complete collection material through ordinary extraction' do
    with_url_page('https://publication.example.test/', media_collection_html) do |page|
      before = page.evaluate('document.body.innerHTML')
      payload = extract(page)
      markdown = payload.fetch('markdown')
      4.times do |index|
        expect(markdown.scan("![](https://publication.example.test/images/record-#{index}.jpg)").size).to eq(1)
        expect(markdown).to include("The complete authored explanation belongs to physical exhibition #{index}.")
        expect(markdown).to include("https://publication.example.test/exhibitions/#{index}")
      end
      expect(markdown).to include('The complete introduction', 'The complete closing explanation')
      expect(markdown).not_to include('Hidden exhibition', '/images/hidden.jpg')
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end
end
