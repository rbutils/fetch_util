RSpec.describe 'Declared guidance publication precision' do
  include_context 'extractor integration helpers'

  let(:guidance_html) { fixture_contents(File.expand_path('../../fixtures/govuk_guidance.html', __dir__)) }
  let(:guidance_url) { 'https://unknown.example/guidance/publication-precision' }

  def each_guidance_layout(html, &)
    plain = html.sub('<div id="contents" data-module="contents-list-with-body"', '<div id="contents"')
                .sub(%r{<nav aria-label="Contents".*?</nav>}m, '')
    [html, plain].each(&)
  end

  it 'preserves the original declared timestamp in both Contents and plain article layouts' do
    each_guidance_layout(guidance_html) do |html|
      extract_from_url(guidance_url, html) do |payload|
        expect_content_type(payload, 'article')
        expect(payload['byline']).to eq('HM Revenue & Customs')
        expect(payload['publishedTime']).to eq('2026-01-30T10:09:00+00:00')
        expect(payload['markdown']).to include('The example payroll uses PAYE so HMRC can record the synthetic deductions.')
      end
    end
  end

  it 'retains higher-priority standard publication metadata without discarding its precision' do
    html = guidance_html.sub('</head>', '<meta property="article:published_time" content="2026-01-30T14:35:00+00:00"></head>')

    each_guidance_layout(html) do |layout|
      extract_from_url(guidance_url, layout) do |payload|
        expect(payload['byline']).to eq('HM Revenue & Customs')
        expect(payload['publishedTime']).to eq('2026-01-30T14:35:00+00:00')
      end
    end
  end

  it 'keeps the owned Contents publication day when a declared timestamp contradicts it' do
    html = guidance_html.sub('2026-01-30T10:09:00+00:00', '2025-12-01T10:09:00+00:00')

    extract_from_url(guidance_url, html) do |payload|
      expect(payload['byline']).to eq('HM Revenue & Customs')
      expect(payload['publishedTime']).to eq('30 January 2026')
      expect(payload['markdown']).to include('The example payroll uses PAYE so HMRC can record the synthetic deductions.')
    end
  end

  it 'compares the declared calendar day without shifting it through UTC' do
    timestamp = '2026-01-30T23:50:00-07:00'
    html = guidance_html.sub('2026-01-30T10:09:00+00:00', timestamp)

    each_guidance_layout(html) do |layout|
      extract_from_url(guidance_url, layout) do |payload|
        expect(payload['byline']).to eq('HM Revenue & Customs')
        expect(payload['publishedTime']).to eq(timestamp)
      end
    end
  end

  it 'preserves a visible publication day without inventing a timestamp when none is declared' do
    html = guidance_html.sub(/<meta name="govuk:first-published-at"[^>]*>/, '')

    each_guidance_layout(html) do |layout|
      extract_from_url(guidance_url, layout) do |payload|
        expect(payload['publishedTime']).to eq('30 January 2026')
      end
    end
  end
end
