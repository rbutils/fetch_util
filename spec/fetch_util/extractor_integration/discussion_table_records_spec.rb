# frozen_string_literal: true

RSpec.describe 'FetchUtil structured list table records' do
  include_context 'extractor integration helpers'

  def discussion_table_page
    rows = 18.times.map do |index|
      <<~HTML
        <tr><td><b><a href="/topic/#{index}">Club:</a></b> <a href="/topic/#{index}">Q#{index}</a></td>
          <td><a href="/author/#{index}">Writer #{index}</a></td><td>#{index + 1}</td>
          <td>#{index + 50}</td><td>September #{index + 1}, 2026</td></tr>
      HTML
    end.join
    <<~HTML
      <html><head><title>River restoration discussions</title></head><body><main>
        <h1>River restoration discussions</h1><p>Talk about the <a href="/book">restoration handbook</a> by
          <a href="/editor">the river editor</a>.</p>
        <table><thead><tr><th>Topic</th><th>Started by</th><th>Posts</th><th>Views</th><th>Last activity</th></tr></thead>
          <tbody>#{rows}<tr hidden><td><a href="/hidden">Hidden topic</a></td><td>Hidden author</td><td>1</td><td>2</td><td>September</td></tr></tbody></table>
      </main></body></html>
    HTML
  end

  it 'preserves every short-title row, supporting destination, and metadata column in source order' do
    extract_from_url('https://discussion.test/book/discussions', discussion_table_page) do |payload|
      markdown = payload['markdown']
      expect(payload['contentType']).to eq('list')
      expect(markdown).to include('https://discussion.test/book', 'https://discussion.test/editor')
      18.times do |index|
        expect(markdown).to include("[Q#{index}](https://discussion.test/topic/#{index})")
        expect(markdown).to include("[Writer #{index}](https://discussion.test/author/#{index})")
        expect(markdown).to include("| #{index + 1} | #{index + 50} | September #{index + 1}, 2026 |")
      end
      positions = 18.times.map { |index| markdown.index("[Q#{index}](") }
      expect(positions).to eq(positions.sort)
      expect(markdown).not_to include('Hidden topic', 'https://discussion.test/hidden')
      expect(payload['html']).to include('Topic', 'Last activity', 'Writer 17')
    end
  end

  it 'does not promote navigation tables with short link labels as structured data records' do
    navigation = '<nav><table><tr><td><a href="/nav">Nav</a></td><td>Tools</td><td>Menu</td></tr></table></nav>'
    html = discussion_table_page.sub('<main>', "<main>#{navigation}")

    extract_from_url('https://discussion.test/book/discussions', html) do |payload|
      expect(payload['markdown']).not_to include('https://discussion.test/nav')
      expect(payload['markdown']).to include('[Q0](https://discussion.test/topic/0)')
    end
  end
end
