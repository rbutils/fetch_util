RSpec.describe 'Canonical article linked-card material ownership' do
  include_context 'extractor integration helpers'

  def linked_card_fixture(name)
    fixture_contents("spec/fixtures/canonical_article_ownership/#{name}")
  end

  def rendered_article(payload)
    "#{payload.fetch("html")}\n#{payload.fetch("markdown")}"
  end

  it 'ignores complete cards whose title and media anchors share each external destination' do
    url = 'https://counter.example/articles/complete-linked-cards'

    with_url_page(url, linked_card_fixture('linked-card-complete.html')) do |page|
      payload = extract_payload(page)
      rendered = rendered_article(payload)

      expect(payload['contentType']).to eq('article')
      expect(payload['publishedTime']).to eq('2026-09-29T08:00:00Z')
      expect(rendered).to include('Harbor restoration plan', 'complete harbor restoration plan')
      expect(rendered).not_to include('More independently linked stories')
      expect(rendered).not_to include(
        'Flood response source photograph', '/media/flood-response.jpg',
        'Transit update source photograph', '/media/transit-update.jpg'
      )
    end
  end

  it 'declines canonical ownership for an unlinked paragraph and PDF destination in a card' do
    url = 'https://counter.example/articles/unowned-prose-pdf'

    with_url_page(url, linked_card_fixture('linked-card-unowned-prose-pdf.html')) do |page|
      payload = extract_payload(page)
      rendered = rendered_article(payload)

      expect(payload['contentType']).to eq('article')
      expect(payload['publishedTime']).to eq('2026-09-29T08:00:00Z')
      expect(rendered).to include(
        'complete harbor restoration plan',
        'The harbor authority issued an additional closing update',
        'Download the complete harbor support review PDF',
        '/reports/harbor-support-review.pdf'
      )
    end
  end

  it 'declines canonical ownership for an unlinked image and caption in a card' do
    url = 'https://counter.example/articles/unowned-image-caption'

    with_url_page(url, linked_card_fixture('linked-card-unowned-image-caption.html')) do |page|
      payload = extract_payload(page)
      rendered = rendered_article(payload)

      expect(payload['contentType']).to eq('article')
      expect(payload['publishedTime']).to eq('2026-09-29T08:00:00Z')
      expect(rendered).to include(
        'complete harbor restoration plan',
        'harbor-engineers.jpg',
        'Harbor engineers at the inspection',
        'Harbor engineers recorded the independent inspection conditions.'
      )
    end
  end
end
