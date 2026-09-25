# frozen_string_literal: true

RSpec.describe 'FetchUtil Markdown player label boundaries' do
  include_context 'extractor integration helpers'

  it 'preserves duration in editorial prose and image labels while removing standalone player timing labels' do
    html = <<~HTML
      <html><head><title>How duration affects forecasts</title></head><body><main><article>
        <h1>How duration affects forecasts</h1>
        <p>Duration estimates explain how long the survey covered the river and why its timing matters for comparing measurements.</p>
        <p>The research team returned throughout the year to record changing water levels and identify which observations were consistent.</p>
        <p>Long duration samples captured more variation than short duration samples, providing the team with a clearer picture of seasonal changes.</p>
        <figure><img src="/chart.svg" alt="Short duration river chart"><figcaption>A comparison of survey duration.</figcaption></figure>
        <div>Duration 00:42</div><div>Duration --:--</div>
      </article></main></body></html>
    HTML

    extract_from_url('https://research.example/forecast', html) do |payload|
      expect(payload['markdown']).to include('Duration estimates explain', 'Long duration samples', 'short duration samples')
      expect(payload['markdown']).to include('![Short duration river chart](https://research.example/chart.svg)', 'A comparison of survey duration.')
      expect(payload['markdown']).not_to include('Duration 00:42', 'Duration --:--')
    end
  end
end
