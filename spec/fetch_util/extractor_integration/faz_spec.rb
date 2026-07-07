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
    expect_fixture_article(
      url: 'https://www.faz.net/aktuell/wirtschaft/unternehmen/tkms-kanadas-u-boot-milliardendeal-mit-deutschland-201005300.html',
      fixture_path: File.expand_path('../../fixtures/faz_article.html', __dir__),
      includes: ['Kanada hat sich entschieden. Mit dem deutschen Marinekonzern TKMS', 'Die Zeit bis zum Stapellauf läuft.'],
      excludes: ['MEHR ZUM THEMA'],
      warning_excludes: %w[multi_topic_page paywall_partial_content]
    )
  end
end
