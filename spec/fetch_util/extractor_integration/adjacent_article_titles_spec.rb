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

  it 'uses a unique self-linked article headline instead of an unrelated blog suffix' do
    headline = 'Local researchers publish complete transport funding records for every district'
    html = <<~HTML
      <html><head><title>#{headline} | Author journal and notebook</title></head><body><main>
        <article>
          <h1><a href="/reports/funding-records">#{headline}</a></h1>
          <p>The first section explains where the public funding originated and how the regional transport team checked the submitted documents.</p>
          <p>The published records also name each district, the expected completion dates, and the public consultation held before decisions were made.</p>
          <p>Readers can review the complete report and compare the independent measurements with the ministry's own published timetable.</p>
        </article>
      </main></body></html>
    HTML

    extract_from_url('https://journal.example/reports/funding-records', html) do |payload|
      expect(payload['title']).to eq(headline)
      expect(payload['markdown']).to include('each district', 'independent measurements')
    end
  end

  it 'does not trust a linked heading that points to a different article' do
    headline = 'Local researchers publish complete transport funding records for every district'
    html = <<~HTML
      <html><head><title>#{headline} | Regional research archive</title></head><body><main>
        <article>
          <h1><a href="/reports/another-story">#{headline}</a></h1>
          <p>The complete regional report explains the public funding decisions and offers the original records for review by affected residents.</p>
          <p>Each section describes the local consultation, the possible route changes, and the dates when the final policy will be announced.</p>
          <p>Researchers also published independent measurements that readers can compare with the ministry's own report and supporting evidence.</p>
        </article>
      </main></body></html>
    HTML

    with_url_page('https://journal.example/reports/funding-records', html) do |page|
      root = File.expand_path('../../..', __dir__)
      source = File.readlines(File.join(root, 'websieve/manifest.txt'), chomp: true).reject(&:empty?).map do |entry|
        File.read(File.join(root, 'websieve', entry))
      end.join("\n")
      page.add_script_tag(content: source.sub('})(window);', 'global.selfLinkedTitleProbe = articleTitleFromSelfLinkedHeading; })(window);'))
      selected = "<article><h2><a href='/reports/another-story'>#{headline}</a></h2><p>Original article prose.</p></article>"
      title = "#{headline} | Regional research archive"

      expect(page.evaluate("selfLinkedTitleProbe(#{JSON.generate(selected)}, #{JSON.generate(title)})")).to eq(title)
    end
  end
end
