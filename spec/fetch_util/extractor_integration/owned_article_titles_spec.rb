# frozen_string_literal: true

RSpec.describe 'Owned article titles' do
  include_context 'extractor integration helpers'

  it 'prefers the selected article heading over an appended publication name' do
    html = <<~HTML
      <html><head><title>Research across borders - Journal.example</title>
      <meta property="og:site_name" content="www.journal.example"></head><body>
      <article><h1>Research across borders</h1>
      <p>Researchers compared independent measurements from several regions and documented the evidence behind each conclusion. Their report describes the practical limitations and the complete methodology.</p>
      <h2>Supporting evidence</h2><p>The investigators also published a <a href="/data">public dataset</a> so others can reproduce the analysis. These independent records remain important when interpreting the observations.</p></article>
      </body></html>
    HTML
    with_url_page('https://journal.example/reports/borders', html) do |page|
      result = FetchUtil::Extractor.new(reader_mode: false).extract(page)
      expect(result['title']).to eq('Research across borders')
      expect(result['markdown']).to start_with('# Research across borders')
      expect(result['markdown']).not_to include(' - Journal.example')
      expect(result['markdown']).to include('[public dataset](https://journal.example/data)')
    end
  end

  it 'preserves a genuine title extension that is not the publication name' do
    html = <<~HTML
      <html><head><title>Research across borders - A new method</title>
      <meta property="og:site_name" content="Journal.example"></head><body>
      <article><h1>Research across borders</h1>
      <p>Researchers compared independent measurements from several regions and documented the evidence behind each conclusion. Their report describes the practical limitations and the complete methodology.</p>
      <h2>Supporting evidence</h2><p>The investigators published independent records with additional context, including the assumptions and the measurements used to reproduce their careful analysis.</p></article>
      </body></html>
    HTML
    with_url_page('https://journal.example/reports/method', html) do |page|
      result = FetchUtil::Extractor.new(reader_mode: false).extract(page)
      expect(result['title']).to eq('Research across borders - A new method')
      expect(result['markdown']).to include('A new method')
    end
  end

  it 'does not leave an enrichment-generated publication suffix as article prose' do
    html = <<~HTML
      <html><head><title>League match review - Sports.example</title>
      <meta property="og:site_name" content="Sports.example"></head><body>
      <article><h1>League match review</h1><p>North Club played South Club in the league competition. The complete match report describes the players, the decisive moments, and the tactical choices made by each manager throughout the game.</p>
      <table><tr><th>Team</th><th>Score</th></tr><tr><td>North Club</td><td>2</td></tr><tr><td>South Club</td><td>1</td></tr></table>
      <h2>Post-match analysis</h2><p>The independent analysis considers the evidence in detail and explains the key differences between the teams. All observations and qualifications remain part of the article.</p></article></body></html>
    HTML
    with_url_page('https://sports.example/sport/league-match', html) do |page|
      result = FetchUtil::Extractor.new(reader_mode: false).extract(page)
      expect(result['title']).to eq('League match review')
      expect(result['markdown'].scan(/^# League match review$/).length).to eq(1)
      expect(result['markdown']).not_to include(' - Sports.example', "\n- Sports.example")
      expect(result['markdown']).to include('Post-match analysis', 'North Club')
    end
  end
end
