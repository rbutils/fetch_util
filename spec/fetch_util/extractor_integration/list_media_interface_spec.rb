# frozen_string_literal: true

RSpec.describe 'FetchUtil list descriptions around media interfaces' do
  include_context 'extractor integration helpers'

  it 'excludes a player announcement while preserving authored explanations and uncarded records' do
    html = <<~HTML
      <html><head><title>Regional records</title></head><body><main>
        <h1>Regional records</h1>
        <div class="vjs-modal-dialog-content">Seek to live, currently behind liveLIVE Beginning of dialog window. Escape will cancel and close the window.</div>
        <div class="vjs-modal-dialog-content">The investigation explains why player announcements interrupt access to public records.</div>
        <p>The phrase “Seek to live” identifies a player action, not part of the following reports.</p>
        <article><h2><a href="/reports/water">New public water-quality measurements released</a></h2></article>
        <article><h2><a href="/reports/buses">Bus operator publishes revised arrival records</a></h2></article>
        <article><h2><a href="/reports/budget">Council publishes the complete annual budget</a></h2></article>
        <article><h2><a href="/reports/parks">Public park survey includes the original measurements</a></h2></article>
        <div><a href="/notices/hearing">PUBLIC NOTICE OF THE NEXT DISTRICT HEARING</a></div>
      </main></body></html>
    HTML

    with_url_page('https://records.example/', html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload['markdown']).not_to include('Beginning of dialog window', 'Escape will cancel')
      expect(payload['markdown']).to include(
        'The investigation explains why player announcements interrupt access to public records.',
        'The phrase “Seek to live” identifies a player action', 'PUBLIC NOTICE OF THE NEXT DISTRICT HEARING'
      )
      destinations = %w[reports/water reports/buses reports/budget reports/parks notices/hearing]
      positions = destinations.map do |path|
        url = "https://records.example/#{path}"
        expect(payload['markdown']).to include(url)
        payload['markdown'].index(url)
      end
      expect(positions).to eq(positions.sort)
    end
  end
end
