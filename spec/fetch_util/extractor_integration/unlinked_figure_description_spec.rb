# frozen_string_literal: true

require 'spec_helper'
require 'support/extractor_integration_helpers'

RSpec.describe 'Unselected physical figure descriptions' do
  include_context 'extractor integration helpers'

  def figure_collection_html
    records = 4.times.map do |index|
      image = index.zero? ? 'independent' : "record-#{index}"
      <<~HTML
        <div class="exhibit-unit">
          <div><picture><img src="/images/#{image}.jpg" alt=""></picture></div>
          <div><h2>Complete published exhibition #{index}</h2>
            <p>The complete independently authored explanation belongs to exhibition #{index}.</p></div>
          <a id="record-#{index}" href="/exhibitions/#{index}">Read about complete exhibition #{index}</a>
        </div>
      HTML
    end.join
    <<~HTML
      <html><head><title>Complete published exhibitions</title></head><body><main>
      <h1>Complete published exhibitions</h1>
      <figure id="unselected-figure">
        <picture><img src="/images/independent.jpg" alt=""></picture>
        <figcaption><h2>Independent physical opening exhibition</h2><p>12 March</p>
          <p>The complete opening explanation precedes every independently published exhibition.</p>
          <a href="/opening-details">Opening details</a>
          <pre><code>opening_url = "https://resource.example.test/complete"</code></pre>
        </figcaption>
      </figure>
      <section id="collection"><div class="exhibit-flow">#{records}</div></section>
      <figure hidden><img src="/images/hidden.jpg" alt=""><figcaption><h2>Hidden opening</h2>
        <p>The hidden explanation must remain hidden from the complete publication.</p></figcaption></figure>
      <p>The complete closing explanation follows every physical published record.</p>
      </main></body></html>
    HTML
  end

  def selected_figure_markdown(page)
    root = File.expand_path('../..', File.dirname(FetchUtil::Extractor.instance_method(:extract).source_location.first))
    paths = File.readlines(File.join(root, 'websieve/manifest.txt'), chomp: true).reject { |line| line.empty? || line.start_with?('#') }
    source = paths.map { |path| File.read(File.join(root, 'websieve', path)) }.join("\n")
    outro = File.read(File.join(root, 'websieve/99_outro.js'))
    raise 'private source boundary changed' unless source.scan(outro).size == 1

    source = source.sub(outro, <<~JS)
      window.__selectedFigureMarkdown = function() {
        var root = visibleListClone(document.querySelector('main'));
        var card = root.querySelector('#collection');
        var items = [0, 1, 2].map(function(index) {
          var link = root.querySelector('#record-' + index);
          return {sourceNode: link, card: card, url: link.href, text: link.textContent};
        });
        var descriptions = listDescriptionParts(root, items, {preserveUnrepresentedText: true, preserveTextLengths: true});
        return sectionedListMarkdownWithDescriptions({regions: [{node: card, cards: items}]}, descriptions);
      };
      })(window);
    JS
    inject_standalone_extractor(page)
    page.add_script_tag(content: source)
    page.evaluate('window.__selectedFigureMarkdown()')
  end

  def expect_complete_figure(markdown)
    image = '![](https://publication.example.test/images/independent.jpg)'
    expect(markdown.scan(image).size).to eq(2)
    expect(markdown.scan('## Independent physical opening exhibition').size).to eq(1)
    expect(markdown.scan('12 March').size).to eq(1)
    expect(markdown).to include('[Opening details](https://publication.example.test/opening-details)')
    expect(markdown).to include('opening_url = "https://resource.example.test/complete"')
    expect(markdown.index(image)).to be < markdown.index('## Independent physical opening exhibition')
    4.times do |index|
      expect(markdown.scan(/^## Complete published exhibition #{index}$/).size).to eq(1)
      expect(markdown).to include("The complete independently authored explanation belongs to exhibition #{index}.")
      expect(markdown).to include("https://publication.example.test/exhibitions/#{index}")
    end
    expect(markdown).not_to include('Hidden opening', '/images/hidden.jpg', 'The hidden explanation')
  end

  it 'retains a complete unselected figure before the selected physical media records' do
    with_url_page('https://publication.example.test/', figure_collection_html) do |page|
      before = page.evaluate('document.body.innerHTML')
      expect_complete_figure(selected_figure_markdown(page))
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end

  it 'retains every visible figure field through ordinary collection extraction' do
    with_url_page('https://publication.example.test/', figure_collection_html) do |page|
      before = page.evaluate('document.body.innerHTML')
      expect_complete_figure(extract(page).fetch('markdown'))
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end

  it 'keeps a physical figure heading and its formatted subtitle in one heading' do
    html = figure_collection_html.sub(
      '<h2>Independent physical opening exhibition</h2>',
      '<h2>Independent physical opening exhibition<br><em>Complete subtitle</em></h2>'
    )
    with_url_page('https://publication.example.test/', html) do |page|
      before = page.evaluate('document.body.innerHTML')
      markdown = extract(page).fetch('markdown')
      expect_complete_figure(markdown)
      expect(markdown).to include("## Independent physical opening exhibition _Complete subtitle_\n")
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end
end
