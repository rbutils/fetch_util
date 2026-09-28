# frozen_string_literal: true

RSpec.describe 'FetchUtil source-owned liveblog footer material' do
  include_context 'extractor integration helpers'

  def footer_variants_fixture
    fixture_contents(File.expand_path('../../../fixtures/liveblog_footer_ownership/footer-variants.html', __dir__))
  end

  it 'preserves each material footer owned by a validated update without promoting child metadata' do
    html = footer_variants_fixture

    with_url_page('https://wire.example/live/footer-attribution', html) do |page|
      payload = extract_payload(page)

      expect_content_type(payload, 'article')
      expect(payload['contentFormat']).to eq('liveblog')
      expect(payload['title']).to eq('Harbor operations live updates')
      expect(payload['publishedTime']).to be_nil
      expect(payload['byline']).to be_nil
      expect(payload['markdown']).to include(
        'Updated by Reporter Mira',
        'Attribution posted at 10:05 UTC',
        'For corrections, contact the harbor desk',
        'harbor-desk@example.test',
        'Updated by Reporter Rowan',
        'Attribution posted at 12:05 UTC'
      )
      expect(payload['markdown']).not_to include(
        'Foreign Contributor',
        'Foreign record timestamp',
        'Unrelated site footer with author and timestamp'
      )
    end
  end

  it 'keeps the author-only attribution in an addressed update body' do
    html = footer_variants_fixture

    with_url_page('https://wire.example/live/footer-attribution?story=author-only', html) do |page|
      payload = extract_payload(page)

      expect_content_type(payload, 'article')
      expect(payload['contentFormat']).to eq('liveblog')
      expect(payload['title']).to eq('Harbor inspection update')
      expect(payload['byline']).to eq('Updated by Reporter Mira')
      expect(payload['publishedTime']).to eq('2026-09-29T09:00:00Z')
      expect(payload['markdown']).to include(
        'Engineers completed the morning harbor inspection',
        'Updated by Reporter Mira'
      )
      expect(payload['markdown']).not_to include('Foreign Contributor', 'Unrelated site footer')
    end
  end
end
