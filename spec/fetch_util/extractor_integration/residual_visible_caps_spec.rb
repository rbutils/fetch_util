# frozen_string_literal: true

RSpec.describe 'FetchUtil residual visible-content caps' do
  include_context 'extractor integration helpers'

  def residual_fixture(name)
    fixture_contents(File.expand_path("../../fixtures/residual_#{name}.html", __dir__))
  end

  it 'keeps default news homepage entries beyond eighteen' do
    links = Array.new(19) do |index|
      number = index + 1
      "<section><a href=\"https://www.ft.com/content/residual-#{number}\">A sufficiently long Financial Times story #{number}</a><p>Local story context.</p></section>"
    end.join

    extract_from_url('https://www.ft.com/', "<html><head><title>Financial Times</title></head><body>#{links}</body></html>") do |payload|
      expect(payload['contentType']).to eq('list')
      expect(payload['markdown']).to include('Financial Times story 19')
    end
  end

  it 'keeps Xinhua weekly entries beyond eighteen' do
    extract_from_url('https://english.news.cn/weekly.htm', residual_fixture('xinhua_weekly')) do |payload|
      expect(payload['contentType']).to eq('list')
      expect(payload['markdown']).to include('Weekly issue 19')
    end
  end

  it 'keeps Unidad Editorial homepage entries beyond eighteen' do
    extract_from_url('https://www.elmundo.es/', residual_fixture('unidad')) do |payload|
      expect(payload['contentType']).to eq('list')
      expect(payload['markdown']).to include('Unidad Editorial story number 19')
    end
  end

  it 'keeps job cards beyond eighteen and their complete local detail' do
    extract_from_url('https://jobs.example.com/search/jobs', residual_fixture('jobs')) do |payload|
      expect(payload['contentType']).to eq('list')
      expect(payload['markdown']).to include('Remote engineering role 19')
      expect(payload['markdown']).to include('The final clause proves preservation.')
    end
  end

  it 'keeps product cards beyond fifteen' do
    extract_from_url('https://shop.example.com/products', residual_fixture('products')) do |payload|
      expect(payload['contentType']).to eq('list')
      expect(payload['markdown']).to include('Product item 16')
    end
  end

  it 'keeps complete Discourse topic context' do
    extract_from_url('https://forum.example.com/latest', residual_fixture('discourse')) do |payload|
      expect(payload['contentType']).to eq('social')
      expect(payload['markdown']).to include('The final clause proves preservation.')
    end
  end

  it 'keeps every descriptive block in a flat list' do
    descriptions = Array.new(9) do |index|
      "<p>Descriptive block #{index + 1} preserves a complete visible paragraph with useful local context and ordering.</p>"
    end.join
    html = "<html><head><title>Directory</title></head><body><main>#{descriptions}</main></body></html>"

    extract_from_url('https://directory.example.com/list', html) do |payload|
      expect(payload['markdown']).to include('Descriptive block 9')
    end
  end

  it 'keeps long generic card context through final Markdown' do
    context = 'This complete card summary continues past the old boundary and retains visible local context for readers. ' * 8
    context += 'The final local sentence remains available for readers.'
    html = <<~HTML
      <html><head><title>Stories</title></head><body><main>
        <article><h2><a href="/story/1">A sufficiently descriptive story title for the list</a></h2>
          <p>#{context}</p><time>2026-07-10T12:00:00Z</time><figcaption>A complete caption remains visible.</figcaption>
        </article>
        <article><h2><a href="/story/2">Another sufficiently descriptive story title for the list</a></h2><p>Second story context.</p></article>
        <article><h2><a href="/story/3">Third sufficiently descriptive story title for the list</a></h2><p>Third story context.</p></article>
      </main></body></html>
    HTML

    extract_from_url('https://stories.example.com/', html) do |payload|
      expect(payload['markdown']).to include('The final local sentence remains available for readers.')
      expect(payload['markdown']).to include('A complete caption remains visible.')
    end
  end
end
