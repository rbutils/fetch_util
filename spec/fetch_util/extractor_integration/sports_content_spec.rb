# frozen_string_literal: true

RSpec.describe 'FetchUtil sports content extraction' do
  include_context 'extractor integration helpers'

  it 'classifies ESPN game pages as sports events and preserves box score tables without nav' do
    html = fixture_contents('spec/fixtures/sports_espn_game.html')

    with_url_page('https://www.espn.com/nba/game/_/gameId/401765432/knicks-celtics', html) do |page|
      payload = extract_payload(page)
      expect_content_type(payload, 'sports_event')
      expect(payload['markdown']).to include('Score: New York Knicks 91, Boston Celtics 85')
      expect(payload['markdown']).to include('| Player | MIN | PTS | REB | AST |')
      expect(payload['markdown']).to include('| Jalen Brunson | 39 | 28 | 4 | 7 |')
      expect(payload['markdown']).not_to include('Fantasy More Sports Betting Tickets')
      expect_warnings(payload, exclude: %w[short_extraction multi_topic_page])
    end
  end

  it 'keeps BBC Sport article body and embedded match tables' do
    html = fixture_contents('spec/fixtures/sports_bbc_article.html')

    with_url_page('https://www.bbc.com/sport/football/76543210', html) do |page|
      payload = extract_payload(page)

      expect_content_type(payload, 'article')
      expect(payload['markdown']).to include('Northbridge finished the fixture ahead')
      expect(payload['markdown']).to include('| Team | Goals | Shots | Possession |')
      expect(payload['markdown']).not_to include('Worklife Travel Future Culture')
    end
  end

  it 'keeps Sky Sports match reports as articles when they lack match-detail evidence' do
    html = fixture_contents('spec/fixtures/sports_sky_article.html')

    with_url_page('https://www.skysports.com/football/news/11670/12345678/arsenal-chelsea-report', html) do |page|
      payload = extract_payload(page)

      expect_content_type(payload, 'article')
      expect(payload['markdown']).to include('Harbor FC finished ahead of Riverside')
      expect(payload['markdown']).to include('Score: Full-timeHarbor FC 3 Riverside 2')
      expect(payload['markdown']).not_to include('Transfer Centre Watch')
    end
  end

  it 'keeps Goal.com article body and player-rating tables' do
    html = fixture_contents('spec/fixtures/sports_goal_article.html')

    with_url_page('https://www.goal.com/en/news/usmnt-player-ratings-pulisic/blt1234567890', html) do |page|
      payload = extract_payload(page)

      expect_content_type(payload, 'article')
      expect(payload['markdown']).to include('Jordan Vale scored once')
      expect(payload['markdown']).to include('| Player | Goals | Assists | Rating |')
      expect(payload['markdown']).not_to include('News Matches Tables Betting NXGN Transfers')
    end
  end

  it 'keeps NBA.com news article body and embedded stat table' do
    html = fixture_contents('spec/fixtures/sports_nba_news.html')

    with_url_page('https://www.nba.com/news/thunder-rally-force-game-7', html) do |page|
      payload = extract_payload(page)

      expect_content_type(payload, 'article')
      expect(payload['markdown']).to include('Comets removed a double-digit gap')
      expect(payload['markdown']).to include('| Team | PTS | REB | AST |')
      expect(payload['markdown']).not_to include('Games Schedule Watch News Teams Players Stats Standings')
    end
  end

  it 'preserves relevant tables beyond the former row cap' do
    html = fixture_contents('spec/fixtures/sports_table_over_cap.html')

    with_url_page('https://sports.example/college-basketball/stats', html) do |page|
      payload = extract_payload(page)

      expect_content_type(payload, 'article')
      expect(payload['markdown']).to include('| Player | Team | PTS | REB |', '| Player 82 | Team 82 | 92 | 85 |')
      expect(payload['markdown'].index('| Player 1 |')).to be < payload['markdown'].index('| Player 82 |')
    end
  end

  it 'preserves relevant tables whose normalized text exceeds 10000 characters' do
    html = fixture_contents('spec/fixtures/sports_table_over_cap.html')
    rows = (83..180).map do |index|
      description = "Player #{index} made a sustained contribution across the full basketball season " \
                    "with detailed defensive and offensive statistics recorded for this game."
      "<tr><td>Player #{index}</td><td>Team #{index}</td><td>#{index + 10}</td><td>#{index + 3}</td><td>#{description}</td></tr>"
    end.join
    html = html.sub('</tbody>', "#{rows}</tbody>")

    with_url_page('https://sports.example/college-basketball/stats', html) do |page|
      payload = extract_payload(page)

      expect(html.gsub(/<[^>]+>/, ' ').gsub(/\s+/, ' ').length).to be > 10_000
      expect(payload['markdown']).to include('| Player 180 | Team 180 | 190 | 183 |')
      expect(payload['markdown'].index('| Player 1 |')).to be < payload['markdown'].index('| Player 180 |')
    end
  end

  it 'does not classify a large unrelated table as sports' do
    rows = (1..82).map do |index|
      "<tr><td>Entry #{index}</td><td>2026-07-#{format("%02d", (index % 28) + 1)}</td><td>Archive</td></tr>"
    end.join
    html = <<~HTML
      <html><head><title>Public archive index</title></head><body><main>
        <h1>Public archive index</h1>
        <table><thead><tr><th>Name</th><th>Date</th><th>Location</th></tr></thead>
          <tbody>#{rows}</tbody>
        </table>
      </main></body></html>
    HTML

    with_url_page('https://example.test/archive', html) do |page|
      payload = extract_payload(page)

      expect(payload['contentType']).not_to eq('sports_event')
      expect(payload['contentType']).not_to eq('sports')
    end
  end

  it 'classifies schema-less match detail from reusable score and team-stat evidence' do
    html = <<~HTML
      <html><head><title>Patriots 13, Seahawks 16</title></head><body><main>
        <h1>Patriots vs Seahawks</h1><div class="scoreboard">Patriots 13 Seahawks 16</div>
        <table><thead><tr><th>Team</th><th>PTS</th><th>YDS</th></tr></thead><tbody><tr><td>Patriots</td><td>13</td><td>281</td></tr><tr><td>Seahawks</td><td>16</td><td>312</td></tr></tbody></table>
      </main></body></html>
    HTML

    with_url_page('https://scores.example/matches/patriots-seahawks', html) do |page|
      payload = extract_payload(page)

      expect_content_type(payload, 'sports_event')
      expect(payload['markdown']).to include('Score: Patriots 13 Seahawks 16')
      expect(payload['markdown']).to include('| Team | PTS | YDS |')
    end
  end

  it 'classifies cross-host schema-less match detail from score and stat tables' do
    html = <<~HTML
      <html><head><title>Raptors 101, Comets 98</title></head><body><main>
        <h1>Raptors 101, Comets 98</h1><p class="result">Final</p>
        <table><thead><tr><th>Team</th><th>PTS</th><th>REB</th><th>AST</th></tr></thead><tbody><tr><td>Raptors</td><td>101</td><td>42</td><td>24</td></tr><tr><td>Comets</td><td>98</td><td>39</td><td>21</td></tr></tbody></table>
      </main></body></html>
    HTML

    with_url_page('https://results.test/basketball/raptors-comets', html) do |page|
      payload = extract_payload(page)

      expect_content_type(payload, 'sports_event')
      expect(payload['markdown']).to include('| Team | PTS | REB | AST |')
    end
  end

  it 'keeps ordinary sports articles with an uncorroborated score as articles' do
    html = <<~HTML
      <html><head><title>Football report: Harbor FC 2, City United 1</title></head><body><main><article>
        <h1>Harbor FC rally seals a dramatic win</h1><p>Harbor FC 2 City United 1 was the final score after a late goal.</p>
        <p>The manager said the match changed after half-time and praised the travelling supporters.</p>
        <table><thead><tr><th>Player</th><th>PTS</th></tr></thead><tbody><tr><td>Jordan Lee</td><td>8</td></tr><tr><td>Riley Chen</td><td>6</td></tr></tbody></table>
      </article></main></body></html>
    HTML

    with_url_page('https://news.example/football/harbor-report', html) do |page|
      expect_content_type(extract_payload(page), 'article')
    end
  end

  it 'keeps an article ordinary when its score and two-label player table are unrelated' do
    html = <<~HTML
      <html><head><title>Match report and player reaction</title></head><body><main>
        <article>
          <h1>Match report and player reaction</h1>
          <p class="scoreboard">Harbor FC 2, City United 1</p>
          <p>The late goal decided the match, while the feature explains the season and the manager's reaction.</p>
          <table class="player-stats"><thead><tr><th>Player</th><th>PTS</th><th>REB</th></tr></thead>
            <tbody><tr><td>Jordan Lee</td><td>8</td><td>6</td></tr><tr><td>Riley Chen</td><td>7</td><td>5</td></tr></tbody>
          </table>
        </article>
      </main></body></html>
    HTML

    with_url_page('https://news.example/football/harbor-reaction', html) do |page|
      payload = extract_payload(page)

      expect(payload['contentType']).to eq('article')
      expect(payload['sportsDetailEvidence']).to be_nil
    end
  end

  it 'does not treat betting or navigation tables as match-detail evidence' do
    html = <<~HTML
      <html><head><title>Football betting odds</title></head><body>
        <nav><table><thead><tr><th>Team</th><th>PTS</th></tr></thead><tbody><tr><td>Harbor FC</td><td>13</td></tr><tr><td>City United</td><td>16</td></tr></tbody></table></nav>
        <main><h1>Football betting odds</h1><div class="scoreboard">Harbor FC 13 City United 16</div>
          <table><thead><tr><th>Team</th><th>Odds</th><th>Handicap</th></tr></thead><tbody><tr><td>Harbor FC</td><td>2.10</td><td>+3</td></tr><tr><td>City United</td><td>1.75</td><td>-3</td></tr></tbody></table>
        </main></body></html>
    HTML

    with_url_page('https://betting.example/football/harbor-city', html) do |page|
      payload = extract_payload(page)

      expect(payload['contentType']).not_to eq('sports_event')
      expect(payload['contentType']).not_to eq('sports')
    end
  end

  it 'classifies an abbreviated-team score table on an unrelated host' do
    html = <<~HTML
      <html><head><title>New York Knicks 101 - Boston Celtics 98</title></head><body><main>
          <h1>New York Knicks 101 - Boston Celtics 98</h1><div class="scoreboard">New York Knicks 101 - Boston Celtics 98</div>
          <table><thead><tr><th>Team</th><th>PTS</th><th>REB</th><th>AST</th></tr></thead>
            <tbody><tr><td>NYK</td><td>101</td><td>44</td><td>25</td></tr><tr><td>BOS</td><td>98</td><td>40</td><td>22</td></tr></tbody>
          </table>
        </main></body></html>
    HTML

    with_url_page('https://scores.other.example/box/knicks-celtics', html) do |page|
      payload = extract_payload(page)
      expect_content_type(payload, 'sports_event')
      expect(payload['sportsDetailEvidence']).to include('kind' => 'sports_detail', 'urlMatch' => 'consistent')
      expect(payload['markdown']).to include('| Team | PTS | REB | AST |', '| NYK | 101 | 44 | 25 |')
    end
  end

  it 'classifies an opaque game identifier without using the identifier as team evidence' do
    html = <<~HTML
      <html><head><title>Raptors 101, Comets 98</title></head><body><main>
        <h1>Raptors 101, Comets 98</h1><div class="scoreboard">Raptors 101, Comets 98</div>
        <table><thead><tr><th>Team</th><th>PTS</th><th>REB</th></tr></thead>
          <tbody><tr><td>Raptors</td><td>101</td><td>42</td></tr><tr><td>Comets</td><td>98</td><td>39</td></tr></tbody>
        </table>
      </main></body></html>
    HTML

    with_url_page('https://opaque.example/game/401765432', html) do |page|
      payload = extract_payload(page)

      expect_content_type(payload, 'sports_event')
      expect(payload['sportsDetailEvidence']).to include('urlMatch' => 'opaque')
      expect(payload['warnings']).not_to include('url_content_mismatch')
    end
  end

  it 'keeps a semantically mismatched named game truthful' do
    html = <<~HTML
      <html><head><title>Knicks 101, Celtics 98</title></head><body><main>
        <h1>Knicks 101, Celtics 98</h1><div class="scoreboard">Knicks 101, Celtics 98</div>
        <table><thead><tr><th>Team</th><th>PTS</th><th>REB</th></tr></thead>
          <tbody><tr><td>Knicks</td><td>101</td><td>42</td></tr><tr><td>Celtics</td><td>98</td><td>39</td></tr></tbody>
        </table>
      </main></body></html>
    HTML

    with_url_page('https://scores.example/game/lakers-heat', html) do |page|
      payload = extract_payload(page)

      expect_content_type(payload, 'sports_event')
      expect(payload['sportsDetailEvidence']).to include('urlMatch' => 'mismatch')
      expect(payload['warnings']).to include('url_content_mismatch')
    end
  end

  it 'does not classify standings tables as sports events' do
    html = <<~HTML
      <html><head><title>Football standings</title></head><body><main>
        <h1>Football standings</h1>
        <table><thead><tr><th>Team</th><th>Played</th><th>Points</th><th>Rank</th></tr></thead>
          <tbody><tr><td>Harbor FC</td><td>13</td><td>31</td><td>1</td></tr><tr><td>City United</td><td>13</td><td>28</td><td>2</td></tr></tbody>
        </table>
      </main></body></html>
    HTML

    with_url_page('https://league.example/football/standings', html) do |page|
      payload = extract_payload(page)

      expect(payload['contentType']).not_to eq('sports_event')
    end
  end

  it 'does not classify search result tables as sports events' do
    html = <<~HTML
      <html><head><title>Search results for basketball</title></head><body><main>
        <h1>Search results for basketball</h1>
        <table><thead><tr><th>Result</th><th>Score</th><th>Link</th></tr></thead>
          <tbody><tr><td>Knicks Celtics preview</td><td>101 - 98</td><td>Open</td></tr><tr><td>League news</td><td>88 - 82</td><td>Open</td></tr></tbody>
        </table>
      </main></body></html>
    HTML

    with_url_page('https://search.example/search?q=knicks+celtics', html) do |page|
      payload = extract_payload(page)

      expect(payload['contentType']).not_to eq('sports_event')
      expect(payload['contentType']).not_to eq('sports')
    end
  end
end
