require 'spec_helper'

RSpec.describe 'Source-declared summaries for proved portal collections' do
  include_context 'extractor integration helpers'

  def portal_summary_html(description: true)
    summary = 'A complete overview of current public reporting, research and community affairs.'
    declared = description ? "<meta name='description' content='#{summary}'>" : ''
    sections = %w[Research Community].map do |section|
      cards = (1..6).map do |index|
        "<article class='card'><h3><a href='/reports/#{section.downcase}-#{index}'>#{section} reporting headline #{index}</a></h3>" \
          "<p>An authored reporting summary for #{section.downcase} observation #{index} with meaningful detail.</p></article>"
      end.join
      "<section><h2>#{section} reporting</h2>#{cards}</section>"
    end.join
    <<~HTML
      <html><head><title>Public Reporting</title>#{declared}</head><body><main><h1>Public Reporting</h1>
      <section><h2>Market indicators</h2><article class='card'><h3><a href='/markets/unit'>UNIT 49.27</a></h3></article></section>
      #{sections}</main></body></html>
    HTML
  end

  it 'uses the whole-page declaration rather than a first ticker while retaining every record' do
    with_url_page('https://reporting.example.test/', portal_summary_html) do |page|
      payload = extract(page)
      expect(payload.fetch('contentType')).to eq('list')
      expect(payload.fetch('excerpt')).to eq('A complete overview of current public reporting, research and community affairs.')
      expect(payload.fetch('markdown')).to include('UNIT 49.27', 'Research reporting headline 6', 'Community reporting headline 6')
    end
  end

  it 'keeps the first materialized record as a fallback when no page declaration is available' do
    with_url_page('https://reporting.example.test/', portal_summary_html(description: false)) do |page|
      payload = extract(page)
      expect(payload.fetch('contentType')).to eq('list')
      expect(payload.fetch('excerpt')).not_to be_empty
      expect(payload.fetch('markdown')).to include('UNIT 49.27', 'Research reporting headline 6', 'Community reporting headline 6')
    end
  end
end
