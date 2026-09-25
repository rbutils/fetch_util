# frozen_string_literal: true

RSpec.describe 'FetchUtil visible publication fields' do
  include_context 'extractor integration helpers'

  def publication_field_page(field)
    <<~HTML
      <html><head><title>Restoring the river</title><meta name="generator" content="WordPress 6.8"></head>
      <body><main><article class="status-publish"><h1 class="entry-title">Restoring the river</h1>
        <div class="publication-wrapper">#{field}<div class="entry-content">
          <p>The restoration team returned to the river to measure the effect of removing the concrete barriers.</p>
          <p>Engineers compared water levels and wildlife counts before discussing the next stage with residents.</p>
          <p>The work will continue through the autumn, with a public report documenting each result.</p>
        </div></div></article></main></body></html>
    HTML
  end

  it 'does not treat publication-status article or body containers as a date field' do
    extract_from_url('https://example-blog.test/restoration/', publication_field_page('')) do |payload|
      expect(payload['publishedTime']).to be_nil
      expect(payload['markdown']).to include('The restoration team returned to the river')
    end
  end

  it 'finds localized publication fields after rejecting a matching body wrapper' do
    fields = {
      '<div class="published"><p>Δημοσιεύτηκε: 25 Σεπτεμβρίου 2026</p></div>' => 'Δημοσιεύτηκε: 25 Σεπτεμβρίου 2026',
      '<p class="published"><span>Published</span> September 25, 2026</p>' => 'Published September 25, 2026'
    }

    fields.each do |field, expected|
      extract_from_url('https://example-blog.test/restoration/', publication_field_page(field)) do |payload|
        expect(payload['publishedTime']).to eq(expected)
      end
    end
  end

  it 'preserves explicit datetime priority and ignores hidden date fields' do
    field = <<~HTML
      <span class="published" hidden>September 24, 2026</span>
      <time datetime="2026-09-25T09:30:00Z">25 September 2026</time>
    HTML

    extract_from_url('https://example-blog.test/restoration/', publication_field_page(field)) do |payload|
      expect(payload['publishedTime']).to eq('2026-09-25T09:30:00Z')
    end
  end
end
