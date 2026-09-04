# frozen_string_literal: true

RSpec.describe 'FetchUtil extractor same-root list coverage' do
  include_context 'extractor integration helpers'

  def same_root_card(number, title: nil, summary: true)
    title ||= "Complete archive record #{number}"
    paragraph = summary ? "<p>Local summary for archive record #{number}.</p>" : ''
    <<~HTML
      <article>
        <h3><a href="/records/#{number}">#{title}</a></h3>
        #{paragraph}
      </article>
    HTML
  end

  def same_root_section(label, numbers)
    cards = numbers.map { |number| same_root_card(number) }.join
    "<section><h2>#{label}</h2>#{cards}</section>"
  end

  def same_root_neutral_section(label, numbers)
    cards = numbers.map { |number| same_root_card(number) }.join
    "<div class=\"content-group\"><h2>#{label}</h2>#{cards}</div>"
  end

  def same_root_links(numbers)
    items = numbers.map do |number|
      "<li><a href=\"/records/#{number}\">Complete archive record #{number}</a></li>"
    end.join
    "<ul>#{items}</ul>"
  end

  def extracted_record_numbers(markdown)
    markdown.scan(%r{\]\(https://coverage\.example/records/(\d+)\)}).flatten.map(&:to_i)
  end

  it 'adds same-root records omitted by minority sections without losing section context' do
    html = <<~HTML
      <html><head><title>Complete archive</title></head><body><main>
        <h1>Complete archive</h1>
        <p>Browse the complete public archive and its locally described featured records.</p>
        #{same_root_section("Featured records", [1])}
        #{same_root_section("Latest records", [2, 3])}
        #{same_root_links(4..10)}
      </main></body></html>
    HTML

    with_url_page('https://coverage.example/', html) do |page|
      payload = FetchUtil::Extractor.new(reader_mode: false).extract(page)
      markdown = payload['markdown']

      expect(payload['contentType']).to eq('list')
      expect(extracted_record_numbers(markdown)).to eq((1..10).to_a)
      expect(markdown.scan(/^## (.+)$/).flatten).to include('Featured records', 'Latest records')
      expect(markdown).to include('Local summary for archive record 1.')
      expect(markdown.index('## Featured records')).to be < markdown.index('/records/1')
    end
  end

  it 'retains section-only output at exactly half of flat coverage' do
    html = <<~HTML
      <html><head><title>Balanced archive</title></head><body><main>
        <h1>Balanced archive</h1>
        #{same_root_section("Featured records", [1, 2])}
        #{same_root_section("Latest records", [3, 4])}
        #{same_root_links(5..8)}
      </main></body></html>
    HTML

    with_url_page('https://coverage.example/', html) do |page|
      payload = FetchUtil::Extractor.new(reader_mode: false).extract(page)

      expect(extracted_record_numbers(payload['markdown'])).to eq((1..4).to_a)
      expect(payload['markdown']).not_to include('/records/5')
    end
  end

  it 'retains section-only output when flat extraction loses a section record' do
    html = <<~HTML
      <html><head><title>Identity archive</title></head><body><main>
        <h1>Identity archive</h1>
        <section><h2>Featured records</h2>#{same_root_card(1, title: "Short 1", summary: false)}</section>
        #{same_root_section("Latest records", [2])}
        #{same_root_links(3..8)}
      </main></body></html>
    HTML

    with_url_page('https://coverage.example/', html) do |page|
      payload = FetchUtil::Extractor.new(reader_mode: false).extract(page)

      expect(extracted_record_numbers(payload['markdown'])).to eq([1, 2])
      expect(payload['markdown']).to include('Short 1')
      expect(payload['markdown']).not_to include('/records/3')
    end
  end

  it 'requires a flat occurrence for every repeated section record' do
    html = <<~HTML
      <html><head><title>Recurring record archive</title></head><body><main><h1>Recurring record archive</h1>
        <section>
          <h2>Spring records</h2>
          <article><h3><a href="/records/recurring">Recurring archive record</a></h3><time datetime="2026-03-01"></time><p>Shared record context</p></article>
        </section>
        <section>
          <h2>Autumn records</h2>
          <article><h3><a href="/records/recurring">Recurring archive record</a></h3><time datetime="2026-09-01"></time><p>Shared record context</p></article>
        </section>
        #{same_root_links(3..8)}
      </main></body></html>
    HTML

    with_url_page('https://coverage.example/recurring', html) do |page|
      payload = extract_payload(page)
      markdown = payload['markdown']

      expect(markdown.scan('](https://coverage.example/records/recurring)').length).to eq(2)
      expect(markdown).to include('## Spring records', '## Autumn records', '2026-03-01', '2026-09-01')
      expect(markdown).not_to include('/records/3')
    end
  end

  it 'rejects flat additions when one shared wrapper owns half of them' do
    shared_links = (3..4).map do |number|
      "<h3><a href=\"/records/#{number}\">Complete archive record #{number}</a></h3>"
    end.join
    local_links = (5..6).map do |number|
      "<div><h3><a href=\"/records/#{number}\">Complete archive record #{number}</a></h3></div>"
    end.join
    html = <<~HTML
      <html><head><title>Local archive</title></head><body>
        <h1>Local archive</h1>
        #{same_root_section("Featured records", [1])}
        #{same_root_section("Latest records", [2])}
        <div class="record-pool">#{shared_links}</div>
        #{local_links}
      </body></html>
    HTML

    with_url_page('https://coverage.example/', html) do |page|
      payload = FetchUtil::Extractor.new(reader_mode: false).extract(page)

      expect(extracted_record_numbers(payload['markdown'])).to eq([1, 2])
      expect(payload['markdown']).not_to include('/records/3')
    end
  end

  it 'keeps expanded records from creating new portal ownership evidence' do
    excerpt = 'Independent context for every organization represented in this public directory.'
    html = <<~HTML
      <html><head>
        <title>Marketplace directory</title>
        <meta name="description" content="#{excerpt}">
      </head><body><main>
        <h1>Marketplace directory</h1>
        #{same_root_neutral_section("Featured records", [1])}
        #{same_root_neutral_section("Latest records", [2])}
        #{same_root_links(3..7)}
      </main></body></html>
    HTML

    with_url_page('https://coverage.example/', html) do |page|
      payload = FetchUtil::Extractor.new(reader_mode: false).extract(page)

      expect(extracted_record_numbers(payload['markdown'])).to eq((1..7).to_a)
      expect(payload['markdown']).to include(excerpt)
    end
  end
end
