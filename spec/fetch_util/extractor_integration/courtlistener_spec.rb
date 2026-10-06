# frozen_string_literal: true

RSpec.describe 'FetchUtil CourtListener extraction' do
  include_context 'extractor integration helpers'

  it 'extracts a court opinion as an article instead of a link list' do
    expect_fixture_article(
      url: 'https://www.courtlistener.com/opinion/111503/brown-v-board-of-education/',
      fixture_path: File.expand_path('../../fixtures/courtlistener_opinion.html', __dir__),
      includes: [
        'Brown v. Board of Education',
        'MR. CHIEF JUSTICE WARREN delivered the opinion of the Court.',
        'Separate educational facilities are inherently unequal.',
        'The judgment of the court below is reversed'
      ],
      excludes: ['Download PDF', 'Cited by 1000'],
      warning_excludes: %w[short_extraction truncated_content multi_topic_page]
    )
  end

  def contributor_opinion_html(contributors:, declared_author: '')
    paragraphs = (1..4).map do |index|
      "<p>Owned judgment paragraph #{index} #{"with the complete legal analysis and factual context " * 4}</p>"
    end.join
    <<~HTML
      <html><head><title>Independent judicial opinion</title>#{declared_author}</head><body><main>
      <article><header><h1>Independent judicial opinion</h1>#{contributors}</header>
      <div><p class="citation-links">123 F. 456 | Download PDF | Cited by 12</p>#{paragraphs}
      <p class="citation-links">The authored reasoning discusses Download PDF | Cited by 12 as an example of interface wording, not as navigation.</p>
      <p>Compare the authored <a href="/precedent/123">precedent citation</a> with the facts stated above.</p></div></article>
      </main></body></html>
    HTML
  end

  it 'recovers a focal contributor and preserves authored citation prose on an unknown host' do
    html = contributor_opinion_html(contributors: '<p class="judges">Opinion by Justice Morgan</p>')
    with_url_page('https://judicial-record.example/decisions/independent-opinion', html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)
      expect(payload).to include('contentType' => 'article', 'byline' => 'Opinion by Justice Morgan')
      markdown = payload.fetch('markdown')
      (1..4).each { |index| expect(markdown).to include("Owned judgment paragraph #{index}") }
      expect(markdown).to include('The authored reasoning discusses Download PDF | Cited by 12')
      expect(markdown).to include('[precedent citation](https://judicial-record.example/precedent/123)')
      expect(markdown).not_to include('123 F. 456 | Download PDF | Cited by 12')
      expect(payload.fetch('excerpt')).to start_with('Owned judgment paragraph 1')
    end
  end

  it 'keeps a declared author ahead of a secondary contributor' do
    html = contributor_opinion_html(
      contributors: '<p class="judges">Opinion by Justice Morgan</p>',
      declared_author: '<meta name="author" content="Declared author">'
    )
    with_url_page('https://judicial-record.example/decisions/declared-author', html) do |page|
      expect(FetchUtil::Extractor.new.extract(page)['byline']).to eq('Declared author')
    end
  end

  it 'does not choose arbitrarily between distinct focal contributors' do
    html = contributor_opinion_html(contributors: '<p class="judges">Opinion by Justice Morgan</p><p class="judges">Opinion by Justice Patel</p>')
    with_url_page('https://judicial-record.example/decisions/ambiguous-contributors', html) do |page|
      expect(FetchUtil::Extractor.new.extract(page)['byline']).to be_nil
    end
  end
end
