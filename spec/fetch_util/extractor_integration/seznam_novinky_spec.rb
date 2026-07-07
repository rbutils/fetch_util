# frozen_string_literal: true

RSpec.describe 'FetchUtil Seznam Novinky extractor integration' do
  include_context 'extractor integration helpers'

  it 'extracts Novinky article bodies without CMP or related chrome' do
    html = File.read(File.expand_path('../../fixtures/seznam_novinky_article.html', __dir__))
    url = 'https://www.novinky.cz/clanek/domaci-zemrel-namestek-ministryne-pro-mistni-rozvoj-endal-40586881'

    extract_from_url(url, html) do |payload|
      expect_content_type(payload, 'article')
      expect(payload['markdown']).to include('Ve věku 51 let zemřel náměstek ministryně')
      expect(payload['markdown']).to include('Byl to skvělý profesionál a nesmírně erudovaný člověk')
      expect(payload['markdown']).not_to include('Nastavení souhlasu s personalizací')
      expect(payload['markdown']).not_to include('Sdílet na Facebooku')
      expect(payload['markdown']).not_to include('Související témata')
      expect_warnings(payload, exclude: %w[empty_extraction short_extraction url_content_mismatch consent_interstitial])
      expect(payload['suspect']).to be(false)
    end
  end
end
