# frozen_string_literal: true

RSpec.describe 'FetchUtil extractor integration' do
  include_context 'extractor integration helpers'

  it 'extracts Telex article bodies without share, toast, weather, or audio chrome' do
    html = File.read(File.expand_path('../../fixtures/telex_article.html', __dir__))
    url = 'https://telex.hu/kulfold/2026/07/06/nato-csucs-ankara-trump-kozel-kelet-magyar-peter'

    extract_from_url(url, html) do |payload|
      expect(payload['contentType']).to eq('article')
      expect(payload['markdown']).to include('Az évente megrendezett NATO-csúcsok hosszú időn át')
      expect(payload['markdown']).to include('Politikai konfliktusok árnyékában')
      expect(payload['markdown']).not_to include('Hozzáadva a lejátszási listához')
      expect(payload['markdown']).not_to include('Vágólapra másolva')
      expect(payload['markdown']).not_to include('Megosztás')
      expect(payload['markdown']).not_to include('Budapest 27 C')
      expect(payload['markdown']).not_to include('Egy könyv, amit bárhová magaddal vihetsz')
      expect(payload['markdown']).not_to include('Kedvenceink')
      expect(payload['warnings']).not_to include('empty_extraction')
      expect(payload['warnings']).not_to include('short_extraction')
      expect(payload['warnings']).not_to include('url_content_mismatch')
      expect(payload['warnings']).not_to include('consent_interstitial')
    end
  end
end
