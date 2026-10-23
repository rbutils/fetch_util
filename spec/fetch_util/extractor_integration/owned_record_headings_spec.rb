require 'spec_helper'
require 'nokogiri'

RSpec.describe 'FetchUtil physically owned record heading roles' do
  include_context 'extractor integration helpers'

  def owned_heading_page(rank: 2, inline: false, extra: '')
    records = (1..13).map do |number|
      level = rank.respond_to?(:call) ? rank.call(number) : rank
      label = inline ? "Record <em>heading</em> <code>revision_#{number}</code>" : "Independent record heading #{number}"
      <<~HTML
        <article><h#{level}>#{label}</h#{level}>
          <a href="/reports/#{number}">Independent report destination #{number}</a>
          <p>Complete authored reporting belongs only to physical record #{number}.</p>#{extra}</article>
      HTML
    end.join
    <<~HTML
      <html><head><title>Independent publication</title></head><body>
        <main><h1>Independent publication</h1>#{records}</main></body></html>
    HTML
  end

  def with_owned_heading_result(**options)
    with_url_page('https://records.publication.example.test/', owned_heading_page(**options)) do |page|
      before = page.evaluate('document.body.outerHTML')
      payload = FetchUtil::Extractor.new.extract(page)
      markdown = payload.fetch('markdown')
      expect(payload.fetch('title')).to eq('Independent publication')
      expect(payload['byline']).to be_nil
      expect(payload['publishedTime']).to be_nil
      (1..13).each do |number|
        expect(markdown.scan("https://records.publication.example.test/reports/#{number})").length).to eq(1)
        expect(markdown.scan("Complete authored reporting belongs only to physical record #{number}.").length).to eq(1)
      end
      yield markdown
      expect(page.evaluate('document.body.outerHTML')).to eq(before)
    end
  end

  it 'keeps each source-owned unlinked heading before its own complete reference and prose' do
    with_owned_heading_result do |markdown|
      positions = (1..13).map do |number|
        heading = "## Independent record heading #{number}"
        expect(markdown.lines.map(&:strip).count(heading)).to eq(1)
        destination = "[Independent report destination #{number}](https://records.publication.example.test/reports/#{number})"
        expect(markdown.index(heading)).to be < markdown.index(destination)
        expect(markdown.index(destination)).to be < markdown.index("Complete authored reporting belongs only to physical record #{number}.")
        markdown.index(heading)
      end
      expect(positions).to eq(positions.sort)
    end
  end

  it 'preserves the independently declared heading ranks across repeated physical records' do
    rank = ->(number) { 2 + ((number - 1) % 5) }
    with_owned_heading_result(rank: rank) do |markdown|
      (1..13).each do |number|
        heading = "#{"#" * rank.call(number)} Independent record heading #{number}"
        expect(markdown.lines.map(&:strip).count(heading)).to eq(1)
      end
    end
  end

  it 'preserves emphasis and literal inline programs inside owned headings' do
    with_owned_heading_result(rank: 3, inline: true) do |markdown|
      (1..13).each do |number|
        expect(markdown.lines.map(&:strip)).to include("### Record _heading_ `revision_#{number}`")
      end
    end
  end

  it 'retains complete owned programs while hidden and closed headings stay excluded' do
    extra = <<~HTML
      <pre><code>const complete_record_value = "unchanged";</code></pre>
      <div hidden><h2>Hidden auxiliary heading</h2><p>Hidden auxiliary prose.</p></div>
      <details><summary>Supplement</summary><h3>Closed auxiliary heading</h3><p>Closed auxiliary prose.</p></details>
    HTML
    with_owned_heading_result(extra: extra) do |markdown|
      (1..13).each do |number|
        expect(markdown.lines.map(&:strip)).to include("## Independent record heading #{number}")
      end
      expect(markdown.scan('const complete_record_value = "unchanged";').length).to eq(13)
      expect(markdown).not_to include('Hidden auxiliary heading', 'Hidden auxiliary prose.', 'Closed auxiliary heading', 'Closed auxiliary prose.')
    end
  end

  it 'keeps selected HTML and publisher metadata while restoring sibling heading roles' do
    cards = Array.new(13) do |index|
      number = index + 1
      "<article><h2>Portal heading #{number}</h2><a href=\"/items/#{number}\">Portal item #{number} with useful detail</a></article>"
    end.join
    html = "<html><head><title>Portal</title></head><body><main><h1>Portal home</h1>#{cards}</main></body></html>"

    with_url_page('https://flat.example/', html) do |page|
      before = page.evaluate('document.body.outerHTML')
      payload = FetchUtil::Extractor.new(reader_mode: false).extract(page)
      native = Nokogiri::HTML5.fragment(payload.fetch('html'))

      expect(native.css('h2').map(&:text)).to eq((1..13).map { |number| "Portal heading #{number}" })
      expect(native.css('a[href]').map { |node| [node.text, node['href']] }).to eq((1..13).map do |number|
        ["Portal item #{number} with useful detail", "https://flat.example/items/#{number}"]
      end)
      expect(payload.values_at('title', 'excerpt', 'byline', 'publishedTime')).to eq(['Portal', 'Portal item 1 with useful detail', nil, nil])
      expect(payload.fetch('markdown').scan(/^## Portal heading \d+$/)).to eq((1..13).map { |number| "## Portal heading #{number}" })
      expect(page.evaluate('document.body.outerHTML')).to eq(before)
    end
  end
end
