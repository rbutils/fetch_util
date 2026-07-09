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
end
