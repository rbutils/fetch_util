# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Adjacent source-owned article headings' do
  include_context 'extractor integration helpers'

  let(:short_title) { 'Funding changes for the regional transport network' }
  let(:full_title) { 'Funding changes for the regional transport network: “The next phase will reach every district in 2027”' }
  let(:body) do
    <<~HTML
      <p>The ministry outlined its next phase of funding for the regional transport network, with details on the new routes, timetable, and stations for residents.</p>
      <p>Officials said the next phase will reach every district in 2027, following a year of infrastructure work across the network.</p>
      <p>The announced programme also covers maintenance, safety checks, accessibility upgrades, and publication of progress for the communities affected.</p>
    HTML
  end

  it 'uses a fuller adjacent heading only when the article itself corroborates its missing text' do
    html = <<~HTML
      <html><head><title>#{short_title}</title></head><body>
        <header><h1>#{full_title}</h1></header>
        <article>#{body}</article>
      </body></html>
    HTML

    with_url_page('https://publisher.example/stories/transport-funding', html) do |page|
      before = page.evaluate('document.body.innerHTML')
      payload = extract_payload(page)

      expect(payload['contentType']).to eq('article')
      expect(payload['title']).to eq(full_title)
      expect(payload['markdown']).to start_with("# #{full_title}")
      expect(payload['markdown']).to include('The announced programme also covers maintenance')
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end

  it 'does not promote an invisible adjacent heading even when its words appear in the article' do
    html = <<~HTML
      <html><head><title>#{short_title}</title></head><body>
        <header><h1 hidden>#{full_title}</h1></header>
        <article>#{body}</article>
      </body></html>
    HTML

    with_url_page('https://publisher.example/stories/transport-funding', html) do |page|
      payload = extract_payload(page)
      expect(payload['title']).to eq(short_title)
    end
  end
end
