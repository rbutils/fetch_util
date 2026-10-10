require 'spec_helper'

RSpec.describe 'source-owned publisher context in table feeds' do
  include_context 'extractor integration helpers'

  def publisher_table(label: 'publisher.example.test', host: 'journal.publisher.example.test')
    rows = 8.times.map do |index|
      <<~HTML
        <tr><td><a href="https://#{host}/report/#{index}">Authored report #{index}</a>
        <span>(<a href="/source/#{index}">#{label}</a>)</span></td></tr>
        <tr><td><span>#{index + 10} points</span> by <a rel="author" href="/writer/#{index}">Writer #{index}</a>
        <time datetime="2026-10-09T12:00:00Z">2 hours ago</time> | <a href="/discussion/#{index}">#{index} comments</a></td></tr>
      HTML
    end.join
    "<html><head><title>Community reports</title></head><body><main><h1>Community reports</h1><table>#{rows}</table></main></body></html>"
  end

  it 'retains every story when its publisher label names the destination parent domain' do
    extract_from_url('https://community.example.test/', publisher_table) do |payload|
      expect(payload['contentType']).to eq('social')
      offsets = 8.times.map do |index|
        expect(payload['markdown']).to include("[Authored report #{index}](https://journal.publisher.example.test/report/#{index})", "Writer #{index}")
        payload['markdown'].index("[Authored report #{index}](")
      end
      expect(offsets).to all(be_a(Integer))
      expect(offsets).to eq(offsets.sort)
    end
  end

  it 'keeps URL-shaped publisher context attached to stories without treating it as a competing headline' do
    extract_from_url('https://community.example.test/', publisher_table(label: 'publisher.example.test/account')) do |payload|
      expect(payload['contentType']).to eq('social')
      8.times { |index| expect(payload['markdown']).to include("[Authored report #{index}](") }
    end
  end

  it 'declines social story ownership for a foreign domain-shaped second headline' do
    html = publisher_table(label: 'publisher.example.test', host: 'otherpublisher.example.test')
    extract_from_url('https://community.example.test/', html) do |payload|
      expect(payload['contentType']).not_to eq('social')
      expect(payload['markdown']).to include('Authored report 0', 'Authored report 7', 'publisher.example.test')
    end
  end
end
