# frozen_string_literal: true

RSpec.describe 'FetchUtil Maroela Media extractor integration' do
  include_context 'extractor integration helpers'

  it 'extracts Maroela Media article bodies without the closed-comments footer note' do
    expect_fixture_article(
      url: 'https://www.maroelamedia.co.za/nuus/sa-nuus/eskom-verwelkom-hofbevel-wat-trillian-dwing-om-miljoene-terug-te-betaal',
      fixture_path: File.expand_path('../fixtures/maroelamedia_article.html', __dir__),
      includes: [
        '# Eskom verwelkom hofbevel wat Trillian dwing om miljoene terug te betaal',
        'Eskom het ŉ hofbeslissing verwelkom wat die konsultantefirma Trillian Capital beveel'
      ],
      excludes: ['O wee, die gesang is uit!', '- Maroela Media'],
      warning_excludes: %w[empty_extraction short_extraction url_content_mismatch consent_interstitial]
    )
  end
end
