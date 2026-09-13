# frozen_string_literal: true

RSpec.describe 'Flat list supplementation context' do
  include_context 'extractor integration helpers'

  it 'retains sparse section headings and unlinked notices around all selected records' do
    sections = ['Local reporting', 'Community projects', 'Evening notices'].each_with_index.map do |label, section|
      cards = 5.times.map do |card|
        number = section * 5 + card + 1
        detail = if section != 1 && card < 2
                   '<p>Reporters describe the changes and explain what residents can expect next.</p>'
                 else
                   ''
                 end
        <<~HTML
          <a class="bulletin-teaser" href="/report-#{number}">
            <h3>Neighbourhood report #{number} explains the local changes</h3>#{detail}
          </a>
        HTML
      end.join
      notice = section == 1 ? '<h4>Volunteer registration opens on Friday</h4>' : ''
      "<div class=\"bulletin-grid\"><h2>#{label}</h2>#{cards}#{notice}</div>"
    end.join
    html = <<~HTML
      <main><h1>City bulletin and latest reports</h1>#{sections}
        <div hidden><h2>Unpublished section</h2><a href="/hidden">Hidden report</a></div>
      </main>
    HTML

    extract_from_url('https://bulletin.example.test/', html, reader_mode: false) do |payload|
      markdown = payload['markdown']
      expect(payload['contentType']).to eq('list')
      expect(markdown.scan(%r{https://bulletin\.example\.test/report-\d+})).to eq(
        (1..15).map { |number| "https://bulletin.example.test/report-#{number}" }
      )
      expect(markdown).to include('## Local reporting', '## Community projects', '## Evening notices')
      expect(markdown.index('Community projects')).to be < markdown.index('Neighbourhood report 6')
      expect(markdown.index('Neighbourhood report 10')).to be < markdown.index('Volunteer registration opens')
      expect(markdown.index('Volunteer registration opens')).to be < markdown.index('Evening notices')
      expect(markdown).not_to include('Unpublished section', '/hidden')
    end
  end
end
