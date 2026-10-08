# frozen_string_literal: true

require 'nokogiri'

RSpec.describe 'FetchUtil To Vima extractor integration' do
  include_context 'extractor integration helpers'

  it 'extracts To Vima article bodies without Google preferred-source chrome' do
    expect_fixture_article(
      url: 'https://www.tovima.gr/2026/07/07/world/i-nea-eksisosi-sto-nato-eyropaiki-aytonomia-amerikanikes-pieseis-kai-o-rolos-tis-tourkias/',
      fixture_path: File.expand_path('../../fixtures/tovima_gr_article.html', __dir__),
      includes: [
        'Καθώς οι ηγέτες των χωρών του ΝΑΤΟ καταφτάνουν στην Άγκυρα',
        'Οι ευρωπαϊκές πρωτεύουσες αναζητούν κοινές λύσεις χρηματοδότησης'
      ],
      excludes: ['Κάντε TO BHMA προτιμώμενη πηγή', 'google-preferred-source', 'googletag.cmd.push'],
      warning_excludes: %w[empty_extraction short_extraction url_content_mismatch consent_interstitial]
    )
  end

  it 'preserves every reporting paragraph and the original page after shared cleanup' do
    html = fixture_contents(File.expand_path('../../fixtures/tovima_gr_article.html', __dir__))
    paragraphs = Nokogiri::HTML(html, nil, 'UTF-8').css('article > p').map(&:text)
    with_url_page('https://www.tovima.gr/world/report/', html) do |page|
      before = page.evaluate('document.body.innerHTML')
      payload = extract_payload(page)
      expect(Nokogiri::HTML.fragment(payload.fetch('html')).css('p').map(&:text)).to eq(paragraphs)
      offsets = paragraphs.map { |text| payload.fetch('markdown').index(text) }
      expect(offsets).not_to include(nil)
      expect(offsets).to eq(offsets.sort)
      expect(payload['markdown']).not_to include('προτιμώμενη πηγή', 'googletag')
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end

  it 'recognizes a generic preference action without deleting authored or linked same-class content' do
    ['Make Example Journal your preferred source on Google', 'Κάντε Example Journal προτιμώμενη πηγή'].each do |prompt|
      html = <<~HTML
        <html><head><title>How source preferences work</title></head><body><article id="report">
          <h1>How source preferences work</h1>
          <p>This authored report explains how readers select sources while retaining the context and evidence for those decisions.</p>
          <p>The second reporting paragraph describes an independent experiment and the observations that support its conclusion.</p>
          <p>The final reporting paragraph links to <a href="/research">the source research</a> for a reproducible account of the results.</p>
          <div class="publisher-preferred-source">#{prompt}</div>
          <p class="publisher-preferred-source">#{prompt} is the literal wording examined in this reporting paragraph.</p>
          <blockquote><div class="publisher-preferred-source">#{prompt}</div></blockquote>
          <a class="publisher-preferred-source" href="/preferences">The preference study</a>
          <pre class="publisher-preferred-source">#{prompt}</pre>
        </article></body></html>
      HTML
      extract_from_url('https://independent-journal.test/research/report', html) do |payload|
        document = Nokogiri::HTML.fragment(payload.fetch('html'))
        controls = document.css('div, section').select do |node|
          node.element_children.empty? && node.text.strip == prompt && node.ancestors.none? { |parent| %w[blockquote pre code].include?(parent.name) }
        end
        expect(controls).to be_empty
        expect(document.css('p').map(&:text)).to include("#{prompt} is the literal wording examined in this reporting paragraph."), payload.fetch('html')
        expect(document.at_css('blockquote').text).to include(prompt)
        expect(document.at_css('pre').text).to eq(prompt)
        expect(document.css('a[href]').map { |link| link['href'] }).to eq(['https://independent-journal.test/research', 'https://independent-journal.test/preferences'])
      end
    end
  end
end
