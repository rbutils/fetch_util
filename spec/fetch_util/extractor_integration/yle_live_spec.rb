# frozen_string_literal: true

RSpec.describe 'FetchUtil Yle live extractor integration' do
  include_context 'extractor integration helpers'

  it 'preserves the complete parent when the source does not identify the requested update' do
    html = fixture_contents(File.expand_path('../../fixtures/yle_live_article.html', __dir__))

    extract_from_url('https://yle.fi/a/74-20235117/64-3-304362', html) do |payload|
      expect_content_type(payload, 'article')
      expect(payload['title']).to eq('Stubb: ”Meidän on tuettava Ukrainaa”')
      expect(payload['contentFormat']).to eq('liveblog')
      expect(payload['byline']).to be_nil
      expect(payload['publishedTime']).to be_nil
      [
        'Yle seuraa tiistaina alkavaa Nato-kokousta',
        'Trump on saapunut Ankaraan',
        'Yhdysvaltain presidentti Donald Trump on saapunut Turkin pääkaupunkiin Ankaraan',
        'Trump asteli juuri alas lentokoneestaan',
        'Trumpin ja Ukrainan presidentin Volodymyr Zelenskyin',
        'rauha Ukrainassa on lähempänä', 'Lähde: Reuters', 'Jani Parkkari',
        'Rutte: Naton ja EU:n tiivistettävä yhteistyötä',
        'Sotilasliitto Naton ja Euroopan unionin on tiivistettävä yhteistyötä'
      ].each { |text| expect(payload['markdown']).to include(text) }
      expect(payload['markdown'].index('Trump on saapunut Ankaraan')).to be < payload['markdown'].index('Rutte: Naton')
      expect(payload['markdown']).not_to include('Sulje')
      expect_warnings(payload, include: ['multi_topic_page'], exclude: %w[empty_extraction short_extraction url_content_mismatch consent_interstitial])
    end
  end
end
