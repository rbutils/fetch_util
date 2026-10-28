# frozen_string_literal: true

require 'spec_helper'
require 'nokogiri'
require 'open3'

RSpec.describe 'FetchUtil physically owned directory information groups' do
  include_context 'extractor integration helpers'

  def informational_group(suffix, assessment: 'Complete and checked')
    <<~HTML
      <div class="certificate" id="certificate-#{suffix}">
        <div class="certificate__header"><h3>Reference coverage</h3><p>Complete declaration.</p></div>
        <div class="certificate__subject"><a href="https://inspection.example.test/report?subject=directory&amp;format=full#evidence">Directory publication</a></div>
        <div class="certificate__footer"><h3>#{assessment}</h3><p>Inspected by <a href="https://inspection.example.test/">Independent inspection</a>.</p></div>
        <p>2026 assessment edition.</p>
      </div>
    HTML
  end

  def with_directory_information(_name, material)
    records = (1..6).map do |index|
      "<li><a href=\"https://publication.example.test/guide/#{index}?edition=2#details\">Complete reference guide #{index}</a></li>"
    end.join
    html = <<~HTML
      <!doctype html><html><head><title>Directory publication</title>
      <link rel="canonical" href="https://publication.example.test/"></head><body>
      <div id="page"><section><h2>Directory publication</h2>
      <p>This publication describes a federated directory and preserves the complete references, independent inspection declarations and limitations that readers need to interpret its information.</p>
      <div class="columns"><div><h2>Reference guides</h2><ul>#{records}</ul></div>
      <div><h2>Contact and maintenance</h2><p>The maintenance documentation records reproducible procedures and independent evidence for every published reference.</p>
      <a href="https://publication.example.test/maintenance">Complete maintenance documentation</a></div></div>
      <div class="inspection-area"><h3>Independent assessment</h3>#{material}</div>
      <pre><code>record("&lt;complete&gt;")

      verify("first&amp;second")</code></pre>
      <p>The final limitations remain a complete independently authored paragraph.</p>
      </section></div></body></html>
    HTML
    with_url_page('https://publication.example.test/', html) do |page|
      before = page.evaluate('document.body.outerHTML')
      payload = extract_payload(page, reader_mode: false)
      parser = "from markdown_it import MarkdownIt\nimport sys\nprint(MarkdownIt('commonmark').enable('table').render(sys.stdin.read()))"
      rendered, error, status = Open3.capture3('python', '-c', parser, stdin_data: payload.fetch('markdown'))
      raise "independent parser failed: #{error}" unless status.success?
      expect(page.evaluate('document.body.outerHTML')).to eq(before)
      native = Nokogiri::HTML5.fragment(payload.fetch('html'))
      markdown = Nokogiri::HTML5.fragment(rendered)
      [native, markdown].each do |document|
        expect(document.css('a[href]').select { |link| link['href'].include?('/guide/') }.map(&:text)).to eq(
          (1..6).map { |index| "Complete reference guide #{index}" }
        )
        expect(document.css('pre').map { |node| node.text.delete_suffix("\n") }).to eq(
          ["record(\"<complete>\")\n\nverify(\"first&second\")"]
        )
        expect(document.css('p').map { |node| node.text.gsub(/\s+/, ' ').strip }).to include(
          'The final limitations remain a complete independently authored paragraph.'
        )
      end
      yield native, markdown, payload
    ensure
      expect(page.evaluate('document.body.outerHTML')).to eq(before)
    end
  end

  it 'preserves complete heading, status and reference material inside a physical information group' do
    with_directory_information('complete-group', informational_group('one')) do |native, markdown, _payload|
      [native, markdown].each do |document|
        expect(document.css('h3').map(&:text)).to eq(
          ['Independent assessment', 'Reference coverage', 'Complete and checked']
        )
        expect(document.css('p').map { |node| node.text.gsub(/\s+/, ' ').strip }).to include(
          'Complete declaration.', 'Inspected by Independent inspection.', '2026 assessment edition.'
        )
        expect(document.css('a[href]').select { |link| link['href'].include?('inspection.example.test') }
          .map { |link| [link['href'], link.text] }).to eq(
            [
              ['https://inspection.example.test/report?subject=directory&format=full#evidence', 'Directory publication'],
              ['https://inspection.example.test/', 'Independent inspection']
            ]
          )
      end
    end
  end

  it 'keeps independent same-destination information groups in physical source order' do
    material = informational_group('first', assessment: 'First independent assessment') +
               informational_group('second', assessment: 'Second independent assessment')
    with_directory_information('independent-groups', material) do |native, markdown, _payload|
      [native, markdown].each do |document|
        expect(document.css('h3').map(&:text)).to eq(
          [
            'Independent assessment', 'Reference coverage', 'First independent assessment',
            'Reference coverage', 'Second independent assessment'
          ]
        )
        expect(document.css('p').map(&:text).count { |text| text.strip == 'Complete declaration.' }).to eq(2)
        expect(document.css('a[href="https://inspection.example.test/"]').map(&:text)).to eq(
          ['Independent inspection', 'Independent inspection']
        )
      end
    end
  end

  it 'excludes actual navigation and interaction owners rather than inferring ownership from their text' do
    material = '<nav><div class="certificate__header"><h3>Navigation options</h3><p>Choose a destination.</p></div>' \
      '<div class="certificate__footer"><h3>Navigation footer</h3><p><a href="/nav-only">Navigation reference</a></p></div></nav>' \
      '<div role="toolbar"><div class="certificate__header"><h3>Toolbar choices</h3><p>Choose an action.</p></div></div>' \
      '<p>The independently authored inspection explanation remains complete.</p>'
    with_directory_information('interfaces', material) do |native, markdown, _payload|
      [native, markdown].each do |document|
        expect(document.text).not_to include('Navigation options', 'Choose a destination.', 'Navigation footer',
                                             'Navigation reference', 'Toolbar choices', 'Choose an action.')
        expect(document.css('a[href]').map { |link| link['href'] }).not_to include('https://publication.example.test/nav-only')
        expect(document.text).to include('The independently authored inspection explanation remains complete.')
      end
    end
  end

  it 'keeps captured-hidden and closed-body groups excluded while preserving their visible surrounding document' do
    material = "<div hidden>#{informational_group("hidden", assessment: "Hidden inspection")}</div>" \
      "<div style=\"display:none\">#{informational_group("styled-hidden", assessment: "Styled hidden inspection")}</div>" \
      "<details><summary>Closed assessment</summary>#{informational_group("closed", assessment: "Closed inspection")}</details>" \
      '<p>The independently visible inspection context remains complete.</p>'
    with_directory_information('visibility', material) do |native, markdown, _payload|
      [native, markdown].each do |document|
        expect(document.text).not_to include('Hidden inspection', 'Styled hidden inspection')
        expect(document.text).to include('The independently visible inspection context remains complete.')
      end
      expect(markdown.text).not_to include('Closed inspection', 'Complete declaration.', 'Inspected by Independent inspection.')
      native.css('h3, p').select do |node|
        ['Closed inspection', 'Complete declaration.', 'Inspected by Independent inspection.'].include?(node.text.strip)
      end.each do |node|
        owner = node.ancestors('details').first
        expect(owner).not_to be_nil
        expect(owner.key?('open')).to eq(false)
      end
    end
  end
end
