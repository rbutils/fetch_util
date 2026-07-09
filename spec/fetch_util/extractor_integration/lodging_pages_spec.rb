# frozen_string_literal: true

RSpec.describe 'FetchUtil lodging page extraction' do
  include_context 'extractor integration helpers'

  it 'preserves every visible amenity beyond the presentation threshold' do
    html = fixture_contents(File.expand_path('../../fixtures/lodging_over_cap.html', __dir__))

    extract_from_url('https://example.test/hotel/over-cap', html) do |payload|
      expect(payload['markdown']).to include('Amenity 25')
      expect(payload['markdown']).to include('Late amenity with a complete description')
      expect(payload['markdown']).not_to include('Show all amenities')
      expect(payload['markdown'].index('Amenity 25')).to be < payload['markdown'].index('Late amenity with a complete description')
    end
  end

  it 'classifies JSON-LD LodgingBusiness pages as hotels with structured fields' do
    html = fixture_contents(File.expand_path('../../fixtures/lodging_json_ld.html', __dir__))

    extract_from_url('https://travel.example.test/hotel/seaside-garden-hotel', html) do |payload|
      expect_content_type(payload, 'hotel')
      expect(payload['name']).to eq('Seaside Garden Hotel')
      expect(payload['title']).to eq('Seaside Garden Hotel')
      expect(payload['price']).to eq('£189')
      expect(payload['rating']).to eq('Rating: 4.6/5 from 842 reviews')
      expect(payload['address']).to eq('12 Harbor Road, Brighton, East Sussex, BN1 1AA, GB')
      expect(payload['markdown']).to include('- Price: £189')
      expect(payload['markdown']).to include('- Address: 12 Harbor Road, Brighton, East Sussex, BN1 1AA, GB')
    end
  end

  it 'preserves Booking-style descriptions and amenity lists' do
    html = fixture_contents(File.expand_path('../../fixtures/lodging_booking_dom.html', __dir__))

    extract_from_url('https://www.booking.com/hotel/nl/canal-house-suites.html', html) do |payload|
      expect_content_type(payload, 'hotel')
      expect(payload['name']).to eq('Canal House Suites')
      expect(payload['price']).to eq('$242')
      expect(payload['rating']).to eq('Rating: 9.1/10')
      expect(payload['address']).to eq('Keizersgracht 100, Amsterdam City Center, 1015 CV Amsterdam, Netherlands')
      expect(payload['description']).to include('restored residence offers generous')
      expect(payload['markdown']).to include('## Amenities')
      expect(payload['markdown']).to include('- Wireless internet')
      expect(payload['markdown']).to include('- Shuttle service')
    end
  end

  it 'flags client-rendered lodging shells instead of treating them as usable lists' do
    html = fixture_contents(File.expand_path('../../fixtures/lodging_airbnb_shell.html', __dir__))

    extract_from_url('https://www.airbnb.com/rooms/30939716', html) do |payload|
      expect_content_type(payload, 'interstitial')
      expect(payload['warnings']).to include('client_rendered_property_shell')
      expect(payload['markdown']).to include('Client-rendered lodging detail shell')
    end
  end
end
