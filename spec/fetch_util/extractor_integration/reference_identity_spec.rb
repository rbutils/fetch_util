# frozen_string_literal: true

require 'spec_helper'
require 'nokogiri'

RSpec.describe 'Declared reference tree identity' do
  include_context 'extractor integration helpers'

  def reference_html(identity: 'Domain::Ledger', tree: '["Domain","Ledger"]')
    modules = (1..36).map { |index| "<li><a href='/api/Capabilities#{index}.html'>Domain::Capabilities#{index}</a></li>" }.join
    prose = (1..8).map do |index|
      "<p>Section #{index} explains the ledger's actual behavior and the relationship between its " \
        'stored values, input validation, persistence and public contract.</p>'
    end.join
    <<~HTML
      <!doctype html><html><head><title>#{identity}</title>
      <meta name="data-tree-keys" content='#{tree}'><meta name="data-rel-prefix" content="../">
      </head><body><nav><h1>Files</h1><a href='/files/private'>Unrelated file navigation</a></nav>
      <main id="bodyContent"><div id="content"><div class="description">
      <h1>Ledger behavior</h1><h2 id="operations"><a href="#operations">Operations</a></h2>
      #{prose}<pre><code>ledger.validate(input)</code></pre></div>
      <h3 class="sectiontitle">Included Modules</h3><ul>#{modules}</ul></div></main></body></html>
    HTML
  end

  it 'retains every declared reference relationship beside the prose and code' do
    with_url_page('https://reference.example.test/api/Ledger.html', reference_html) do |page|
      result = extract(page)
      document = Nokogiri::HTML5.fragment(result.fetch('html'))

      expect(result.fetch('title')).to eq('Domain::Ledger')
      expect(result.fetch('readerMode')).to be(false)
      expect(document.css('a[href]').map { |link| link['href'] }).to eq((1..36).map { |index| "https://reference.example.test/api/Capabilities#{index}.html" })
      expect(result.fetch('markdown')).to include('ledger.validate(input)')
      expect(document.at_css('#operations').text).to eq('Operations')
      expect(document.css('p').map(&:text)).to include(a_string_including('Section 8 explains'))
      expect(result.fetch('markdown')).not_to include('Unrelated file navigation')
    end
  end

  it 'does not treat a conflicting tree identity as a declared documentation engine' do
    with_url_page('https://reference.example.test/story', reference_html(identity: 'A different authored page')) do |page|
      result = extract(page)

      expect(result.fetch('readerMode')).to be(true)
      expect(result.fetch('markdown')).to include('Section 8 explains')
    end
  end

  it 'rejects malformed declaration data while retaining the ordinary source content' do
    with_url_page('https://reference.example.test/story', reference_html(tree: 'not-json')) do |page|
      result = extract(page)

      expect(result.fetch('readerMode')).to be(true)
      expect(result.fetch('markdown')).to include('ledger.validate(input)')
    end
  end
end
