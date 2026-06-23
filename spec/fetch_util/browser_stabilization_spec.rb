# frozen_string_literal: true

require 'spec_helper'

RSpec.describe FetchUtil::Browser do
  it 'uses fast reddit stabilization instead of idle waits and cookie clicks' do
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
    allow(network).to receive(:wait_for_idle)
    allow(page).to receive(:at_xpath).and_return(nil)
    allow(page).to receive(:evaluate).and_return(true)
    allow(page).to receive(:close)

    browser = described_class.new(browser_path: '/usr/bin/chromium', wait: 0, wait_for_idle: true)
    browser.with_page('https://www.reddit.com/r/ruby/comments/1') {}

    expect(network).not_to have_received(:wait_for_idle)
    expect(page).to have_received(:evaluate).at_least(:twice)
  end

  it 'uses ebay search stabilization instead of generic idle waits' do
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
    allow(network).to receive(:wait_for_idle)
    allow(page).to receive(:evaluate).and_return({ 'clicked' => false, 'itemCount' => 4, 'challengeVisible' => false })
    allow(page).to receive(:close)

    browser = described_class.new(browser_path: '/usr/bin/chromium', wait: 0, wait_for_idle: true)
    browser.with_page('https://www.ebay.com/sch/i.html?_nkw=ruby+programming') {}

    expect(network).not_to have_received(:wait_for_idle)
    expect(page).to have_received(:evaluate).at_least(:once)
  end

  it 'configures reddit cookie dismissal through the shared overlay helper' do
    page = instance_double(Ferrum::Browser)
    allow(page).to receive(:evaluate).and_return(true)

    browser = described_class.new(browser_path: '/usr/bin/chromium', wait: 0)
    expect(browser.send(:dismiss_reddit_cookie_dialog, page)).to eq(true)

    expect(page).to have_received(:evaluate).with(include('before you continue to reddit'))
    expect(page).to have_received(:evaluate).with(include('shreddit-experience-tree'))
  end

  it 'reuses the shared text-button helper for ebay cookie acceptance' do
    page = instance_double(Ferrum::Browser)
    allow(page).to receive(:evaluate) do |script|
      if script.include?('labelGroups')
        false
      else
        { 'itemCount' => 4, 'challengeVisible' => false }
      end
    end

    browser = described_class.new(browser_path: '/usr/bin/chromium', wait: 0)
    browser.send(:stabilize_ebay_search, page)

    expect(page).to have_received(:evaluate).with(include('accept all cookies'))
    expect(page).to have_received(:evaluate).with(include('input[type='))
  end

  it 'configures facebook cookie dismissal through the shared text-button helper' do
    page = instance_double(Ferrum::Browser)
    allow(page).to receive(:evaluate).and_return(true)

    browser = described_class.new(browser_path: '/usr/bin/chromium', wait: 0)
    expect(browser.send(:dismiss_facebook_cookie_dialog, page)).to eq(true)

    expect(page).to have_received(:evaluate) do |script|
      expect(script).to include('decline optional cookies')
      expect(script).to include('allow all cookies')
    end
  end

  it 'configures instagram login dismissal through the shared overlay helper' do
    page = instance_double(Ferrum::Browser)
    allow(page).to receive(:evaluate).and_return(true)

    browser = described_class.new(browser_path: '/usr/bin/chromium', wait: 0)
    expect(browser.send(:dismiss_instagram_login_modal, page)).to eq(true)

    expect(page).to have_received(:evaluate) do |script|
      expect(script).to include('allowEmptyCloseLabel')
      expect(script).to include('don.?t have an account')
      expect(script).to include('^(?:close|dismiss|x|×)?$')
      expect(script).to include('position: fixed')
      expect(script).to include('withinMatchingNode')
    end
  end

  it 'configures instagram cookie acceptance through the shared text-button helper' do
    page = instance_double(Ferrum::Browser)
    allow(page).to receive(:evaluate).and_return(true)

    browser = described_class.new(browser_path: '/usr/bin/chromium', wait: 0)
    expect(browser.send(:accept_instagram_cookie_dialog, page)).to eq(true)

    expect(page).to have_received(:evaluate) do |script|
      expect(script).to include('accept all cookies')
      expect(script).to include('allow all cookies')
    end
  end

  it 'uses a fixed post-overlay pause when wait is zero' do
    browser = described_class.new(browser_path: '/usr/bin/chromium', wait: 0)
    allow(browser).to receive(:sleep)

    browser.send(:social_login_phase_pause)

    expect(browser).to have_received(:sleep).with(0.3)
  end

  it 'reuses the shared settling helper for post-overlay pauses when wait is positive' do
    browser = described_class.new(browser_path: '/usr/bin/chromium', wait: 0.75)
    allow(browser).to receive(:settle_after_stabilization)

    browser.send(:social_login_phase_pause)

    expect(browser).to have_received(:settle_after_stabilization).with(0.3)
  end

  it 'uses the shared post-overlay pause sequence for instagram stabilization' do
    page = instance_double(Ferrum::Browser)
    browser = described_class.new(browser_path: '/usr/bin/chromium', wait: 0, wait_for_idle: true)

    expect(browser).to receive(:wait_for_idle_or_content).with(page).ordered
    expect(browser).to receive(:accept_instagram_cookie_dialog).with(page).ordered.and_return(true)
    expect(browser).to receive(:social_login_phase_pause).ordered
    expect(browser).to receive(:accept_instagram_cookie_dialog).with(page).ordered.and_return(true)
    expect(browser).to receive(:retry_until_timeout).with(5.0).ordered.and_yield
    expect(browser).to receive(:dismiss_instagram_login_modal).with(page).ordered.and_return(true)
    expect(browser).to receive(:social_login_phase_pause).ordered
    expect(browser).to receive(:dismiss_instagram_login_modal).with(page).ordered.and_return(true)

    browser.send(:stabilize_instagram, page)
  end

  it 'uses the shared post-overlay pause sequence for facebook stabilization' do
    page = instance_double(Ferrum::Browser)
    browser = described_class.new(browser_path: '/usr/bin/chromium', wait: 0, wait_for_idle: true)

    expect(browser).to receive(:wait_for_idle_or_content).with(page).ordered
    expect(browser).to receive(:social_login_phase_pause).ordered
    expect(browser).to receive(:dismiss_facebook_cookie_dialog).with(page).ordered
    expect(browser).to receive(:social_login_phase_pause).ordered
    expect(browser).to receive(:retry_until_timeout).with(5.0).ordered.and_yield
    expect(browser).to receive(:dismiss_facebook_login_dialog).with(page).ordered.and_return(true)
    expect(browser).to receive(:social_login_phase_pause).ordered

    browser.send(:stabilize_facebook, page)
  end
end
