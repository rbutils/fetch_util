# frozen_string_literal: true

require 'spec_helper'
require 'support/extractor_integration_helpers'

RSpec.describe 'Physical images owned by selected heading references' do
  include_context 'extractor integration helpers'

  def linked_heading_images_html
    <<~HTML
      <html><head><title>Independent exhibition programme</title></head><body><main>
      <h1>Independent exhibition programme</h1>
      <p id="introduction">The complete introduction describes these independently published exhibitions.</p>
      <section><h2>Current exhibitions</h2>
      <article id="entry" class="publication-card">
        <a id="reference" href="/exhibitions/first">
          <picture><img src="/images/physical.jpg" alt="Complete first artwork alternative"></picture>
          <h3>Complete first exhibition heading</h3>
        </a>
        <p>The complete first authored description remains attached to this exhibition.</p>
        <time datetime="2026-10-12">12 October 2026</time>
        <div hidden><img src="/images/hidden.jpg" alt="Hidden artwork alternative"></div>
        <details><summary>Additional information</summary>
          <img src="/images/closed.jpg" alt="Closed artwork alternative"><pre>closed_program();</pre>
        </details>
      </article>
      <article id="second" class="publication-card">
        <a id="second-reference" href="/exhibitions/second">
          <img src="/images/physical.jpg" alt="Independent second artwork alternative">
          <h3>Complete second exhibition heading</h3>
        </a>
        <p>The complete second authored description remains independently owned.</p>
      </article>
      <article id="third" class="publication-card">
        <img src="/images/third.jpg" alt="">
        <h3><a id="third-reference" href="/exhibitions/third">Complete third exhibition heading</a></h3>
        <p>The complete third authored description follows its physical image.</p>
      </article>
      </section>
      <pre id="program">const literal = "[image](/images/physical.jpg) &amp; a &gt; b";
      second_line();  </pre>
      </main></body></html>
    HTML
  end

  def linked_heading_images_markdown(page, sectioned: false, narrow_card: false, body_images: false)
    root = File.expand_path('../..', File.dirname(FetchUtil::Extractor.instance_method(:extract).source_location.first))
    paths = File.readlines(File.join(root, 'websieve/manifest.txt'), chomp: true).reject do |line|
      line.empty? || line.start_with?('#')
    end
    source = paths.map { |path| File.read(File.join(root, 'websieve', path)) }.join("\n")
    outro = File.read(File.join(root, 'websieve/99_outro.js'))
    raise 'source-module test boundary changed' unless source.scan(outro).size == 1

    source = source.sub(outro, <<~JS)
      window.__linkedHeadingImagesMarkdown = function() {
        var root = visibleListClone(document.body);
        var items = [['entry', 'reference'], ['second', 'second-reference'], ['third', 'third-reference']].map(function(ids) {
          var card = root.querySelector('#' + ids[0]);
          var link = root.querySelector('#' + ids[1]);
          var heading = link.closest('h3') || link.querySelector('h3');
          var fieldCard = #{narrow_card} ? link.closest('h3') || link : card;
          var item = {sourceNode: link, card: fieldCard, url: link.href, text: heading.textContent};
          if (#{narrow_card}) item.contentCard = card;
          addCardContext(item, fieldCard);
          return item;
        });
        var introduction = root.querySelector('#introduction');
        var program = root.querySelector('#program');
        if (#{body_images}) {
          var descriptions = listDescriptionParts(root, items, {
            includeInlineProse: true, preserveTextLengths: true,
            preserveUnrepresentedText: true, suppressRepresentedText: true
          });
          descriptions.push({node: program, markdown: markdownFor(program.outerHTML)});
          return sectionedListMarkdownWithDescriptions({regions: [
            {node: root, label: '', cards: items}
          ]}, descriptions);
        }
        if (!#{sectioned}) return [markdownFor(introduction.outerHTML), listMarkdown(items), markdownFor(program.outerHTML)].join(String.fromCharCode(10, 10));
        var region = root.querySelector('section');
        var heading = region.querySelector('h2');
        return sectionedListMarkdownWithDescriptions({regions: [
          {node: region, cards: items, headingNode: heading, label: heading.textContent}
        ]}, [
          {node: introduction, markdown: markdownFor(introduction.outerHTML)},
          {node: program, markdown: markdownFor(program.outerHTML)}
        ]);
      };
      })(window);
    JS
    inject_standalone_extractor(page)
    page.add_script_tag(content: source)
    page.evaluate('window.__linkedHeadingImagesMarkdown()')
  end

  [false, true].each do |sectioned|
    it "retains each physical heading-owned image in #{sectioned ? "sectioned" : "ordinary"} selected-record output" do
      with_url_page('https://exhibitions.publication.example.test/', linked_heading_images_html) do |page|
        before = page.evaluate('document.body.innerHTML')
        markdown = linked_heading_images_markdown(page, sectioned: sectioned)
        images = [
          '![Complete first artwork alternative](https://exhibitions.publication.example.test/images/physical.jpg)',
          '![Independent second artwork alternative](https://exhibitions.publication.example.test/images/physical.jpg)',
          '![](https://exhibitions.publication.example.test/images/third.jpg)'
        ]
        images.each { |image| expect(markdown.scan(image).size).to eq(1) }
        expect(images.map { |image| markdown.index(image) }).to eq(images.map { |image| markdown.index(image) }.sort)
        %w[first second third].each do |name|
          expect(markdown.scan("[Complete #{name} exhibition heading](https://exhibitions.publication.example.test/exhibitions/#{name})").size).to eq(1)
          expect(markdown).to include("The complete #{name} authored description")
        end
        expect(markdown).to include('The complete introduction', '2026-10-12', 'Additional information')
        expect(markdown).to include("const literal = \"[image](/images/physical.jpg) & a > b\";\nsecond_line();  ")
        expect(markdown).not_to include('Hidden artwork alternative', '/images/hidden.jpg', 'Closed artwork alternative', '/images/closed.jpg', 'closed_program')
        expect(markdown).not_to include('### Complete first exhibition heading')
        expect(page.evaluate('document.body.innerHTML')).to eq(before)
      end
    end
  end

  it 'retains physical sibling images when the selected reference has a narrower field card' do
    with_url_page('https://exhibitions.publication.example.test/', linked_heading_images_html) do |page|
      before = page.evaluate('document.body.innerHTML')
      markdown = linked_heading_images_markdown(page, narrow_card: true)
      expect(markdown.scan('![Complete first artwork alternative](https://exhibitions.publication.example.test/images/physical.jpg)').size).to eq(1)
      expect(markdown.scan('![Independent second artwork alternative](https://exhibitions.publication.example.test/images/physical.jpg)').size).to eq(1)
      expect(markdown.scan('![](https://exhibitions.publication.example.test/images/third.jpg)').size).to eq(1)
      expect(markdown).not_to include('/images/hidden.jpg', '/images/closed.jpg', 'closed_program')
      expect(markdown).to include("const literal = \"[image](/images/physical.jpg) & a > b\";\nsecond_line();  ")
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end

  it 'retains independent body images and gallery destinations outside selected records in source order' do
    images = <<~HTML
      <div><img src="/images/lead.jpg" alt="First complete lead alternative">
      <img src="/images/lead.jpg" alt="Independent complete lead alternative"></div>
      <figure><a href="/images/gallery.jpg" role="button" aria-haspopup="true"><img src="/images/gallery.jpg" alt="Complete gallery alternative"></a></figure>
      <nav><img src="/images/navigation.jpg" alt="Navigation control"></nav>
      <button><img src="/images/control.jpg" alt="Button control"></button>
      <a role="button" href="/controls/open"><img src="/images/control-link.jpg" alt="Indirect action control"></a>
      <details><summary>Additional lead information</summary><img src="/images/closed-lead.jpg" alt="Closed lead"></details>
    HTML
    html = linked_heading_images_html.sub('<p id="introduction">', "#{images}<p id=\"introduction\">")
    with_url_page('https://exhibitions.publication.example.test/', html) do |page|
      before = page.evaluate('document.body.innerHTML')
      markdown = linked_heading_images_markdown(page, body_images: true)
      expected = [
        '![First complete lead alternative](https://exhibitions.publication.example.test/images/lead.jpg)',
        '![Independent complete lead alternative](https://exhibitions.publication.example.test/images/lead.jpg)',
        '[![Complete gallery alternative](https://exhibitions.publication.example.test/images/gallery.jpg)](https://exhibitions.publication.example.test/images/gallery.jpg)',
        '![Complete first artwork alternative](https://exhibitions.publication.example.test/images/physical.jpg)',
        '![Independent second artwork alternative](https://exhibitions.publication.example.test/images/physical.jpg)',
        '![](https://exhibitions.publication.example.test/images/third.jpg)'
      ]
      expected.each { |value| expect(markdown.scan(value).size).to eq(1) }
      expect(expected.map { |value| markdown.index(value) }).to eq(expected.map { |value| markdown.index(value) }.sort)
      expect(markdown).not_to include(
        '/images/navigation.jpg', '/images/control.jpg', '/images/control-link.jpg', '/images/closed-lead.jpg',
        '/images/hidden.jpg', '/images/closed.jpg', 'closed_program'
      )
      expect(markdown).to include("const literal = \"[image](/images/physical.jpg) & a > b\";\nsecond_line();  ")
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end
end
