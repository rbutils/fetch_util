# frozen_string_literal: true

require 'nokogiri'

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

    path = File.expand_path('../../fixtures/oxu_article.html', __dir__)
    source = Nokogiri::HTML(File.read(path))
    extract_from_url('https://oxu.az/dunya/alyaskada-yoxa-cixan-teyyareden-xeber-var', File.read(path)) do |payload|
      output = Nokogiri::HTML.fragment(payload.fetch('html'))
      paragraphs = source.css('.post-detail-content-inner p').map(&:text)
      expect(output.css('p').map(&:text)).to include(*paragraphs)
      expect(output.css('img').map { |image| [image['src'], image['alt']] }).to include(
        [source.at_css('.post-detail-img img')['src'], source.at_css('h1').text]
      )
      expect(payload.fetch('markdown')).to include('08 fevral, 2025 / 09:22', '[Alyaska](https://oxu.az/tag/alyaska)')
      expect(payload.fetch('markdown')).not_to include('Xəbər maraqlı gəlib?', 'facebook.com/sharer')
      expect(payload['publishedTime']).to be_nil
    end
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
      expect(payload['markdown']).to include('21 September 2026')
      expect(payload['markdown']).not_to include('oxu.az/1078092')
      expect(payload['html']).not_to include('oxu.az/1078092')
      expect(payload['textContent']).not_to include('Xəbər maraqlı gəlib?')
    end
  end

  it 'recovers only physically owned visible lead context on an independent host' do
    title = 'A source-owned regional report'
    body = <<~HTML
      <main>
        <div><img src="/lead.jpg" alt="#{title}"><img src="/unrelated.jpg" alt="Another report"></div>
        <img src="/hidden.jpg" alt="#{title}" hidden>
        <header><h1>#{title}</h1></header>
        <div>7 October 2026</div>
        <article>
          <p>The regional report records how the transport authority assessed the consultation and the independently published source evidence.</p>
          <p>The next section explains the changes that residents proposed and the safeguards adopted by the participating officials.</p>
          <p>The final paragraph retains an authored <a href="/reference">source reference</a> and records the next public review.</p>
        </article>
        <div><a rel="tag" href="/topics/transport">Transport policy</a></div>
        <aside><img src="/foreign.jpg" alt="#{title}"><a rel="tag" href="/topics/foreign">Foreign topic</a></aside>
      </main>
    HTML
    extract_from_url('https://regional.example/reports/consultation', body) do |payload|
      output = Nokogiri::HTML.fragment(payload.fetch('html'))
      expect(output.css('img').map { |image| image['src'] }).to eq(['https://regional.example/lead.jpg'])
      expect(payload.fetch('markdown')).to include('7 October 2026', '[Transport policy](https://regional.example/topics/transport)', '[source reference](https://regional.example/reference)')
      expect(payload.fetch('markdown')).not_to include('Foreign topic')
      expect(payload['publishedTime']).to be_nil
    end
  end
end
