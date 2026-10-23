# frozen_string_literal: true

RSpec.describe 'Independent physical section records' do
  include_context 'extractor integration helpers'

  def section_record(number, identical: false, aliases: false, material: false)
    title = identical ? 'Shared publication' : "Publication #{number}"
    detail = identical ? 'An independently materialized paragraph.' : "Complete reporting paragraph #{number}."
    extra = aliases ? '<p><a href="/reports/shared">Read the complete publication</a></p>' : ''
    extra += "<pre>record_#{number}()\n  preserve_all_lines</pre>" if material
    <<~HTML
      <article><h3><a href="/reports/shared?utm_source=record#{number}">#{title}</a></h3>
        <p>#{detail}</p>#{extra}</article>
    HTML
  end

  def section_record_page(identical: false, aliases: false, material: false, nested: false)
    sections = (1..2).map do |section|
      records = (1..3).map do |index|
        section_record((section - 1) * 3 + index, identical: identical, aliases: aliases, material: material)
      end.join
      records = "<section><h2>Inner section #{section}</h2>#{records}</section>" if nested
      "<section><h2>Section #{section}</h2>#{records}</section>"
    end.join
    "<html><head><title>Publication collections</title></head><body><main>#{sections}</main></body></html>"
  end

  def with_section_records(**options)
    with_url_page('https://collections.publication.example.test/', section_record_page(**options)) do |page|
      before = page.evaluate('document.body.outerHTML')
      payload = FetchUtil::Extractor.new(reader_mode: false).extract(page)
      yield payload
      expect(page.evaluate('document.body.outerHTML')).to eq(before)
      expect(payload['byline']).to be_nil
      expect(payload['publishedTime']).to be_nil
    end
  end

  it 'retains complete independently owned records with the same canonical destination' do
    with_section_records do |payload|
      markdown = payload.fetch('markdown')
      expect(markdown.lines.grep(/^### /).map(&:strip)).to eq((1..6).map do |number|
        "### [Publication #{number}](https://collections.publication.example.test/reports/shared?utm_source=record#{number})"
      end)
      paragraphs = (1..6).map { |number| "Complete reporting paragraph #{number}." }
      expect(markdown.scan(/Complete reporting paragraph \d+\./)).to eq(paragraphs)
      expect(markdown.index('## Section 2')).to be > markdown.index(paragraphs.fetch(2))
      expect(markdown.index('## Section 2')).to be < markdown.index(paragraphs.fetch(3))
    end
  end

  it 'retains independent identical cards without globally deduplicating their words or URL' do
    with_section_records(identical: true) do |payload|
      markdown = payload.fetch('markdown')
      expect(markdown.lines.grep(/^### \[Shared publication\]/).length).to eq(6)
      expect(markdown.scan('An independently materialized paragraph.').length).to eq(6)
      expect(markdown.scan(%r{\]\(https://collections\.publication\.example\.test/reports/shared\?utm_source=record\d\)}).length).to eq(6)
    end
  end

  it 'preserves each card once while retaining its separate authored reference occurrences' do
    with_section_records(aliases: true) do |payload|
      markdown = payload.fetch('markdown')
      expect(markdown.lines.grep(/^### /).length).to eq(6)
      expect(markdown.scan(/Complete reporting paragraph \d+\./).length).to eq(6)
      expect(markdown.scan('[Read the complete publication](https://collections.publication.example.test/reports/shared)').length).to eq(6)
    end
  end

  it 'retains every complete program without exposing hidden or closed source material' do
    html = section_record_page(material: true).sub('</main>', <<~HTML)
      <section style="display:none"><h2>Hidden section</h2>#{section_record(7, material: true)}</section>
      <details><summary>Closed sources</summary><section><h2>Closed section</h2>#{section_record(8, material: true)}</section></details>
      </main>
    HTML
    with_url_page('https://collections.publication.example.test/', html) do |page|
      before = page.evaluate('document.body.outerHTML')
      payload = FetchUtil::Extractor.new(reader_mode: false).extract(page)
      markdown = payload.fetch('markdown')
      expect(markdown.lines.grep(/^### /).length).to eq(6)
      (1..6).each { |number| expect(markdown.scan("record_#{number}()\n  preserve_all_lines").length).to eq(1) }
      expect(markdown).not_to include('record_7()', 'record_8()', 'Hidden section', 'Closed section')
      expect(page.evaluate('document.body.outerHTML')).to eq(before)
    end
  end

  it 'does not emit the same physical cards again through overlapping outer and inner regions' do
    with_section_records(nested: true) do |payload|
      markdown = payload.fetch('markdown')
      paragraphs = (1..6).map { |number| "Complete reporting paragraph #{number}." }
      expect(markdown.scan(/Complete reporting paragraph \d+\./)).to eq(paragraphs)
      expect(markdown.lines.grep(/^### /).length).to eq(6)
      expect(markdown).to include('## Inner section 1', '## Inner section 2')
    end
  end
end
