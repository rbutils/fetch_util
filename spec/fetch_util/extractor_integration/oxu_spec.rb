# frozen_string_literal: true

RSpec.describe 'FetchUtil Oxu extractor integration' do
  include_context 'extractor integration helpers'

  it 'extracts Oxu article bodies from the post-detail layout without false truncation or stale warnings' do
    expect_fixture_article(
      url: 'https://oxu.az/dunya/alyaskada-yoxa-cixan-teyyareden-xeber-var',
      fixture_path: File.expand_path('../../fixtures/oxu_article.html', __dir__),
      includes: [
        'Dünən Alyaskada radarların ekranından itən',
        'hava gəmisinin göyərtəsində olanların hamısı həlak olub',
        'Xatırladaq ki, "Cessna 208B Grand Caravan"'
      ],
      excludes: ['A-', 'A+'],
      warning_excludes: %w[empty_extraction short_extraction url_content_mismatch consent_interstitial truncated_content]
    )
  end

  it 'does not fabricate a share destination from another article' do
    body = <<~HTML
      <main class="post-detail">
        <header class="post-detail-title"><h1>Independent regional report</h1></header>
        <div class="post-detail-meta">21 September 2026</div>
        <div class="post-detail-content-inner">
          <p>This independent regional report contains detailed source material about local transport planning, public consultation, and the decisions recorded by participating officials.</p>
          <p>Residents described how the revised schedule would affect schools, workplaces, and community services while the authority published the supporting evidence.</p>
          <p>The final section records the next review date and the safeguards that will keep the public process open to every affected neighborhood.</p>
        </div>
      </main>
    HTML

    extract_from_url('https://oxu.az/dunya/independent-report', body) do |payload|
      expect(payload['markdown']).to include('This independent regional report contains detailed source material')
      expect(payload['markdown']).not_to include('oxu.az/1078092')
      expect(payload['html']).not_to include('oxu.az/1078092')
      expect(payload['textContent']).not_to include('Xəbər maraqlı gəlib?')
    end
  end
end
