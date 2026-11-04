# frozen_string_literal: true

require 'spec_helper'
require 'support/extractor_integration_helpers'
require 'nokogiri'

RSpec.describe 'Complete inline material in ordinary list descriptions' do
  include_context 'extractor integration helpers'

  def inline_description_document(content)
    features = ['Private Notes', 'Complete Archive', 'Published Reports', 'Source Records', 'Independent Copies'].map do |name|
      <<~HTML
        <article class="feature-card"><h3><a href="https://manual.example.test/library/#{name.downcase.tr(" ", "-")}?edition=full&amp;view=text#record">#{name}</a></h3>
          <p>#{name} keeps complete independent material and original observations on the reader's own server.</p>
        </article>
      HTML
    end.join
    <<~HTML
      <html><head><title>Independent Notebook</title></head><body><main>
        <section><h1>Keep an independent notebook</h1>
          <p>Keep complete notes, publish original observations and retain every source-owned detail on your own server.</p>
          <a href="/install?edition=full&amp;view=text#instructions">Installation instructions</a>
        </section>
        #{content}
        <section class="features"><div class="feature-grid">#{features}</div></section>
      </main></body></html>
    HTML
  end

  def inline_description_section(paragraph, heading: 'Reading principles')
    "<section class=\"explanation\"><h2>#{heading}</h2>#{paragraph}</section>"
  end

  def observe_inline_descriptions(html)
    with_url_page('https://notebook.example.test/', html) do |page|
      before = page.evaluate('document.body.outerHTML')
      payload = extract(page)
      expect(page.evaluate('document.body.outerHTML')).to eq(before)
      native = Nokogiri::HTML5.fragment(payload.fetch('html'))
      expect(payload.fetch('contentType')).to eq('list')
      expect(native.css('h3').map(&:text)).to eq(
        ['Private Notes', 'Complete Archive', 'Published Reports', 'Source Records', 'Independent Copies']
      )
      expect(payload.fetch('markdown')).to include(
        'Private Notes', 'Complete Archive', 'Published Reports', 'Source Records', 'Independent Copies'
      )
      yield native, payload
    end
  end

  it 'retains complete emphasis, strong text and an inline program in admitted ordinary prose' do
    paragraph = <<~HTML
      <p>Preserve <em>careful observation</em>, <strong>complete records</strong> and <code>publish --all --format=text</code> in every independent source and every complete original archive.</p>
    HTML
    observe_inline_descriptions(inline_description_document(inline_description_section(paragraph))) do |native, payload|
      source = native.at_css('section.explanation > p')
      expect(source.at_css('em').text).to eq('careful observation')
      expect(source.at_css('strong').text).to eq('complete records')
      expect(source.at_css('code').text).to eq('publish --all --format=text')
      expect(payload.fetch('markdown')).to include(
        '_careful observation_', '**complete records**', '`publish --all --format=text`'
      )
    end
  end

  it 'retains the complete rich linked label and its full destination in ordinary prose' do
    paragraph = <<~HTML
      <p>Read the <a href="/method?edition=full&amp;view=text#proof"><strong>complete guide</strong> and <em>original methods</em></a> before publishing every independent observation and its complete source material.</p>
    HTML
    observe_inline_descriptions(inline_description_document(inline_description_section(paragraph))) do |native, payload|
      link = native.at_css('section.explanation > p > a')
      expect(link['href']).to eq('https://notebook.example.test/method?edition=full&view=text#proof')
      expect(link.at_css('strong').text).to eq('complete guide')
      expect(link.at_css('em').text).to eq('original methods')
      expect(payload.fetch('markdown')).to include(
        '[**complete guide** and _original methods_](https://notebook.example.test/method?edition=full&view=text#proof)'
      )
    end
  end

  it 'preserves two independent equal rich paragraphs in their physical section order' do
    paragraph = '<p>Keep <em>careful reading</em> and every independent observation together with its complete original material and authored context.</p>'
    content = inline_description_section(paragraph, heading: 'Original observations') +
              inline_description_section(paragraph, heading: 'Independent observations')
    observe_inline_descriptions(inline_description_document(content)) do |native, payload|
      expect(native.css('section.explanation > p > em').map(&:text)).to eq(['careful reading', 'careful reading'])
      markdown = payload.fetch('markdown')
      expect(markdown.scan('_careful reading_').size).to eq(2)
      first = markdown.index('_careful reading_')
      last = markdown.rindex('_careful reading_')
      expect(markdown.index('Original observations')).to be < first
      expect(first).to be < markdown.index('Independent observations')
      expect(markdown.index('Independent observations')).to be < last
    end
  end

  it 'keeps complete plain admitted prose exactly once' do
    reading = 'Keep every independent observation with its complete original source material, physical context and authored order in the published archive.'
    observe_inline_descriptions(inline_description_document(inline_description_section("<p>#{reading}</p>"))) do |native, payload|
      expect(native.at_css('section.explanation > p').text).to eq(reading)
      expect(payload.fetch('markdown').scan(reading).size).to eq(1)
    end
  end

  it 'keeps hidden and closed prose excluded while preserving a complete literal program' do
    content = <<~HTML
            <section class="explanation"><h2>Literal instructions</h2>
              <p>Keep the complete published instructions with their original source and preserve the program exactly as authored.</p>
              <p style="display:none">Do not publish <em>hidden-only emphasis</em> or this complete hidden-only source paragraph.</p>
              <details><summary>Supplementary notes</summary><p>Do not publish <strong>closed-only emphasis</strong> or this complete closed-only source paragraph.</p></details>
              <pre><code>&lt;em&gt;literal material&lt;/em&gt;
      publish --all --format=text</code></pre>
            </section>
    HTML
    observe_inline_descriptions(inline_description_document(content)) do |native, payload|
      expect(native.at_css('pre > code').text).to eq("<em>literal material</em>\npublish --all --format=text")
      expect(payload.fetch('markdown')).to include("<em>literal material</em>\npublish --all --format=text")
      expect(payload.fetch('markdown')).not_to include('hidden-only emphasis', 'closed-only emphasis', '_literal material_')
    end
  end

  it 'does not separately duplicate rich prose already represented by a selected record' do
    html = inline_description_document('').sub(
      "Private Notes keeps complete independent material and original observations on the reader's own server.",
      "Private Notes keeps <em>independently owned emphasis</em> and complete original observations on the reader's own server."
    )
    observe_inline_descriptions(html) do |native, payload|
      expect(native.css('article.feature-card em').map(&:text)).to eq(['independently owned emphasis'])
      expect(payload.fetch('markdown').scan('_independently owned emphasis_').size).to eq(1)
    end
  end
end
