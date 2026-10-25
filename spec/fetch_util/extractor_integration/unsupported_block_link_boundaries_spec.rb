require 'cgi'
require 'nokogiri'

RSpec.describe 'Unsupported block-link boundaries' do
  include_context 'extractor integration helpers'

  def with_unsupported_block_material(body)
    html = <<~HTML
      <!doctype html><html lang="en"><head><title>Reference boundaries</title></head><body>
      <article><h1>Reference boundaries</h1>
      <p>This publication explains how independent reference records retain their visible material.
      Each record is authored as part of this article, and its complete wording remains useful
      even when its declared destination cannot be represented as a readable reference.</p>
      #{body}
      <p>The final paragraph belongs to the same publication and remains after every record.</p>
      </article></body></html>
    HTML
    with_url_page('https://publication.example.test/reference-boundaries/', html) do |page|
      before = page.evaluate('({html: document.body.outerHTML, text: document.body.innerText})')
      payload = extract_payload(page, reader_mode: false)
      retained = Nokogiri::HTML5.fragment(payload.fetch('html'))
      yield(payload, retained)
      expect(page.evaluate('({html: document.body.outerHTML, text: document.body.innerText})')).to eq(before)
    end
  end

  it 'retains independent block labels after removing unsupported destinations' do
    with_unsupported_block_material(<<~HTML) do |payload, retained|
      <a href="javascript:openRecord()"><div>First visible record</div></a>
      <a href="https://person:secret@restricted.example.test/record"><div>Second visible record</div></a>
    HTML
      expect(retained.text).to include('First visible record', 'Second visible record')
      expect(retained.css('a[href]').map { |link| link['href'] }).to be_empty
      expect(payload.fetch('markdown')).to include("First visible record\n\nSecond visible record")
      expect(payload.fetch('markdown')).not_to include('javascript:', 'person:secret@')
    end
  end

  it 'keeps complete inline formatting and every block within an unlinked record' do
    with_unsupported_block_material(<<~HTML) do |payload, retained|
      <a href="javascript:openRecord()"><p><strong>First complete section</strong></p>
      <p><em>Second complete section</em></p></a>
      <a href="https://person:secret@restricted.example.test/next"><div>Third independent section</div></a>
    HTML
      expect(retained.css('strong').map(&:text)).to eq(['First complete section'])
      expect(retained.css('em').map(&:text)).to eq(['Second complete section'])
      expect(payload.fetch('markdown')).to include(
        "**First complete section**\n\n_Second complete section_\n\nThird independent section"
      )
      expect(payload.fetch('markdown')).not_to include('javascript:', 'person:secret@')
    end
  end

  it 'retains an image and its separate authored paragraphs without joining the following record' do
    with_unsupported_block_material(<<~HTML) do |payload, retained|
      <a href="javascript:openRecord()"><div><img src="https://images.example.test/evidence.png" alt="Declared evidence"></div>
      <p>Complete image context</p><p>Independent image detail</p></a>
      <a href="https://person:secret@restricted.example.test/next"><div>Following visible record</div></a>
    HTML
      expect(retained.css('img').map { |image| [image['src'], image['alt']] }).to eq(
        [['https://images.example.test/evidence.png', 'Declared evidence']]
      )
      expect(payload.fetch('markdown').scan('![Declared evidence](https://images.example.test/evidence.png)').length).to eq(1)
      expect(payload.fetch('markdown')).to include(
        "Complete image context\n\nIndependent image detail\n\nFollowing visible record"
      )
    end
  end

  it 'keeps intentional adjacent inline labels adjacent' do
    with_unsupported_block_material(<<~HTML) do |payload, retained|
      <p><a href="javascript:openRecord()"><span>Un</span></a><a href="https://person:secret@restricted.example.test/next"><span>broken</span></a> identifier.</p>
    HTML
      expect(retained.css('p').map(&:text)).to include('Unbroken identifier.')
      expect(payload.fetch('markdown')).to include('Unbroken identifier.')
      expect(payload.fetch('markdown')).not_to include("Un\n", 'javascript:', 'person:secret@')
    end
  end

  it 'preserves complete permitted inline destinations and their independent occurrences' do
    destination = 'https://reference.example.test/record?mode=%5Bfull%5D&variant=2#part'
    with_unsupported_block_material(<<~HTML) do |payload, retained|
      <p><a href="#{CGI.escapeHTML(destination)}"><span>First</span></a><a href="#{CGI.escapeHTML(destination)}"><span>Second</span></a> inline references.</p>
    HTML
      expect(retained.css('a').map { |link| [link.text, link['href']] }).to eq(
        [['First', destination], ['Second', destination]]
      )
      expect(payload.fetch('markdown')).to include("[First](#{destination})[Second](#{destination}) inline references.")
      expect(payload.fetch('markdown').scan(destination).length).to eq(2)
    end
  end

  it 'preserves literal HTML-looking programs and complete blank lines' do
    program = "show('<a href=\"javascript:openRecord()\"><div>Literal label</div></a>');\n\nfinish();"
    with_unsupported_block_material(<<~HTML) do |payload, retained|
      <pre><code>#{CGI.escapeHTML(program)}</code></pre>
      <a href="javascript:openRecord()"><div>First visible record</div></a>
      <a href="https://person:secret@restricted.example.test/next"><div>Second visible record</div></a>
    HTML
      expect(retained.css('pre').map(&:text)).to eq([program])
      expect(payload.fetch('markdown')).to include(program, "First visible record\n\nSecond visible record")
      expect(payload.fetch('markdown').scan('Literal label').length).to eq(1)
    end
  end

  it 'keeps captured hidden and closed reference bodies out of Markdown' do
    with_unsupported_block_material(<<~HTML) do |payload, retained|
      <div hidden><a href="javascript:openRecord()"><div>Hidden reference body</div></a></div>
      <details><summary>Deferred evidence</summary><a href="https://person:secret@restricted.example.test/private"><div>Closed reference body</div></a></details>
      <a href="javascript:openRecord()"><div>First visible record</div></a>
      <a href="https://person:secret@restricted.example.test/next"><div>Second visible record</div></a>
    HTML
      expect(retained.text).not_to include('Hidden reference body')
      expect(payload.fetch('markdown')).to include('Deferred evidence', "First visible record\n\nSecond visible record")
      expect(payload.fetch('markdown')).not_to include('Hidden reference body', 'Closed reference body')
    end
  end
end
