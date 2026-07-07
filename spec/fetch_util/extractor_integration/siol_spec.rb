# frozen_string_literal: true

RSpec.describe 'FetchUtil Siol extractor integration' do
  include_context 'extractor integration helpers'

  it 'extracts Siol article bodies without stale content warnings' do
    expect_fixture_article(
      url: 'https://siol.net/novice/slovenija/ljubljanska-zelezniska-postaja-v-sklepni-fazi-prenove-kaj-prinasajo-rekordne-nalozbe-v-promet-683781',
      fixture_path: File.expand_path('../fixtures/siol_article.html', __dir__),
      includes: [
        'Ljubljanska železniška postaja v sklepni fazi prenove',
        'Nova ljubljanska potniška postaja je načrtovana tako',
        'Državni prostorski načrt bo potreben samo za širitev dolenjske avtocestne vpadnice'
      ],
      excludes: ['Kaj berete', 'Zadnje objave'],
      warning_excludes: %w[empty_extraction short_extraction url_content_mismatch consent_interstitial]
    )
  end
end
