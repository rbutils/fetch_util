# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Investor relations extraction' do
  include_context 'extractor integration helpers'

  it 'does not append financial links from unrelated article chrome' do
    html = fixture_contents(File.expand_path('../../fixtures/onet_sport_article_financial_noise.html', __dir__))

    extract_from_url('https://przegladsportowy.onet.pl/pilka-nozna/relacja-z-meczu', html) do |payload|
      expect(payload['contentType']).to eq('article')
      expect(payload['markdown']).not_to include('## Financial Statement Links')
      expect(payload['markdown']).not_to include('financial-download.pdf')
      expect(payload['markdown']).to include('https://cdn.onet.pl/sport/mecz.jpg')
      expect(payload['markdown']).to include('Gospodarze zakonczyli spotkanie wynikiem korzystnym')
    end
  end

  it 'surfaces linked financial statement PDFs and images from earnings releases' do
    html = fixture_contents(File.expand_path('../../fixtures/ir_apple_earnings.html', __dir__))

    extract_from_url('https://www.apple.com/newsroom/2025/07/apple-reports-third-quarter-results/', html) do |payload|
      expect(payload['contentType']).to eq('article')
      expect(payload['markdown']).to include('Apple reports third quarter results')
      expect(payload['markdown']).to include('## Financial Statement Links')
      expect(payload['markdown']).to include('https://www.apple.com/newsroom/pdfs/FY25_Q3_Consolidated_Financial_Statements.pdf')
      expect(payload['markdown']).to include('https://www.apple.com/newsroom/images/fy25-q3-condensed-consolidated-statements.png')
      expect_warnings(payload, exclude: %w[url_content_mismatch empty_extraction short_extraction])
    end
  end

  it 'preserves every accepted financial document link in DOM order' do
    html = fixture_contents(File.expand_path('../../fixtures/ir_many_statement_links.html', __dir__))

    extract_from_url('https://example.test/investor-relations/annual-report', html) do |payload|
      markdown = payload.fetch('markdown')
      expected_urls = [
        '01-balance-sheet.pdf', '02-income-statement.pdf', '03-cash-flow.pdf', '04-equity-statement.pdf',
        '05-notes.pdf', '06-annual-report.pdf', '07-quarterly-report.pdf', '08-earnings-release.pdf',
        '09-form-10-k.pdf', '10-form-10-q.pdf', '11-consolidated-statements.pdf', '12-condensed-statements.pdf',
        '13-shareholder-letter.pdf', '14-investor-relations.xlsx'
      ].map { |path| "https://example.test/ir/2025/#{path}" }

      expect(payload['contentType']).to eq('article')
      expect(markdown.scan('## Financial Statement Links').length).to eq(1)
      expect(expected_urls).to all(satisfy { |url| markdown.include?(url) })
      expect(expected_urls.map { |url| markdown.index(url) }).to eq(expected_urls.map { |url| markdown.index(url) }.sort)
    end
  end

  it 'does not warn on archive-style annual shareholder letters with good extraction' do
    html = fixture_contents(File.expand_path('../../fixtures/ir_berkshire_letter.html', __dir__))

    extract_from_url('https://www.berkshirehathaway.com/2001ar/2001letter.html', html) do |payload|
      expect(payload['contentType']).to eq('article')
      expect(payload['markdown']).to include('2001 Letter to Shareholders')
      expect(payload['markdown']).to include('synthetic archive record retains the 2001 net-worth field')
      expect_warnings(payload, exclude: %w[url_content_mismatch empty_extraction short_extraction])
    end
  end

  it 'keeps SEC EDGAR HTML filing bodies and tables' do
    html = fixture_contents(File.expand_path('../../fixtures/sec_edgar_filing.html', __dir__))

    extract_from_url('https://www.sec.gov/Archives/edgar/data/320193/000032019325000079/aapl-20250628.htm', html) do |payload|
      expect(payload['contentType']).to eq('article')
      expect(payload['hostAware']).to be(true)
      expect(payload['markdown']).to include('FORM 10-Q')
      expect(payload['markdown']).to include('Management\'s Discussion and Analysis')
      expect(payload['markdown']).to include('| Products net sales | Three Months Ended |')
      expect_warnings(payload, exclude: %w[url_content_mismatch truncated_content empty_extraction short_extraction])
    end
  end

  it 'keeps a datelined earnings release distinct from investor navigation' do
    html = <<~HTML
      <html><head><title>Example reports third-quarter results</title></head><body><main><article>
        <h1>Example reports third-quarter results</h1><p>SEATTLE, July 20, 2026 -- Example today reported third-quarter results.</p>
        <p>Revenue increased with disciplined operating investment, a broader customer base, and continued product development across the company. The release explains that management will keep investing in durable infrastructure, customer support, and measured hiring while maintaining a long-term focus on profitable growth.</p>
        <table><thead><tr><th>Revenue</th><th>Quarter</th></tr></thead><tbody><tr><td>$500</td><td>Q3</td></tr></tbody></table>
        <p><a href="/reports/q3.pdf">Quarterly report PDF</a></p>
      </article></main></body></html>
    HTML

    extract_from_url('https://investor.example.test/news/quarterly-results', html) do |payload|
      expect_content_type(payload, 'press_release')
      expect(payload['markdown']).to include('| Revenue | Quarter |')
      expect(payload['markdown']).to include('Quarterly report PDF')
    end
  end
end
