# frozen_string_literal: true

RSpec.describe 'FetchUtil property listing extraction' do
  include_context 'extractor integration helpers'

  it 'classifies JSON-LD real-estate listings and extracts structured fields' do
    html = fixture_contents(File.expand_path('../../fixtures/property_listing_json_ld.html', __dir__))

    with_url_page('https://www.redfin.com/CA/Lakeport/1255-Sixth-St-95453/home/12345678', html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload['contentType']).to eq('property')
      expect(payload['price']).to eq('$399000')
      expect(payload['location']).to eq('1255 Sixth Street, Lakeport, CA, 95453')
      expect(payload['bedrooms']).to eq(3)
      expect(payload['bathrooms']).to eq(2)
      expect(payload['areaSqft']).to eq(1428)
      expect(payload['markdown']).to include('- Price: $399000')
      expect(payload['markdown']).to include('About this home')
      expect(payload['suspect']).to be(false)
    end
  end

  it 'keeps Rightmove-style visible listing bodies as property pages instead of lists' do
    html = fixture_contents(File.expand_path('../../fixtures/property_listing_dom.html', __dir__))

    with_url_page('https://www.rightmove.co.uk/properties/90696585', html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload['contentType']).to eq('property')
      expect(payload['price']).to eq('£450,000')
      expect(payload['location']).to eq('Station Road, Bristol, BS1')
      expect(payload['bedrooms']).to eq(3)
      expect(payload['bathrooms']).to eq(2)
      expect(payload['areaSqft']).to eq(1210)
      expect(payload['markdown']).to include('A bright family residence with a broad front room')
      expect(payload['markdown']).to include('A bright family residence')
      expect(payload['markdown']).to include('Connected cooking and dining space')
      expect(payload['suspect']).to be(false)
    end
  end

  it 'falls back to fieldless structured property addresses' do
    html = <<~HTML
      <html><head><script type="application/ld+json">{"@context":"https://schema.org","@type":"House","name":"Harbor Cottage","description":"A detailed coastal cottage listing with bright rooms, private gardens, and walkable local amenities.","address":{"name":"Old Harbor District"},"offers":{"price":"425000","priceCurrency":"USD"}}</script></head><body><main><h1>Harbor Cottage</h1><p>Coastal home with private gardens and bright rooms.</p></main></body></html>
    HTML

    with_url_page('https://homes.example.test/property/harbor-cottage', html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload['contentType']).to eq('property')
      expect(payload['location']).to eq('Old Harbor District')
    end
  end

  it 'does not promote an article with incidental property language and price' do
    html = fixture_contents(File.expand_path('../../fixtures/w1_npr_article_property_negative.html', __dir__))

    extract_from_url('https://www.npr.org/2026/07/10/nx-s1-5885027/housing-bill-without-trump-signature', html) do |payload|
      expect(payload['contentType']).to eq('article')
      expect(payload['price']).to be_nil
      expect(payload['location']).to be_nil
      expect(payload['markdown']).to include('properties are assessed')
    end
  end

  it 'keeps NPR root coverage as a list despite incidental property language' do
    html = fixture_contents(File.expand_path('../../fixtures/w1_npr_root_property_negative.html', __dir__))

    extract_from_url('https://www.npr.org/', html) do |payload|
      expect(payload['contentType']).to eq('list')
      expect(payload['price']).to be_nil
      expect(payload['location']).to be_nil
      expect(payload['markdown']).to include('[Housing bill advances]')
    end
  end
end
