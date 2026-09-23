# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'FetchUtil extractor integration - consent notice ownership' do
  include_context 'extractor integration helpers'

  it 'keeps a public buyer page when its own feature describes cookie matching' do
    features = [
      ['Addressability', 'We engage in cookie matching, saving IDs and integrating external identifiers across campaigns.'],
      ['Buying Priority', 'Preferred agreements let buyers reach relevant inventory before other sources of demand.'],
      ['Broad Formats', 'Advertising formats connect buyers with audiences across apps, video, and other screens.'],
      ['Improved Optimization', 'Real-time reporting helps buyers adjust campaigns across impactful channels.'],
      ['Customized Support', 'A dedicated team helps customers plan and improve their campaigns.']
    ]
    html = <<~HTML
      <html><head><title>For Buyers | Exchange</title></head><body>
        <div class="hero"><h1>For Buyers</h1><p>Let your brand meet the right audience through our exchange.</p></div>
        <div class="features">
          #{features.map.with_index { |(heading, prose), index| "<div id='feature-#{index}'><h2>#{heading}</h2><p>#{prose}</p></div>" }.join}
        </div>
        <footer><a href="/privacy">Privacy Policy</a></footer>
      </body></html>
    HTML

    with_url_page('https://exchange.example.test/buyers', html) do |page|
      extractor_for(true).__send__(:inject_assets, page)
      payload = page.evaluate(<<~JS)
        (() => {
          const NarrowReadability = function() {};
          NarrowReadability.prototype.parse = function() {
            const root = document.querySelector('#feature-0');
            return { title: 'For Buyers', content: root.outerHTML, textContent: root.textContent };
          };
          window.Readability = NarrowReadability;
          return window.FetchUtilExtract.extract({ reader_mode: true });
        })()
      JS

      expect(payload['markdown']).to include('cookie matching')
      expect(payload['contentType']).to eq('article')
      expect(payload['warnings']).not_to include('consent_interstitial')
    end
  end

  it 'still treats an owned cookie prompt as a consent wall' do
    html = <<~HTML
      <html><head><title>Welcome</title></head><body><main>
        <h1>Welcome</h1>
        <p>We use cookies to personalize this website and measure advertising.</p>
        <button>Accept all cookies</button><button>Reject all cookies</button>
      </main></body></html>
    HTML

    with_url_page('https://welcome.example.test/', html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)
      expect(payload['warnings']).to include('consent_interstitial')
      expect(payload['contentType']).to eq('interstitial')
    end
  end
end
