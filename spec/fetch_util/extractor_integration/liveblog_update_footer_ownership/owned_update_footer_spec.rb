# frozen_string_literal: true

RSpec.describe 'FetchUtil source-owned liveblog update attribution' do
  include_context 'extractor integration helpers'

  def fixture
    fixture_contents(File.expand_path('../../../fixtures/liveblog_update_footer_ownership/owned-update-footers.html', __dir__))
  end

  it 'keeps update-owned footer attribution while parent date and author remain absent' do
    html = fixture
    parent_url = 'https://wire.example/live/harbor'

    with_url_page(parent_url, html) do |page|
      payload = extract_payload(page)

      expect_content_type(payload, 'article')
      expect(payload['contentFormat']).to eq('liveblog')
      expect(payload['title']).to eq('Harbor operations live updates')
      expect(payload['publishedTime']).to be_nil
      expect(payload['byline']).to be_nil
      expect(payload['markdown']).to include(
        'Updated by Reporter Mira', 'Attribution posted at 9:05 UTC',
        'Updated by Reporter Rowan', 'Attribution posted at 10:35 UTC'
      )
      expect(payload['markdown']).not_to include('Unrelated site footer that must stay outside the liveblog')
    end
  end

  it 'keeps the addressed update footer in the selected update body' do
    entry_url = 'https://wire.example/live/harbor?story=second'

    with_url_page(entry_url, fixture) do |page|
      payload = extract_payload(page)

      expect_content_type(payload, 'article')
      expect(payload['contentFormat']).to eq('liveblog')
      expect(payload['title']).to eq('West bridge remains open')
      expect(payload['byline']).to eq('Updated by Reporter Rowan')
      expect(payload['publishedTime']).to eq('2026-09-29T10:30:00Z')
      expect(payload['markdown']).to include(
        'Officials confirmed the west bridge remains open',
        'Updated by Reporter Rowan', 'Attribution posted at 10:35 UTC'
      )
      expect(payload['markdown']).not_to include('Initial harbor notice', 'Unrelated site footer that must stay outside the liveblog')
    end
  end

  it 'preserves material author-only, time-only, and contact footers without parent metadata' do
    html = fixture_contents(File.expand_path('../../../fixtures/liveblog_footer_ownership/owned-footer-variants.html', __dir__))
    parent_url = 'https://wire.example/live/footer-attribution'

    with_url_page(parent_url, html) do |page|
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

  it 'preserves an owned footer in a structurally validated div update' do
    html = fixture_contents(File.expand_path('../../../fixtures/liveblog_footer_ownership/div-update-footer.html', __dir__))
    entry_url = 'https://wire.example/live/div-footer?entry=div'

    with_url_page(entry_url, html) do |page|
      payload = extract_payload(page)

      expect_content_type(payload, 'article')
      expect(payload['contentFormat']).to eq('liveblog')
      expect(payload['title']).to eq('North pier clearance')
      expect(payload['byline']).to eq('Report by Pier Desk')
      expect(payload['publishedTime']).to eq('2026-09-29T15:00:00Z')
      expect(payload['markdown']).to include(
        'Harbor engineers cleared the north pier',
        'Report by Pier Desk',
        'Field credit: Pier operations desk.',
        'Contact Pier Desk'
      )
      expect(payload['markdown']).not_to include('Unrelated port site footer.')
    end
  end
end
