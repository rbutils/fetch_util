# frozen_string_literal: true

require 'spec_helper'

RSpec.describe FetchUtil::Browser do
  include_context 'browser spec helpers'

  it 'waits for delayed France24 article bodies after generic stabilization' do
    page = instance_double(Ferrum::Browser)
    network = instance_double('FerrumNetwork')
    browser = browser_with_idle

    allow(page).to receive(:network).and_return(network)
    allow(network).to receive(:idle?).and_return(true)
    allow(network).to receive(:wait_for_idle)
    allow(browser).to receive(:wait_for_idle_or_content).with(page).and_return(true)
    allow(browser).to receive(:preserve_consent_wall?).with(page, 'https://www.france24.com/es/francia/20260707-condena-de-marine-le-pen-lo-que-hay-que-retener').and_return(true)
    allow(browser).to receive(:wait_for_spa_hydration).with(page)
    expect(browser).not_to receive(:accept_cookie_consent)
    expect(browser).not_to receive(:dismiss_privacy_preference_overlay)
    allow(browser).to receive(:sleep)
    expect(browser).to receive(:wait_for_france24_article).with(page, 'https://www.france24.com/es/francia/20260707-condena-de-marine-le-pen-lo-que-hay-que-retener')

    browser.send(:stabilize_page, page, 'https://www.france24.com/es/francia/20260707-condena-de-marine-le-pen-lo-que-hay-que-retener')
  end
end
