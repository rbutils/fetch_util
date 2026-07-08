# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'FetchUtil extractor integration - truncated_content localized articles' do
  include_context 'extractor integration helpers'

  cases = [
    [
      'Dinakaran',
      'https://www.dinakaran.com/news/straitofhormuz-commercialships-iran-usa/',
      'ஹார்முஸ் நீரிணையில் 3 வர்த்தக கப்பல்கள் தாக்கப்பட்டதைக் கண்டித்து'
    ],
    [
      'Klix',
      'https://www.klix.ba/sport/nogomet/poznati-su-svi-parovi-cetvrtfinala-svjetskog-prvenstva-evo-kada-se-igraju-utakmice/260707205',
      'U preostalim duelima sastaju se Francuska i Maroko'
    ],
    [
      'APA football',
      'https://apa.az/football/fifa-rusiya-komandalarina-tetbiq-olunan-sanksiyalarin-legvini-muzakire-edecek-979466',
      'Beynəlxalq Futbol Federasiyası (FIFA)'
    ],
    [
      'APA social',
      'https://apa.az/social/xocavend-ve-susaya-novbeti-koc-karvani-yola-salinib-foto-979468',
      'Prezident İlham Əliyevin tapşırığına uyğun olaraq'
    ],
    [
      'Sakshi',
      'https://www.sakshi.com/telugu-news/international/us-charges-lawrence-bishnoi-goldy-brar-nijjar-assassination-2837548',
      'లారెన్స్ బిష్ణోయ్'
    ]
  ]

  cases.each do |name, url, expected_snippet|
    it "does not flag truncated_content for #{name}" do
      payload = FetchUtil.fetch(url, timeout: 35).to_h

      expect(payload[:content_type]).to eq('article')
      expect(payload[:warnings]).not_to include('truncated_content')
      expect(payload[:markdown]).to include(expected_snippet)
    end
  end
end
