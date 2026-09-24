# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Source-owned article figure captions' do
  include_context 'extractor integration helpers'

  def caption_probe(page)
    root = File.expand_path('../../..', __dir__)
    source = File.readlines(File.join(root, 'websieve/manifest.txt'), chomp: true).reject(&:empty?).map do |entry|
      File.read(File.join(root, 'websieve', entry))
    end.join("\n")
    source.sub!('})(window);', 'window.__figureCaptionProof = sourceOwnedFigureCaptionContent; })(window);')
    page.add_script_tag(content: source)
  end

  it 'retains every visible caption with its selected image, without borrowing from an aside' do
    figures = (1..12).map do |index|
      "<figure><img src='/image-#{index}.jpg' alt='Image #{index}'>" \
        "<figcaption>Source caption #{index}. Photographer #{index}.</figcaption></figure>"
    end.join
    prose = 3.times.map do |index|
      "<p>Report paragraph #{index} records verified public evidence and substantial context " \
        'about the feature without changing the source article or omitting its cited resources. ' \
        'Its documented images and attribution remain available to every reader for independent verification.</p>'
    end.join
    html = "<main><article><h1>Documented field report</h1>#{prose}#{figures}</article></main>" \
           "<aside><figure><img src='/image-13.jpg'><figcaption>Unrelated sidebar caption</figcaption></figure></aside>"

    with_url_page('https://reports.example/field-report', html) do |page|
      before = page.evaluate('document.body.innerHTML')
      caption_probe(page)
      selected = page.evaluate(<<~JS)
        (() => {
          const article = document.querySelector('article');
          const figures = Array.from(article.querySelectorAll('figure')).map((figure) => {
            const image = figure.querySelector('img');
            return '<figure><img src="' + image.src + '" alt="' + image.alt + '"></figure>';
          }).join('');
          const paragraphs = Array.from(article.querySelectorAll('p')).map((node) => node.outerHTML).join('');
          return window.__figureCaptionProof({contentType: 'article', readerMode: true,
            html: paragraphs + figures, textContent: article.querySelector('h1').textContent + ' ' + paragraphs}).html;
        })()
      JS
      positions = (1..12).map do |index|
        text = "Source caption #{index}. Photographer #{index}."
        expect(selected.scan(text).length).to eq(1)
        selected.index(text)
      end
      expect(positions).to eq(positions.sort)
      expect(selected).not_to include('Unrelated sidebar caption')
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end

  it 'declines captions with ambiguous or hidden source owners' do
    html = <<~HTML
      <main><article><h1>Documented field report</h1>
        <p>The first verified report paragraph describes the evidence with enough public context to establish one article.</p>
        <p>The second verified report paragraph distinguishes the focal story from unrelated widgets or other pages.</p>
        <p>The third verified report paragraph confirms that this article owns the selected image, not an outside rail.</p>
        <p>The fourth verified paragraph adds enough substantive public context for the complete article to be identified confidently, while keeping both duplicate photographs intentionally ambiguous and preserving the hidden caption as an explicit negative control.</p>
        <figure><img src="/duplicate.jpg"><figcaption>First photographer credit.</figcaption></figure>
        <figure><img src="/duplicate.jpg"><figcaption>Second photographer credit.</figcaption></figure>
        <figure><img src="/hidden.jpg"><figcaption hidden>Private deferred caption.</figcaption></figure>
      </article></main>
    HTML

    with_url_page('https://reports.example/ambiguous-images', html) do |page|
      caption_probe(page)
      result = page.evaluate(<<~JS)
        (() => {
          const article = document.querySelector('article');
          const paragraphs = Array.from(article.querySelectorAll('p')).map((node) => node.outerHTML).join('');
          const selected = paragraphs + '<figure><img src="/duplicate.jpg"></figure><figure><img src="/hidden.jpg"></figure>';
          return window.__figureCaptionProof({contentType: 'article', readerMode: true,
            html: selected, textContent: paragraphs}).html;
        })()
      JS
      expect(result).not_to include('First photographer credit', 'Second photographer credit', 'Private deferred caption')
    end
  end
end
