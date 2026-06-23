# frozen_string_literal: true

require 'spec_helper'

RSpec.describe FetchUtil::Browser do
  it 'accepts visible cookie prompts by default before yielding' do
    network = instance_double('FerrumNetwork')
    ferrum = instance_double(Ferrum::Browser)
    page = instance_double('FerrumPage')

    allow(Ferrum::Browser).to receive(:new).and_return(ferrum)
    allow(ferrum).to receive(:evaluate_on_new_document)
    allow(ferrum).to receive(:create_page).and_return(page)
    allow(page).to receive(:headers).and_return(double(set: true))
    allow(page).to receive(:bypass_csp)
    allow(page).to receive(:go_to)
    allow(page).to receive(:network).and_return(network)
    allow(network).to receive(:idle?).and_return(true)
    allow(network).to receive(:wait_for_idle)
    allow(page).to receive(:evaluate).and_return(true)
    allow(page).to receive(:close)

    browser = described_class.new(browser_path: '/usr/bin/chromium', wait: 0, wait_for_idle: true)
    yielded = nil

    browser.with_page('https://example.com') { |result| yielded = result }

    expect(yielded).to eq(page)
    expect(page).to have_received(:evaluate).with(include('consentContext')).at_least(:once)
    expect(network).to have_received(:wait_for_idle).once
  end

  it 'does not perform a second idle wait when no cookie prompt was accepted' do
    network = instance_double('FerrumNetwork')
    ferrum = instance_double(Ferrum::Browser)
    page = instance_double('FerrumPage')

    allow(Ferrum::Browser).to receive(:new).and_return(ferrum)
    allow(ferrum).to receive(:evaluate_on_new_document)
    allow(ferrum).to receive(:create_page).and_return(page)
    allow(page).to receive(:headers).and_return(double(set: true))
    allow(page).to receive(:bypass_csp)
    allow(page).to receive(:go_to)
    allow(page).to receive(:network).and_return(network)
    allow(network).to receive(:idle?).and_return(true)
    allow(network).to receive(:wait_for_idle)
    allow(page).to receive(:evaluate).and_return(false)
    allow(page).to receive(:close)

    browser = described_class.new(browser_path: '/usr/bin/chromium', wait: 0, wait_for_idle: true)
    browser.with_page('https://example.com') {}

    expect(network).not_to have_received(:wait_for_idle)
  end

  it 'retries cookie acceptance after spa hydration on generic pages' do
    network = instance_double('FerrumNetwork')
    page = instance_double(Ferrum::Browser, network: network)
    browser = described_class.new(browser_path: '/usr/bin/chromium', wait: 0, wait_for_idle: true)

    allow(browser).to receive(:wait_for_idle_or_content).and_return(true)
    allow(browser).to receive(:preserve_consent_wall?).and_return(false)
    allow(browser).to receive(:accept_cookie_consent).and_return(false, false, true)
    allow(browser).to receive(:dismiss_privacy_preference_overlay).and_return(false)
    allow(browser).to receive(:wait_for_spa_hydration)
    allow(network).to receive(:wait_for_idle)

    browser.send(:stabilize_page, page, 'https://example.com')

    expect(browser).to have_received(:accept_cookie_consent).exactly(3).times
    expect(browser).to have_received(:wait_for_spa_hydration).once
    expect(network).to have_received(:wait_for_idle).once
  end

  it 'does not count hidden consent templates as handled overlays' do
    page = instance_double(Ferrum::Browser)
    allow(page).to receive(:evaluate).and_return(false)

    browser = described_class.new(browser_path: '/usr/bin/chromium', wait: 0)
    expect(browser.send(:accept_cookie_consent, page)).to eq(false)

    expect(page).to have_received(:evaluate) do |script|
      # Phase 1: dialog/modal elements check visibility
      expect(script).to include('if (!visible(el)) continue;')
      # No aria-hidden or display-none shortcuts that could miscount
      expect(script).not_to include("style.display === 'none'")
      expect(script).not_to include("style.visibility === 'hidden'")
      expect(script).not_to include("el.getAttribute('aria-hidden') === 'true'")
    end
  end

  it 'searches open shadow roots when accepting generic cookie prompts' do
    page = instance_double(Ferrum::Browser)
    allow(page).to receive(:evaluate).and_return(false)

    browser = described_class.new(browser_path: '/usr/bin/chromium', wait: 0)
    expect(browser.send(:accept_cookie_consent, page)).to eq(false)

    expect(page).to have_received(:evaluate) do |script|
      expect(script).to include('el.shadowRoot')
      expect(script).to include('parentOrHost')
      expect(script).to include('akkoord')
    end
  end

  it 'includes Amharic accept and privacy cues in the generic consent helper' do
    page = instance_double(Ferrum::Browser)
    allow(page).to receive(:evaluate).and_return(false)

    browser = described_class.new(browser_path: '/usr/bin/chromium', wait: 0)
    expect(browser.send(:accept_cookie_consent, page)).to eq(false)

    expect(page).to have_received(:evaluate) do |script|
      expect(script).to include('ተቀበል')
      expect(script).to include('ግላዊነት')
    end
  end

  it 'includes Czech consent cues in the generic consent helper' do
    page = instance_double(Ferrum::Browser)
    allow(page).to receive(:evaluate).and_return(false)

    browser = described_class.new(browser_path: '/usr/bin/chromium', wait: 0)
    expect(browser.send(:accept_cookie_consent, page)).to eq(false)

    expect(page).to have_received(:evaluate) do |script|
      expect(script).to include('pro pokračování vyberte')
      expect(script).to include('technické cookies')
      expect(script).to include('pokračovat')
    end
  end

  it 'includes generic privacy-center and cookie-information cues in the consent helper' do
    page = instance_double(Ferrum::Browser)
    allow(page).to receive(:evaluate).and_return(false)

    browser = described_class.new(browser_path: '/usr/bin/chromium', wait: 0)
    expect(browser.send(:accept_cookie_consent, page)).to eq(false)

    expect(page).to have_received(:evaluate) do |script|
      expect(script).to include('privacy preference center')
      expect(script).to include('cookie information')
      expect(script).to include('confirm my choices')
    end
  end

  it 'includes Portuguese consent cues and a body-led fallback in the generic consent helper' do
    page = instance_double(Ferrum::Browser)
    allow(page).to receive(:evaluate).and_return(false)

    browser = described_class.new(browser_path: '/usr/bin/chromium', wait: 0)
    expect(browser.send(:accept_cookie_consent, page)).to eq(false)

    expect(page).to have_received(:evaluate) do |script|
      expect(script).to include('bodyLooksLikeConsent')
      expect(script).to include('configurações avançadas de cookies')
      expect(script).to include('gerenciar cookies')
      expect(script).to include('aceitar cookies')
    end
  end

  it 'tries common privacy-preference action labels when a privacy overlay is present' do
    page = instance_double(Ferrum::Browser)
    browser = described_class.new(browser_path: '/usr/bin/chromium', wait: 0)

    allow(browser).to receive(:safe_evaluate).and_return(true)
    allow(browser).to receive(:click_visible_button_by_text).and_return(true)

    expect(browser.send(:dismiss_privacy_preference_overlay, page)).to eq(true)
    expect(browser).to have_received(:click_visible_button_by_text).with(
      page,
      include('Accept All', 'Allow all', 'Confirm My Choices', 'Save preferences', 'Customize Choices'),
      include('Essential only', 'Reject All'),
      selectors: 'button, [role="button"], a, input[type="button"], input[type="submit"]'
    )
  end

  it 'preserves google consent prompts instead of auto-accepting them' do
    network = instance_double('FerrumNetwork')
    ferrum = instance_double(Ferrum::Browser)
    page = instance_double('FerrumPage')

    allow(Ferrum::Browser).to receive(:new).and_return(ferrum)
    allow(ferrum).to receive(:evaluate_on_new_document)
    allow(ferrum).to receive(:create_page).and_return(page)
    allow(page).to receive(:headers).and_return(double(set: true))
    allow(page).to receive(:bypass_csp)
    allow(page).to receive(:go_to)
    allow(page).to receive(:network).and_return(network)
    allow(network).to receive(:idle?).and_return(true)
    allow(network).to receive(:wait_for_idle)
    allow(page).to receive(:close)
    allow(page).to receive(:evaluate) do |script|
      if script.include?('title: document.title')
        { 'title' => 'Before you continue to Google', 'text' => 'We use cookies and data. Accept all. Reject all.' }
      elsif script.include?('__NEXT_DATA__') || script.include?('__reactFiber')
        # SPA framework detection / hydration check — return nil (no SPA detected)
        nil
      else
        raise 'unexpected cookie click evaluation'
      end
    end

    browser = described_class.new(browser_path: '/usr/bin/chromium', wait: 0, wait_for_idle: true)
    browser.with_page('https://www.google.com/webhp?hl=en') {}

    expect(network).not_to have_received(:wait_for_idle)
  end

  it 'falls back cleanly when consent evaluation times out on a heavy page' do
    network = instance_double('FerrumNetwork')
    ferrum = instance_double(Ferrum::Browser)
    page = instance_double('FerrumPage')

    allow(Ferrum::Browser).to receive(:new).and_return(ferrum)
    allow(ferrum).to receive(:evaluate_on_new_document)
    allow(ferrum).to receive(:create_page).and_return(page)
    allow(page).to receive(:headers).and_return(double(set: true))
    allow(page).to receive(:bypass_csp)
    allow(page).to receive(:go_to)
    allow(page).to receive(:network).and_return(network)
    allow(network).to receive(:idle?).and_return(true)
    allow(network).to receive(:wait_for_idle)
    allow(page).to receive(:evaluate).and_raise(Ferrum::TimeoutError)
    allow(page).to receive(:close)

    browser = described_class.new(browser_path: '/usr/bin/chromium', wait: 0, wait_for_idle: true)
    browser.with_page('https://example.com') {}

    expect(network).not_to have_received(:wait_for_idle)
  end
end
