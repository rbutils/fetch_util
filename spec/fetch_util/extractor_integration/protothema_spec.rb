# frozen_string_literal: true

RSpec.describe 'FetchUtil Protothema extractor integration' do
  include_context 'extractor integration helpers'

  it 'extracts Protothema article bodies from the main section without false truncation warnings' do
    expect_fixture_article(
      url: 'https://www.protothema.gr/greece/article/1847263/seismos-39-rihter-koda-stin-kissamo-hanion/',
      fixture_path: File.expand_path('../../fixtures/protothema_article.html', __dir__),
      includes: [
        'Σεισμός 3,9 Ρίχτερ κοντά στην Κίσσαμο Χανίων',
        'Ο σεισμός σημειώθηκε στις 01:18 μετά τα μεσάνυχτα της Τρίτης'
      ],
      excludes: [
        'ΤΑ ΠΙΟ ΔΗΜΟΦΙΛΗ',
        'Games',
        'Άλλο άρθρο δοκιμής'
      ],
      warning_excludes: %w[empty_extraction short_extraction truncated_content url_content_mismatch consent_interstitial]
    )
  end
end
