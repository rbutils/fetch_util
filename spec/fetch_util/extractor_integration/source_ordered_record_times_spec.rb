require 'spec_helper'

RSpec.describe 'FetchUtil source-ordered record times' do
  include_context 'extractor integration helpers'

  def timed_record(number, time, extra: '')
    <<~HTML
      <article>
        <h2><a href="/reports/#{number}">Publication schedule report #{number}</a></h2>
        #{time}
        <p>Complete independently authored report #{number}.</p>
        #{extra}
      </article>
    HTML
  end

  def timed_page(records)
    <<~HTML
      <html><head><title>Publication schedule archive</title></head>
        <body><main><h1>Publication schedule archive</h1>#{records}</main></body>
      </html>
    HTML
  end

  it 'retains declared times, visible labels, markup and independent occurrences in their source order' do
    declarations = [
      ['2026-04-10T09:00:00', '9:00 CET'],
      ['2026-04-10T10:00:00+02:00', '<strong>10:00 CEST</strong>'],
      ['2026-04-10', '2026-04-10'],
      ['2026-04-10T11:15:00Z', '<a href="/schedule">11:15 UTC</a>'],
      ['2026-04-10T09:00:00', '9:00 CET'],
      ['2026-04-11', ''],
      ['2026-04-12', '<span>Updated 2026-04-12</span>']
    ]
    records = declarations.each_with_index.map do |(value, label), index|
      timed_record(index + 1, "<time datetime=\"#{value}\">#{label}</time>")
    end.join

    with_url_page('https://publication.example.test/archive', timed_page(records)) do |page|
      before = page.evaluate('document.body.outerHTML')
      payload = FetchUtil::Extractor.new(reader_mode: false).extract(page)
      markdown = payload['markdown']

      expect(payload['contentType']).to eq('list')
      expect(markdown.scan('2026-04-10T09:00:00').length).to eq(2)
      expect(markdown).to include('**10:00 CEST**', '[11:15 UTC](https://publication.example.test/schedule)')
      blocks = markdown.split(/(?=^## \[Publication schedule report )/).select do |block|
        block.start_with?('## [Publication schedule report ')
      end
      expect(blocks.length).to eq(declarations.length)
      declarations.each_with_index do |(value, label), index|
        number = index + 1
        block = blocks.fetch(index)
        expect(block).to start_with("## [Publication schedule report #{number}](https://publication.example.test/reports/#{number})")
        expect(block.scan(value).length).to eq(1)
        expect(block).to include(Nokogiri::HTML5.fragment(label).text) unless label.empty?
        expect(block.index(value)).to be < block.index("Complete independently authored report #{number}.")
      end
      expect(page.evaluate('document.body.outerHTML')).to eq(before)
    end
  end

  it 'preserves visible disclosure labels and complete programs without exposing excluded declarations' do
    extras = <<~HTML
      <div hidden><time datetime="2031-01-01">Hidden schedule</time></div>
      <div style="display:none"><time datetime="2032-02-02">Styled hidden schedule</time></div>
      <details>
        <summary>Schedule options <time datetime="2026-04-10T20:00:00">Evening</time></summary>
        <time datetime="2033-03-03">Closed schedule</time>
      </details>
      <button><time datetime="2034-04-04">Schedule control</time></button>
      <form><time datetime="2037-07-07">Form schedule</time><input name="schedule"></form>
      <pre><code><time datetime="2035-05-05">11:11</time></code></pre>
      <pre><code>&lt;time datetime="2036-06-06"&gt;literal declaration&lt;/time&gt;</code></pre>
    HTML
    records = (1..5).map do |number|
      timed_record(number, '<time datetime="2026-04-10T09:00:00">Morning</time>', extra: number == 1 ? extras : '')
    end.join

    with_url_page('https://publication.example.test/archive', timed_page(records)) do |page|
      before = page.evaluate('document.body.outerHTML')
      payload = FetchUtil::Extractor.new(reader_mode: false).extract(page)
      markdown = payload['markdown']

      expect(markdown.scan('2026-04-10T09:00:00').length).to eq(5)
      expect(markdown).to include('Evening', '2026-04-10T20:00:00')
      %w[2031-01-01 2032-02-02 2033-03-03 2034-04-04 2035-05-05 2037-07-07].each do |value|
        expect(markdown).not_to include(value)
      end
      expect(markdown).to include("```\n11:11\n```", "```\n<time datetime=\"2036-06-06\">literal declaration</time>\n```")
      expect(page.evaluate('document.body.outerHTML')).to eq(before)
    end
  end
end
