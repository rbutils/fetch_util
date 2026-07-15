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
    allow(browser).to receive(:safe_evaluate).and_return({})
    allow(browser).to receive(:wait_for_idle_or_content).with(page).and_return(true)
    allow(browser).to receive(:preserve_consent_wall?).with(page, 'https://www.france24.com/es/francia/20260707-condena-de-marine-le-pen-lo-que-hay-que-retener').and_return(true)
    allow(browser).to receive(:wait_for_spa_hydration).with(page)
    expect(browser).not_to receive(:accept_cookie_consent)
    expect(browser).not_to receive(:dismiss_privacy_preference_overlay)
    allow(browser).to receive(:sleep)
    expect(browser).to receive(:wait_for_france24_article).with(page, 'https://www.france24.com/es/francia/20260707-condena-de-marine-le-pen-lo-que-hay-que-retener')

    browser.send(:stabilize_page, page, 'https://www.france24.com/es/francia/20260707-condena-de-marine-le-pen-lo-que-hay-que-retener')
  end

  it 'waits for the requested Telegram preview message before extraction' do
    page = instance_double(Ferrum::Browser)
    browser = browser_with_idle

    expect(browser).to receive(:wait_for_anubis_challenge).with(page).and_return(true).ordered
    expect(browser).to receive(:wait_for_telegram_message).with(page).ordered

    browser.send(:stabilize_page, page, 'https://t.me/s/examplechannel/42')
  end

  it 'stabilizes a simple page fixture without the generic consent wait' do
    page = instance_double(Ferrum::Browser)
    network = instance_double('FerrumNetwork')
    browser = described_class.new(browser_path: '/usr/bin/chromium', wait: 0.75, wait_for_idle: true)

    allow(page).to receive(:network).and_return(network)
    allow(network).to receive(:idle?).and_return(true)
    allow(network).to receive(:wait_for_idle)
    allow(browser).to receive(:safe_evaluate).and_return({})
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

  it 'resolves a short same-URL page after a rendered Anubis shell' do
    page = instance_double(Ferrum::Browser)
    browser = browser_with_idle(timeout: 1.0)
    states = [
      { 'challenge' => true, 'document_ready' => false, 'body_present' => true, 'body_text_present' => true, 'url' => 'https://example.com/' },
      { 'challenge' => true, 'document_ready' => true, 'body_present' => true, 'body_text_present' => true, 'url' => 'https://example.com/' },
      { 'challenge' => false, 'document_ready' => true, 'body_present' => true, 'body_text_present' => true, 'url' => 'https://example.com/' }
    ]

    allow(browser).to receive(:safe_evaluate) { states.shift || states.last }

    expect(browser.send(:wait_for_anubis_challenge, page)).to be(true)
  end

  it 'accepts Anubis resolution that navigates to a different URL' do
    page = instance_double(Ferrum::Browser)
    browser = browser_with_idle(timeout: 1.0)

    allow(browser).to receive(:safe_evaluate).and_return(
      { 'challenge' => true, 'document_ready' => true, 'body_present' => true, 'body_text_present' => true, 'url' => 'https://example.com/.within.website/challenge' },
      { 'challenge' => false, 'document_ready' => true, 'body_present' => true, 'body_text_present' => true, 'url' => 'https://example.com/article' }
    )

    expect(browser.send(:wait_for_anubis_challenge, page)).to be(true)
  end

  it 'does not resolve on a transient evaluation failure' do
    page = instance_double(Ferrum::Browser)
    browser = browser_with_idle(timeout: 1.0)

    allow(browser).to receive(:safe_evaluate).and_return(
      { 'challenge' => true, 'document_ready' => true, 'body_present' => true, 'body_text_present' => true, 'url' => 'https://example.com/' },
      {},
      { 'challenge' => false, 'document_ready' => false, 'body_present' => true, 'body_text_present' => true, 'url' => 'https://example.com/' },
      { 'challenge' => false, 'document_ready' => true, 'body_present' => true, 'body_text_present' => true, 'url' => 'https://example.com/' }
    )

    expect(browser.send(:wait_for_anubis_challenge, page)).to be(true)
  end

  it 'retries an invalid initial Anubis observation once' do
    page = instance_double(Ferrum::Browser)
    browser = browser_with_idle(timeout: 1.0)

    allow(browser).to receive(:safe_evaluate).and_return(
      {},
      { 'challenge' => true, 'document_ready' => true, 'body_present' => true, 'body_text_present' => true, 'url' => 'https://example.com/' },
      { 'challenge' => false, 'document_ready' => true, 'body_present' => true, 'body_text_present' => true, 'url' => 'https://example.com/' }
    )

    expect(browser.send(:wait_for_anubis_challenge, page)).to be(true)
  end

  it 'stops at the browser timeout when Anubis remains unresolved' do
    page = instance_double(Ferrum::Browser)
    browser = browser_with_idle(timeout: 0.05)
    allow(browser).to receive(:safe_evaluate).and_return(
      { 'challenge' => true, 'document_ready' => true, 'body_present' => true, 'body_text_present' => true, 'url' => 'https://example.com/' }
    )
    allow(browser).to receive(:sleep)

    expect(browser.send(:wait_for_anubis_challenge, page)).to be(false)
  end

  it 'does not poll ordinary pages for challenge completion' do
    page = instance_double(Ferrum::Browser)
    browser = browser_with_idle
    allow(browser).to receive(:safe_evaluate).and_return(
      { 'challenge' => false, 'document_ready' => true, 'body_present' => true, 'body_text_present' => true, 'url' => 'https://example.com/' }
    )
    expect(browser).not_to receive(:retry_until_timeout)

    expect(browser.send(:wait_for_anubis_challenge, page)).to be(false)
  end
end
