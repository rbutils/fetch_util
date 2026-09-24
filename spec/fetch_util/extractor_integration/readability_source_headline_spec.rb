# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Source-owned Reader headlines' do
  include_context 'extractor integration helpers'

  def reader_source_headline_probe(page)
    root = File.expand_path('../../..', __dir__)
    source = File.readlines(File.join(root, 'websieve/manifest.txt'), chomp: true)
                 .reject { |path| path.empty? || path.start_with?('#') }
                 .map { |path| File.read(File.join(root, 'websieve', path)) }.join("\n")
    page.add_script_tag(content: source.sub('})(window);', 'window.__readerHeadlineProof = sourceOwnedReaderMissingHeadlineContent; })(window);'))
  end

  it 'restores a single visible source H1 above the same owned Reader paragraphs' do
    paragraphs = (1..12).map do |index|
      "<p>Published paragraph #{index} reports the original verified observations and the exact chronology of the experiment.</p>"
    end.join
    html = <<~HTML
      <html><body><main><div class="publication">
        <h1>A uniquely owned technical report</h1>
        <figure><img src="/original.jpg" alt="Photograph of the report"><figcaption>Photograph of the report</figcaption></figure>
        <div class="article-body">#{paragraphs}</div>
      </div></main></body></html>
    HTML

    with_url_page('https://reports.example/technical-report', html) do |page|
      original_body = page.evaluate('document.body.innerHTML')
      reader_source_headline_probe(page)
      selected = "<div class='reader-body'><img src='/original.jpg' alt='Photograph of the report'>#{paragraphs}</div>"
      candidate = { title: 'A uniquely owned technical report', html: selected,
                    readerMode: true, contentType: 'article' }
      result = page.evaluate("window.__readerHeadlineProof(#{JSON.generate(candidate)})")

      expect(result.fetch('html')).to start_with('<h1>A uniquely owned technical report</h1>')
      (1..12).each do |index|
        expect(result.fetch('html').scan("Published paragraph #{index} reports").length).to eq(1)
      end
      expect(result.fetch('html')).to include('alt="Photograph of the report"')
      expect(page.evaluate('document.body.innerHTML')).to eq(original_body)
    end
  end

  it 'rejects conflicting headings, unrelated Reader paragraphs, and an existing heading' do
    intro = '<p>The source lead reports a substantial verified observation about the original experiment.</p>'
    body = '<p>The following report explains an independent measurement with its complete source context.</p>'
    html = "<main><div class='publication'><h1>Owned report</h1>#{intro}#{body}" \
           '<p>Third source paragraph contains additional observed context and methodology.</p></div></main>'

    with_url_page('https://reports.example/report', html) do |page|
      reader_source_headline_probe(page)
      candidate = { title: 'Owned report', html: "<div>#{intro}#{body}</div>",
                    readerMode: true, contentType: 'article' }
      expect(page.evaluate("window.__readerHeadlineProof(#{JSON.generate(candidate)})").fetch('html')).to start_with('<h1>Owned report</h1>')

      page.evaluate("document.querySelector('.publication').insertAdjacentHTML('afterend', '<h1>Independent report</h1>')")
      expect(page.evaluate("window.__readerHeadlineProof(#{JSON.generate(candidate)})").fetch('html')).to eq(candidate.fetch(:html))
      page.evaluate('document.querySelector("main > h1:last-child").remove()')
      unrelated = candidate.merge(html: "<div><p>An unrelated article provides its own long opening explanation of a different experiment.</p>#{body}</div>")
      expect(page.evaluate("window.__readerHeadlineProof(#{JSON.generate(unrelated)})").fetch('html')).to eq(unrelated.fetch(:html))
      already_titled = candidate.merge(html: "<div><h2>Owned report</h2>#{intro}#{body}</div>")
      expect(page.evaluate("window.__readerHeadlineProof(#{JSON.generate(already_titled)})").fetch('html')).to eq(already_titled.fetch(:html))
    end
  end

  it 'restores a source-owned HTML headline when Reader already rendered the matching Markdown title' do
    paragraphs = (1..12).map do |index|
      "<p>Original observation #{index} retains its complete source description and verified sequence of events.</p>"
    end.join
    html = "<main><article><h1>Verified source report</h1>#{paragraphs}</article></main>"

    with_url_page('https://reports.example/source-report', html) do |page|
      original_body = page.evaluate('document.body.innerHTML')
      reader_source_headline_probe(page)
      candidate = { title: 'Verified source report', html: "<div>#{paragraphs}</div>",
                    markdown: "# Verified source report\n\nAll twelve observations remain in the original order.",
                    readerMode: true, contentType: 'article' }
      result = page.evaluate("window.__readerHeadlineProof(#{JSON.generate(candidate)})")

      expect(result.fetch('html')).to start_with('<h1>Verified source report</h1>')
      expect(result.fetch('markdown')).to eq(candidate.fetch(:markdown))
      (1..12).each do |index|
        expect(result.fetch('html').scan("Original observation #{index} retains").length).to eq(1)
      end
      unrelated_markdown = candidate.merge(markdown: "# Another report\n\nThe unrelated article is not the source headline.")
      expect(page.evaluate("window.__readerHeadlineProof(#{JSON.generate(unrelated_markdown)})").fetch('html')).to eq(candidate.fetch(:html))
      expect(page.evaluate('document.body.innerHTML')).to eq(original_body)
    end
  end
end
