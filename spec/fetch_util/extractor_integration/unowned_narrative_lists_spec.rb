# frozen_string_literal: true

require 'spec_helper'
require 'support/extractor_integration_helpers'
require 'nokogiri'
require 'cgi'

RSpec.describe 'Complete unowned narrative lists' do
  include_context 'extractor integration helpers'

  def narrative_list_readings
    [
      'Keep independent drafts on the original server.',
      'Publish the complete sequence in source order.',
      'Retain every authored detail in each entry.',
      'Keep repeated observations as separate records.',
      'Move the archive without changing its contents.'
    ]
  end

  def narrative_list_document(content:, program: nil)
    features = ['Private Notes', 'Complete Archive', 'Published Reports', 'Source Records', 'Independent Copies'].map do |name|
      <<~HTML
        <article class="feature-card">
          <h3><a href="https://manual.example.test/library/#{name.downcase.tr(" ", "-")}?edition=full&amp;view=text#record">#{name}</a></h3>
          <p>#{name} keeps complete independent material and original observations on the reader's own server.</p>
        </article>
      HTML
    end.join
    literal = program ? "<pre><code class=\"language-html\">#{CGI.escapeHTML(program)}</code></pre>" : ''
    <<~HTML
      <html><head><title>Independent Notebook</title></head><body><main>
        <section class="hero"><h1>Keep an independent notebook</h1>
          <p>Keep complete notes, publish original observations and retain every source-owned detail on your own server.</p>
          <a href="/install?edition=full&amp;view=text#instructions">Installation instructions</a>
        </section>
        <section class="principles"><h2>Working principles</h2>#{content}</section>
        <section class="features"><div class="feature-grid">#{features}</div></section>
        #{literal}
      </main></body></html>
    HTML
  end

  def observe_narrative_lists(html)
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

  it 'retains every complete item of an ordinary authored ordered list' do
    list = "<ol id=\"principles\">#{narrative_list_readings.map { |text| "<li><span>#{text}</span></li>" }.join}</ol>"
    observe_narrative_lists(narrative_list_document(content: list)) do |native, payload|
      expect(native.css('ol#principles > li').map(&:text)).to eq(narrative_list_readings)
      narrative_list_readings.each { |text| expect(payload.fetch('markdown')).to include(text) }
      expect(payload.fetch('markdown').lines.grep(/^\d+\. /).map { |line| line.sub(/^\d+\. /, '').strip }).to eq(narrative_list_readings)
    end
  end

  it 'keeps a complete nested unordered list and its rich inline material' do
    list = <<~HTML
      <ul id="nested-principles">
        <li><strong>Important direction</strong> remains complete.
          <ul><li><em>Careful detail</em> stays in order.</li><li>Use <code>retain_complete_record()</code> literally.</li></ul>
        </li>
        <li>The independent final observation remains.</li>
      </ul>
    HTML
    observe_narrative_lists(narrative_list_document(content: list)) do |native, payload|
      expect(native.css('ul#nested-principles li').length).to eq(4)
      expect(payload.fetch('markdown')).to include(
        '**Important direction**', '_Careful detail_', '`retain_complete_record()`',
        'The independent final observation remains.'
      )
      expect(payload.fetch('markdown').index('Important direction')).to be < payload.fetch('markdown').index('Careful detail')
      expect(payload.fetch('markdown').index('Careful detail')).to be < payload.fetch('markdown').index('independent final observation')
    end
  end

  it 'preserves independent equal list entries without text deduplication' do
    reading = 'An independently authored repeated observation remains complete.'
    list = "<ul id=\"independent-principles\"><li>#{reading}</li><li>#{reading}</li></ul>"
    observe_narrative_lists(narrative_list_document(content: list)) do |native, payload|
      expect(native.css('ul#independent-principles > li').map(&:text)).to eq([reading, reading])
      expect(payload.fetch('markdown').scan(reading).length).to eq(2)
    end
  end

  it 'keeps genuine navigation and selection interfaces outside narrative-list material' do
    content = <<~HTML
      <nav><ul><li>Forbidden navigation selection</li><li>Forbidden navigation setting</li></ul></nav>
      <ul role="listbox"><li role="option">Forbidden selected option</li><li role="option">Forbidden second option</li></ul>
    HTML
    observe_narrative_lists(narrative_list_document(content: content)) do |_native, payload|
      expect(payload.fetch('markdown')).not_to include('Forbidden navigation', 'Forbidden selected option', 'Forbidden second option')
    end
  end

  it 'excludes positively hidden and closed-body lists from readable Markdown' do
    content = <<~HTML
      <ul style="display:none"><li>Hidden narrative instruction</li><li>Hidden narrative detail</li></ul>
      <details><summary>Ordinary disclosure summary</summary><ol><li>Closed narrative instruction</li><li>Closed narrative detail</li></ol></details>
    HTML
    observe_narrative_lists(narrative_list_document(content: content)) do |_native, payload|
      expect(payload.fetch('markdown')).not_to include('Hidden narrative', 'Closed narrative')
    end
  end

  it 'retains a whole literal list program without admitting it as a physical list' do
    program = "<ol>\n  <li>literal_collection_instruction()</li>\n</ol>"
    observe_narrative_lists(narrative_list_document(content: '', program: program)) do |native, payload|
      expect(native.css('ol, ul')).to be_empty
      expect(native.at_css('pre code').text).to eq(program)
      expect(payload.fetch('markdown')).to include("```\n#{program}\n```")
      expect(payload.fetch('markdown').scan('literal_collection_instruction()').length).to eq(1)
    end
  end

  it 'keeps a source ordered-list start and complete rich resource destinations' do
    list = <<~HTML
      <ol start="4">
        <li>Read <a href="#record"><strong>Complete notes</strong></a> first.</li>
        <li>Inspect <img src="/diagram.png?edition=full&amp;size=large#image" alt="Complete source diagram"> next.</li>
      </ol>
    HTML
    observe_narrative_lists(narrative_list_document(content: list)) do |native, payload|
      expect(native.at_css('ol')['start']).to eq('4')
      expect(payload.fetch('markdown').lines.grep(/^\d+\. /).map { |line| line[/^\d+/].to_i }).to eq([4, 5])
      expect(payload.fetch('markdown')).to include(
        '**Complete notes**', 'https://notebook.example.test/#record',
        'https://notebook.example.test/diagram.png?edition=full&size=large#image'
      )
      expect(payload.fetch('markdown').index('Working principles')).to be < payload.fetch('markdown').index(/^4\.\s+Read/)
      expect(payload.fetch('markdown').index(/^5\.\s+Inspect/)).to be < payload.fetch('markdown').index('Private Notes')
    end
  end

  it 'preserves every visible peer while excluding a positively hidden list item' do
    list = <<~HTML
      <ol>
        <li>Visible independent first observation.</li>
        <li style="display:none">Hidden independent observation.</li>
        <li>Visible independent final observation.</li>
      </ol>
    HTML
    observe_narrative_lists(narrative_list_document(content: list)) do |_native, payload|
      expect(payload.fetch('markdown').lines.grep(/^\d+\. /).map { |line| line.sub(/^\d+\. /, '').strip }).to eq(
        ['Visible independent first observation.', 'Visible independent final observation.']
      )
      expect(payload.fetch('markdown')).not_to include('Hidden independent observation.')
    end
  end

  it 'keeps original event, focus and ARIA controls outside narrative-list admission' do
    content = <<~HTML
      <ul tabindex="0"><li>Forbidden focus instruction.</li><li>Forbidden focus detail.</li></ul>
      <ul><li onclick="void(0)">Forbidden event instruction.</li><li>Forbidden event detail.</li></ul>
      <ul aria-controls="selection-panel"><li>Forbidden ARIA instruction.</li><li>Forbidden ARIA detail.</li></ul>
    HTML
    observe_narrative_lists(narrative_list_document(content: content)) do |_native, payload|
      expect(payload.fetch('markdown')).not_to include('Forbidden focus', 'Forbidden event', 'Forbidden ARIA')
    end
  end

  it 'does not independently duplicate a list inside an already selected record' do
    reading = 'A complete observation owned by the selected feature record.'
    document = narrative_list_document(content: '')
    document = document.sub(
      "<article class=\"feature-card\">",
      "<article class=\"feature-card\"><ul><li>#{reading}</li><li>Its separate feature-owned detail.</li></ul>"
    )
    observe_narrative_lists(document) do |native, payload|
      expect(native.css('article.feature-card ul li').map(&:text)).to eq([reading, 'Its separate feature-owned detail.'])
      expect(payload.fetch('markdown').scan(reading).length).to be <= 1
    end
  end

  it 'renders a complete program owned by a list exactly once' do
    program = 'literal_list_program()'
    list = "<ol><li>Keep the complete program.<pre><code>#{program}</code></pre></li><li>Keep the final observation.</li></ol>"
    observe_narrative_lists(narrative_list_document(content: list)) do |native, payload|
      expect(native.at_css('ol pre code').text).to eq(program)
      expect(payload.fetch('markdown')).to match(/```[^\n]*\n\s*literal_list_program\(\)\n\s*```/)
      expect(payload.fetch('markdown').scan(program).length).to eq(1)
      expect(payload.fetch('markdown')).to include('Keep the final observation.')
    end
  end
end
