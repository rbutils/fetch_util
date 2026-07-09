# frozen_string_literal: true

RSpec.describe 'FetchUtil government notice extraction' do
  include_context 'extractor integration helpers'

  it 'classifies Federal Register notices and keeps visible metadata' do
    html = fixture_contents(File.expand_path('../../fixtures/federal_register_notice.html', __dir__))

    extract_from_url(
      'https://www.federalregister.gov/documents/2026/07/09/2026-13907/fy-2026-competitive-funding-opportunity-innovative-coordinated-access-and-mobility',
      html
    ) do |payload|
      expect_content_type(payload, 'notice')
      expect(payload['title']).to eq('FY 2026 Competitive Funding Opportunity: Innovative Coordinated Access and Mobility')
      expect(payload['byline']).to eq('Department of Transportation; Federal Transit Administration')
      expect(payload['publishedTime']).to eq('07/09/2026')
      expect(payload['markdown']).to include('AGENCY:')
      expect(payload['markdown']).to include('Federal Transit Administration (FTA), Department of Transportation (DOT).')
      expect(payload['markdown']).to include('SUPPLEMENTARY INFORMATION:')
      expect(payload['markdown']).not_to include('Document Type')
    end
  end

  it 'uses the actual Federal Register title for proposed rules' do
    html = fixture_contents(File.expand_path('../../fixtures/federal_register_notice.html', __dir__))
           .gsub('FY 2026 Competitive Funding Opportunity: Innovative Coordinated Access and Mobility',
                 'Anti-Money Laundering and Countering the Financing of Terrorism Programs')
           .gsub('Notice', 'Proposed Rule')

    extract_from_url(
      'https://www.federalregister.gov/documents/2026/07/09/2026-13919/anti-money-laundering-and-countering-the-financing-of-terrorism-programs',
      html
    ) do |payload|
      expect_content_type(payload, 'notice')
      expect(payload['title']).to eq('Anti-Money Laundering and Countering the Financing of Terrorism Programs')
      expect(payload['title']).not_to eq('Proposed Rule')
    end
  end

  it 'keeps GOV.UK guidance contents and article body as article content' do
    html = fixture_contents(File.expand_path('../../fixtures/govuk_guidance.html', __dir__))

    extract_from_url('https://www.gov.uk/guidance/rates-and-thresholds-for-employers-2026-to-2027', html) do |payload|
      expect_content_type(payload, 'article')
      expect(payload['title']).to eq('Rates and thresholds for employers 2026 to 2027')
      expect(payload['byline']).to eq('HM Revenue & Customs')
      expect(payload['markdown']).to include('Contents')
      expect(payload['markdown']).to include('PAYE tax and Class 1 National Insurance contributions')
      expect(payload['markdown']).to include('Tax thresholds, rates and codes')
      expect(payload['markdown']).to include('National Minimum Wage rates apply from 1 April 2026')
    end
  end
end
