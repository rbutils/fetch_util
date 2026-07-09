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

  it 'stabilizes a simple page fixture without the generic consent wait' do
    page = instance_double(Ferrum::Browser)
    network = instance_double('FerrumNetwork')
    browser = described_class.new(browser_path: '/usr/bin/chromium', wait: 0.75, wait_for_idle: true)

    allow(page).to receive(:network).and_return(network)
    allow(network).to receive(:idle?).and_return(true)
    allow(network).to receive(:wait_for_idle)
    allow(browser).to receive(:wait_for_idle_or_content).with(page).and_return(true)
    allow(browser).to receive(:preserve_consent_wall?).with(page, 'https://example.com').and_return(false)
    allow(browser).to receive(:accept_cookie_consent).with(page).and_return(false)
    allow(browser).to receive(:dismiss_privacy_preference_overlay).with(page).and_return(false)
    allow(browser).to receive(:wait_for_spa_hydration).with(page)
    allow(browser).to receive(:sleep).and_call_original

    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    browser.send(:stabilize_page, page, 'https://example.com')
    elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started

    expect(elapsed).to be < 0.2
    expect(browser).not_to have_received(:sleep).with(0.75)
    expect(browser).to have_received(:accept_cookie_consent).once
    expect(browser).to have_received(:dismiss_privacy_preference_overlay).once
  end

  it 'uses a bounded lodging detail wait for Airbnb room pages' do
    page = instance_double(Ferrum::Browser)
    browser = browser_with_idle

    allow(browser).to receive(:accept_cookie_consent).with(page).and_return(false)
    allow(browser).to receive(:dismiss_privacy_preference_overlay).with(page).and_return(false)
    allow(browser).to receive(:safe_evaluate).and_return(true)
    allow(browser).to receive(:settle_after_stabilization)

    browser.send(:stabilize_page, page, 'https://www.airbnb.com/rooms/123456789')

    expect(browser).to have_received(:safe_evaluate).with(page, include('LodgingBusiness'), default: false)
    expect(browser).not_to have_received(:settle_after_stabilization)
  end
end
