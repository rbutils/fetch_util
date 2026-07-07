# frozen_string_literal: true

require 'spec_helper'

RSpec.describe FetchUtil::Browser do
  include_context 'browser spec helpers'

  it 'uses fast reddit stabilization instead of idle waits and cookie clicks' do
    network = instance_double('FerrumNetwork')
    ferrum = instance_double(Ferrum::Browser)
    page = instance_double('FerrumPage')

    stub_ferrum_page_creation(ferrum, page)
    stub_page_navigation(page)
    stub_page_network(page, network, wait_for_idle: true)
    allow(page).to receive(:at_xpath).and_return(nil)
    stub_page_evaluate_and_close(page, true)

    browser = browser_with_idle
    browser.with_page('https://www.reddit.com/r/ruby/comments/1') {}

    expect(network).not_to have_received(:wait_for_idle)
    expect(page).to have_received(:evaluate).at_least(:twice)
  end

  it 'uses ebay search stabilization instead of generic idle waits' do
    network = instance_double('FerrumNetwork')
    ferrum = instance_double(Ferrum::Browser)
    page = instance_double('FerrumPage')

    stub_ferrum_page_creation(ferrum, page)
    stub_page_navigation(page)
    stub_page_network(page, network, wait_for_idle: true)
    stub_page_evaluate_and_close(page, { 'clicked' => false, 'itemCount' => 4, 'challengeVisible' => false })

    browser = browser_with_idle
    browser.with_page('https://www.ebay.com/sch/i.html?_nkw=ruby+programming') {}

    expect(network).not_to have_received(:wait_for_idle)
    expect(page).to have_received(:evaluate).at_least(:once)
  end

  it 'waits for delayed Agora article bodies after generic stabilization' do
    page = instance_double(Ferrum::Browser)
    network = instance_double('FerrumNetwork')
    browser = browser_with_idle

    allow(page).to receive(:network).and_return(network)
    allow(network).to receive(:idle?).and_return(true)
    allow(network).to receive(:wait_for_idle)
    allow(browser).to receive(:wait_for_idle_or_content).with(page).and_return(true)
    allow(browser).to receive(:preserve_consent_wall?).with(page, 'https://kalisz.wyborcza.pl/kalisz/7,181359,32893183,example.html').and_return(false)
    allow(browser).to receive(:wait_for_spa_hydration).with(page)
    allow(browser).to receive(:accept_cookie_consent).with(page).and_return(false)
    allow(browser).to receive(:dismiss_privacy_preference_overlay).with(page).and_return(false)
    allow(browser).to receive(:sleep)
    expect(browser).to receive(:wait_for_agora_article).with(page, 'https://kalisz.wyborcza.pl/kalisz/7,181359,32893183,example.html')

    browser.send(:stabilize_page, page, 'https://kalisz.wyborcza.pl/kalisz/7,181359,32893183,example.html')
  end

  it 'configures reddit cookie dismissal through the shared overlay helper' do
    page = instance_double(Ferrum::Browser)
    allow(page).to receive(:evaluate).and_return(true)

    browser = browser_without_idle
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

    browser = browser_without_idle
    browser.send(:stabilize_ebay_search, page)

    expect(page).to have_received(:evaluate).with(include('accept all cookies'))
    expect(page).to have_received(:evaluate).with(include('input[type='))
  end

  it 'configures facebook cookie dismissal through the shared text-button helper' do
    page = instance_double(Ferrum::Browser)
    allow(page).to receive(:evaluate).and_return(true)

    browser = browser_without_idle
    expect(browser.send(:dismiss_facebook_cookie_dialog, page)).to eq(true)

    expect(page).to have_received(:evaluate) do |script|
      expect(script).to include('decline optional cookies')
      expect(script).to include('allow all cookies')
    end
  end

  it 'configures instagram login dismissal through the shared overlay helper' do
    page = instance_double(Ferrum::Browser)
    allow(page).to receive(:evaluate).and_return(true)

    browser = browser_without_idle
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

    browser = browser_without_idle
    expect(browser.send(:accept_instagram_cookie_dialog, page)).to eq(true)

    expect(page).to have_received(:evaluate) do |script|
      expect(script).to include('accept all cookies')
      expect(script).to include('allow all cookies')
    end
  end

  it 'uses a fixed post-overlay pause when wait is zero' do
    browser = browser_without_idle
    allow(browser).to receive(:sleep)

    browser.send(:social_login_phase_pause)

    expect(browser).to have_received(:sleep).with(0.3)
  end

  it 'reuses the shared settling helper for post-overlay pauses when wait is positive' do
    browser = browser_without_idle(wait: 0.75)
    allow(browser).to receive(:settle_after_stabilization)

    browser.send(:social_login_phase_pause)

    expect(browser).to have_received(:settle_after_stabilization).with(0.3)
  end

  it 'uses the shared post-overlay pause sequence for instagram stabilization' do
    page = instance_double(Ferrum::Browser)
    browser = browser_with_idle

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
    browser = browser_with_idle

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
