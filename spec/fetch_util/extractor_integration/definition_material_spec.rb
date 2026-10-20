require 'spec_helper'
require 'support/extractor_integration_helpers'
require 'cgi'
require 'nokogiri'

RSpec.describe 'Source-owned definition material' do
  include_context 'extractor integration helpers'

  def definition_material_page(first_class: '', extra: '', program: nil)
    remaining = (1..5).map do |number|
      <<~HTML
        <dl id="edition_#{number}"><dt>How does edition #{number} preserve the reference?</dt><dd style="display:block">
        <p>Edition #{number} preserves the complete independently published reference, including its original observations,
        source records, maintenance history and all of the practical instructions needed to interpret those records.</p>
        </dd></dl>
      HTML
    end.join
    literal = program ? "<pre><code>#{CGI.escapeHTML(program)}</code></pre>" : ''
    <<~HTML
      <html><head><title>Published reference definitions</title>
      <meta name="description" content="Complete definitions and practical reference values for independently maintained editions."></head>
      <body><main><div class="wrapper"><h1>Published reference definitions</h1>
      <p>This reference publishes the complete definitions, source resources and practical comparison values for every edition.</p>
      <div class="raw-html-embed">
      <dl id="community_questions" class="#{CGI.escapeHTML(first_class)}"><dt>Which source defines the first edition?</dt>
      <dd style="display:block"><p>The first edition uses the <a href="/source/">published source</a> and retains every comparison value.</p>
      <table><tbody><tr><th>Edition</th><th>Storage</th></tr><tr><td>First edition</td><td>42 records</td></tr>
      <tr><td>Second edition</td><td>81 records</td></tr></tbody></table></dd>
      <dt>Where is the independent reference?</dt><dd style="display:block"><p>The independently published instructions preserve
      this second physical <a href="/source/">published source</a> and the literal <code>edition_source</code> identifier.</p></dd></dl>
      #{remaining}#{literal}#{extra}</div></div></main></body></html>
    HTML
  end

  def expect_complete_definitions(payload)
    native = Nokogiri::HTML5(payload.fetch('html'))
    native.css('nav, details:not([open])').remove
    expected_terms = [
      'Which source defines the first edition?', 'Where is the independent reference?',
      *(1..5).map { |number| "How does edition #{number} preserve the reference?" }
    ]
    expected_rows = [
      %w[Edition Storage], ['First edition', '42 records'], ['Second edition', '81 records']
    ]
    expected_references = [
      ['published source', 'https://reference.publication.example.test/source/'],
      ['published source', 'https://reference.publication.example.test/source/']
    ]
    expect(native.css('dt').map(&:text)).to eq(expected_terms)
    expect(native.css('table tr').map { |row| row.element_children.map(&:text) }).to eq(expected_rows)
    expect(native.css('a[href]').map { |node| [node.text, node['href']] }).to eq(expected_references)
    expect(payload.fetch('markdown')).to include('Which source defines the first edition?',
                                                 'Where is the independent reference?', '42 records', '81 records', 'edition_source')
    expect(payload.fetch('markdown').scan('[published source](https://reference.publication.example.test/source/)').length).to eq(2)
    (1..5).each { |number| expect(payload.fetch('markdown')).to include("Edition #{number} preserves the complete independently published reference") }
    expect(payload.fetch('html')).not_to include('fetchutil-definition-content-')
  end

  it 'preserves complete visible definitions despite an unrelated community identifier' do
    with_url_page('https://reference.publication.example.test/manual/', definition_material_page) do |page|
      before = page.evaluate('document.body.innerHTML')
      expect_complete_definitions(extract(page))
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end

  it 'preserves the same definitions when their owner also has an explicit content class' do
    with_url_page('https://reference.publication.example.test/manual/', definition_material_page(first_class: 'content')) do |page|
      before = page.evaluate('document.body.innerHTML')
      expect_complete_definitions(extract(page))
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end

  it 'keeps every physical headerless definition-table cell as data' do
    html = definition_material_page.sub('<th>Edition</th><th>Storage</th>', '<td>Edition</td><td>Storage</td>')
    with_url_page('https://reference.publication.example.test/manual/', html) do |page|
      before = page.evaluate('document.body.innerHTML')
      payload = extract(page)
      expect_complete_definitions(payload)
      native = Nokogiri::HTML5(payload.fetch('html'))
      expect(native.css('table th')).to be_empty
      expected_cells = ['Edition', 'Storage', 'First edition', '42 records', 'Second edition', '81 records']
      expect(native.css('table td').map(&:text)).to eq(expected_cells)
      rows = payload.fetch('markdown').lines.select { |line| line.lstrip.start_with?('|') }
      expect(rows.first.strip.split('|', -1)[1...-1].map(&:strip)).to eq(['', ''])
      expected_rows = [
        %w[Edition Storage], ['First edition', '42 records'], ['Second edition', '81 records']
      ]
      expect(rows.drop(2).map { |line| line.strip.split('|', -1)[1...-1].map(&:strip) }).to eq(expected_rows)
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end

  it 'keeps hidden, closed and interface definitions excluded without interpreting literal program markup' do
    program = "<dl id=\"community_literal\">\n  <dt>Literal question</dt><dd>Literal answer</dd>\n</dl>"
    extra = <<~HTML
      <dl style="display:none"><dt>Hidden question</dt><dd>Hidden answer</dd></dl>
      <details><summary>Closed reference panel</summary><dl><dt>Closed question</dt><dd>Closed answer</dd></dl></details>
      <nav><dl><dt>Navigation question</dt><dd><a href="/navigation-only/">Navigation answer</a></dd></dl></nav>
      <div role="dialog" aria-modal="true"><dl><dt>Dialog question</dt><dd>Dialog answer</dd></dl></div>
    HTML
    html = definition_material_page(first_class: 'content', extra: extra, program: program)
    with_url_page('https://reference.publication.example.test/manual/', html) do |page|
      before = page.evaluate('document.body.innerHTML')
      payload = extract(page)
      expect_complete_definitions(payload)
      expect(Nokogiri::HTML5(payload.fetch('html')).css('pre').map(&:text)).to eq([program])
      expect(payload.fetch('markdown')).to include(program)
      %w[Hidden Dialog].each do |name|
        expect(payload.fetch('html')).not_to include("#{name} question", "#{name} answer")
      end
      native = Nokogiri::HTML5(payload.fetch('html'))
      %w[Closed Navigation].each do |name|
        native.css('dt, dd').select { |node| ["#{name} question", "#{name} answer"].include?(node.text) }.each do |node|
          expect(node.ancestors.any? { |owner| name == 'Closed' ? owner.name == 'details' && !owner.key?('open') : owner.name == 'nav' }).to be true
        end
      end
      %w[Hidden Closed Navigation Dialog].each do |name|
        expect(payload.fetch('markdown')).not_to include("#{name} question", "#{name} answer")
      end
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end
end
