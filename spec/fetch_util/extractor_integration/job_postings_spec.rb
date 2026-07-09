# frozen_string_literal: true

RSpec.describe 'FetchUtil job posting extraction' do
  include_context 'extractor integration helpers'

  it 'classifies JSON-LD JobPosting pages as jobs with structured fields' do
    html = fixture_contents(File.expand_path('../../fixtures/job_posting_json_ld.html', __dir__))

    extract_from_url('https://example.com/careers/backend-engineer-payments', html) do |payload|
      expect_content_type(payload, 'job')
      expect(payload['title']).to eq('Backend Engineer, Payments')
      expect(payload['company']).to eq('ExampleCo')
      expect(payload['location']).to eq('San Francisco, CA, US')
      expect(payload['description']).to include('Build reliable payment systems')
      expect(payload['description']).to include('## Responsibilities')
      expect(payload['description']).not_to include('<p>')
      expect(payload['markdown']).to include('- Company: ExampleCo')
      expect(payload['markdown']).to include('- Location: San Francisco, CA, US')
    end
  end

  it 'classifies common DOM job-detail pages as jobs when structured data is absent' do
    html = fixture_contents(File.expand_path('../../fixtures/job_posting_dom.html', __dir__))

    extract_from_url('https://jobs.example.com/careers/staff-product-engineer', html) do |payload|
      expect_content_type(payload, 'job')
      expect(payload['title']).to eq('Platform Workshop Lead')
      expect(payload['company']).to eq('Northstar Workshop')
      expect(payload['location']).to eq('New York, NY')
      expect(payload['description']).to start_with('Shape a small coordination service used by distributed operations teams.')
      expect(payload['description']).to include('## What you bring')
      expect(payload['markdown']).to include('# Platform Workshop Lead')
    end
  end

  it 'serializes array and top-level structured job addresses' do
    html = <<~HTML
      <html><head><script type="application/ld+json">{"@context":"https://schema.org","@type":"JobPosting","title":"Platform Engineer","description":"Build reliable platform systems with careful operational ownership and documented engineering practices.","jobLocation":[{"streetAddress":"1 Rails Way","addressLocality":"Austin","addressRegion":"TX","postalCode":"78701","addressCountry":{"name":"United States"}},{"address":"Remote"}]}</script></head><body><h1>Platform Engineer</h1></body></html>
    HTML

    extract_from_url('https://example.com/careers/platform-engineer', html) do |payload|
      expect_content_type(payload, 'job')
      expect(payload['location']).to eq('1 Rails Way, Austin, TX, 78701, United States; Remote')
    end
  end

  it 'keeps a product-like job monotonic and preserves its complete description' do
    html = fixture_contents(File.expand_path('../../fixtures/w1_wwr_job_property_negative.html', __dir__))

    extract_from_url('https://weworkremotely.com/remote-jobs/accuweather-senior-software-engineer', html) do |payload|
      expect_content_type(payload, 'job')
      expect(payload['location']).to eq('Remote; United States; Canada')
      expect(payload['description']).to include('properties for configuration')
      expect(payload['description']).to include('$100,000')
      expect(payload['description']).to include('documented engineering responsibilities')
      expect(payload['price']).to be_nil
      expect(payload['bedrooms']).to be_nil
      expect(payload['sku']).to be_nil
    end
  end
end
