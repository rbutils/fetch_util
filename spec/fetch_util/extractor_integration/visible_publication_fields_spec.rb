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

  it 'prefers a date value among section labels without discarding other date formats' do
    labeled_fields = <<~HTML
      <div class="publication-wrapper">
        <div class="detail-time">تازہ ترین</div>
        <div class="detail-time">قومی خبریں</div>
        <div class="detail-time">26 ستمبر ، 2026</div>
        <div class="entry-content"><p>#{"A" * 80}</p></div>
      </div>
    HTML
    extract_from_url('https://example-blog.test/restoration/', publication_field_page(labeled_fields)) do |payload|
      expect(payload['publishedTime']).to eq('26 ستمبر ، 2026')
    end

    timed_fields = '<time datetime="latest">Latest</time><time datetime="2026-09-28">September 28, 2026</time>'
    extract_from_url('https://example-blog.test/restoration/', publication_field_page(timed_fields)) do |payload|
      expect(payload['publishedTime']).to eq('2026-09-28')
    end

    {
      '<span class="published-date">13 July</span>' => '13 July',
      '<span class="published-date">2026年9月27日</span>' => '2026年9月27日',
      '<span class="published-date">٢٦ سبتمبر ٢٠٢٦</span>' => '26 سبتمبر 2026',
      '<span class="published-date">۲۶ سپتامبر ۲۰۲۶</span>' => '26 سپتامبر 2026',
      '<span class="published-date">3 hours ago</span>' => '3 hours ago',
      '<span class="published-date">12:30</span>' => '12:30'
    }.each do |field, expected|
      with_url_page('https://example-blog.test/restoration/', publication_field_page(field)) do |page|
        original = page.evaluate('document.body.innerHTML')
        payload = extract_payload(page)
        expect(payload['publishedTime']).to eq(expected)
        expect(page.evaluate('document.body.innerHTML')).to eq(original)
      end
    end
  end

  it 'retains the existing first-field fallback when no recognized date format is present' do
    field = '<span class="published-date">Latest coverage</span><span class="date">Regional news</span>'
    extract_from_url('https://example-blog.test/restoration/', publication_field_page(field)) do |payload|
      expect(payload['publishedTime']).to eq('Latest coverage')
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

  def inline_publication_page(field)
    heading = '<h1 class="entry-title">Restoring the river</h1>'
    publication_field_page('').sub(heading, "<header class=\"entry-header\">#{field}#{heading}</header>")
  end

  it 'retains inline labeled header dates in metadata and content without making them the excerpt' do
    field = 'Atualizado em <strong>08/09/2026 às 13:55</strong> • Verificação em tempo real'

    extract_from_url('https://example-blog.test/restoration/', inline_publication_page(field)) do |payload|
      expect(payload['publishedTime']).to eq('08/09/2026 às 13:55')
      expect(payload['html']).to include('Atualizado em <strong>08/09/2026 às 13:55</strong>')
      expect(payload['markdown']).to include('Atualizado em **08/09/2026 às 13:55**')
      expect(payload['excerpt']).to start_with('The restoration team returned to the river')
    end
  end

  it 'does not promote event dates, hidden dates, ambiguous headers, or non-date labels' do
    fields = [
      'Meeting on <strong>08/09/2026</strong>',
      'Updated <strong hidden>2026-09-08</strong>',
      'Updated <strong style="visibility:hidden">2026-09-08</strong>',
      'Updated <strong>all river measurements</strong>',
      'Updated <strong>2026-09-08</strong><h1>Another article</h1>'
    ]

    fields.each do |field|
      extract_from_url('https://example-blog.test/restoration/', inline_publication_page(field)) do |payload|
        expect(payload['publishedTime']).to be_nil
      end
    end
  end

  it 'keeps explicit datetime priority while preserving the separate updated field in content' do
    field = 'Updated <strong>2026-09-08 13:55</strong><time datetime="2026-09-07T12:00:00Z">7 September</time>'

    extract_from_url('https://example-blog.test/restoration/', inline_publication_page(field)) do |payload|
      expect(payload['publishedTime']).to eq('2026-09-07T12:00:00Z')
      expect(payload['markdown']).to include('Updated **2026-09-08 13:55**')
    end
  end

  it 'retains a dated header when the same article repeats its exact headline in the body' do
    html = inline_publication_page('Atualizado em <strong>14/09/2026 às 13:36</strong>')
           .sub('<div class="entry-content">', '<div class="entry-content"><h1>Restoring the river</h1>')

    extract_from_url('https://example-blog.test/restoration/', html) do |payload|
      expect(payload['publishedTime']).to eq('14/09/2026 às 13:36')
      expect(payload['markdown']).to include('Atualizado em **14/09/2026 às 13:36**')
      expect(payload['excerpt']).to start_with('The restoration team returned to the river')
    end
  end
end
