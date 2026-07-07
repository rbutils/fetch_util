# frozen_string_literal: true

RSpec.describe 'FetchUtil To Vima extractor integration' do
  include_context 'extractor integration helpers'

  it 'extracts To Vima article bodies without Google preferred-source chrome' do
    html = File.read(File.expand_path('../../fixtures/tovima_gr_article.html', __dir__))
    url = 'https://www.tovima.gr/2026/07/07/world/i-nea-eksisosi-sto-nato-eyropaiki-aytonomia-amerikanikes-pieseis-kai-o-rolos-tis-tourkias/'

    extract_from_url(url, html) do |payload|
      expect_content_type(payload, 'article')
      expect(payload['markdown']).to include('Καθώς οι ηγέτες των χωρών του ΝΑΤΟ καταφτάνουν στην Άγκυρα')
      expect(payload['markdown']).to include('Οι ευρωπαϊκές πρωτεύουσες αναζητούν κοινές λύσεις χρηματοδότησης')
      expect(payload['markdown']).not_to include('Κάντε TO BHMA προτιμώμενη πηγή')
      expect(payload['markdown']).not_to include('google-preferred-source')
      expect(payload['markdown']).not_to include('googletag.cmd.push')
      expect_warnings(payload, exclude: %w[empty_extraction short_extraction url_content_mismatch consent_interstitial])
      expect(payload['suspect']).to be(false)
    end
  end
end
