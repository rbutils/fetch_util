# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'FetchUtil extractor integration - long consent interfaces' do
  include_context 'extractor integration helpers'

  def news_cards
    (1..18).map do |index|
      "<article><h2><a href='/stories/#{index}'>International briefing #{index}</a></h2>" \
        "<p>Report #{index} explains the public findings, supporting evidence and next decisions.</p></article>"
    end.join
  end

  def long_notice
    '<p>We use cookies and similar technologies. Manage privacy preferences for personal data and personalized ads.</p>' * 90
  end

  ['Accept all cookies', 'Accepter les cookies', 'Akzeptieren'].each do |action|
    it "removes an unbranded long modal with a #{action} control while retaining every news record" do
      html = <<~HTML
        <html><head><title>Global Briefings</title></head><body>
          <div role='dialog' aria-modal='true' aria-label='Privacy choices'>
            <h2>Manage privacy preferences</h2>#{long_notice}
            <ul><li><a href='/partners'>Advertising partners</a></li></ul>
            <button>#{action}</button><button>More information</button>
          </div>
          <main><h1>Global Briefings</h1>#{news_cards}</main>
        </body></html>
      HTML

      with_url_page('https://briefings.example.test/', html) do |page|
        payload = FetchUtil::Extractor.new.extract(page)
        (1..18).each { |index| expect(payload['markdown']).to include("International briefing #{index}") }
        expect(payload['markdown']).not_to include('Manage privacy preferences', 'Advertising partners')
        expect(payload['contentType']).to eq('list')
        expect(payload['warnings']).not_to include('consent_interstitial')
        expect(page.body).to include('Manage privacy preferences', 'Advertising partners')
      end
    end
  end

  it 'keeps a consent-only page explicit when no reporting is available' do
    html = <<~HTML
      <html><head><title>Privacy choices</title></head><body>
        <div role='dialog' aria-modal='true'><h1>Manage privacy preferences</h1>#{long_notice}
          <button>Accept all cookies</button><button>Reject all cookies</button>
        </div>
      </body></html>
    HTML

    with_url_page('https://briefings.example.test/', html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)
      expect(payload['contentType']).to eq('interstitial')
      expect(payload['warnings']).to include('consent_interstitial')
      expect(page.body).to include('Manage privacy preferences')
    end
  end

  it 'preserves authored privacy reporting and quoted consent controls' do
    prose = (1..70).map do |index|
      "<p>Record #{index} in the investigation discusses how privacy choices, personal data and cookies affect public services.</p>"
    end.join
    html = <<~HTML
      <html><head><title>Privacy reporting</title></head><body><main><article>
        <h1>Privacy reporting</h1>#{prose}
        <blockquote>
          <p>We use cookies and similar technologies. Manage privacy preferences for personal data.</p>
          <button>Accept all cookies</button>
        </blockquote>
        <p>These quoted choices are evidence in the investigation rather than the site's consent interface.</p>
      </article></main></body></html>
    HTML

    with_url_page('https://reporting.example.test/privacy', html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)
      expect(payload['markdown']).to include('Record 1 in the investigation discusses', 'Record 70 in the investigation discusses',
                                             'These quoted choices are evidence')
      expect(payload['markdown']).to include('We use cookies and similar technologies.')
      expect(payload['warnings']).not_to include('consent_interstitial')
    end
  end
end
