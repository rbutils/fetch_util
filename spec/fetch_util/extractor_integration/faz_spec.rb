# frozen_string_literal: true

RSpec.describe 'FetchUtil extractor integration' do
  include_context 'extractor integration helpers'

  it 'classifies the FAZ homepage as a story list' do
    html = File.read(File.expand_path('../../fixtures/faz_homepage.html', __dir__))

    extract_from_url('https://www.faz.net/', html) do |payload|
      expect(payload['contentType']).to eq('list')
      expect(payload['markdown']).to include('Kernstück der gemeinsamen Verteidigung')
      expect(payload['markdown']).to include('TKMS bekommt Zuschlag für Milliarden-Auftrag aus Kanada')
      expect(payload['warnings']).to be_empty
    end
  end

  it 'extracts public FAZ article bodies without false list or paywall warnings' do
    html = File.read(File.expand_path('../../fixtures/faz_article.html', __dir__))
    url = 'https://www.faz.net/aktuell/wirtschaft/unternehmen/tkms-kanadas-u-boot-milliardendeal-mit-deutschland-201005300.html'

    extract_from_url(url, html) do |payload|
      expect(payload['contentType']).to eq('article')
      expect(payload['markdown']).to include('Kanada hat sich entschieden. Mit dem deutschen Marinekonzern TKMS')
      expect(payload['markdown']).to include('Die Zeit bis zum Stapellauf läuft.')
      expect(payload['markdown']).not_to include('MEHR ZUM THEMA')
      expect(payload['warnings']).not_to include('multi_topic_page')
      expect(payload['warnings']).not_to include('paywall_partial_content')
    end
  end
end
