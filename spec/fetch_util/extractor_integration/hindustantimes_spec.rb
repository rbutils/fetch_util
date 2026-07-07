# frozen_string_literal: true

RSpec.describe 'FetchUtil Hindustan Times extractor integration' do
  include_context 'extractor integration helpers'

  it 'extracts Hindustan Times article bodies without topic-list or footer warnings' do
    expect_fixture_article(
      url: 'https://www.hindustantimes.com/opinion/hindi-and-its-role-in-the-unified-future-of-india-101726241382225.html',
      fixture_path: File.expand_path('../../fixtures/hindustantimes_article.html', __dir__),
      includes: [
        'Hindi Divas (Hindi Day), observed every year on September 14',
        'The forward march of Hindi has been impressive.'
      ],
      excludes: ['Hindi Language', 'SIGN UP TO SUBSCRIBE', 'Get Current Updates on', 'Prefer HT on Google'],
      warning_excludes: %w[multi_topic_page stale_content]
    )
  end
end
