# frozen_string_literal: true

require 'spec_helper'

RSpec.describe FetchUtil::Browser do
  include_context 'browser spec helpers'

  it 'raises when no browser executable is available' do
    browser = described_class.new(browser_path: nil)
    browser.instance_variable_set(:@browser_path, nil)

    expect { browser.with_page('https://example.com') {} }.to raise_error(FetchUtil::BrowserError)
  end

  it 'requires a finite positive timeout' do
    [nil, '', 'invalid', 0, -1, Float::INFINITY, Float::NAN].each do |timeout|
      expect do
        described_class.new(timeout: timeout)
      end.to raise_error(ArgumentError, 'timeout must be positive')
    end
  end

  it 'preserves fractional timeout budgets' do
    browser = described_class.new(timeout: 0.25)

    expect(browser.instance_variable_get(:@timeout)).to eq(0.25)
  end

  it 'requires finite nonnegative wait durations' do
    %i[wait idle_duration].each do |name|
      [nil, '', 'invalid', -1, Float::INFINITY, Float::NAN].each do |duration|
        expect do
          described_class.new(name => duration)
        end.to raise_error(ArgumentError, "#{name} must be nonnegative")
      end
    end
  end

  it 'preserves zero and fractional wait durations' do
    browser = described_class.new(wait: 0, idle_duration: 0.125)

    expect(browser.instance_variable_get(:@wait)).to eq(0.0)
    expect(browser.instance_variable_get(:@idle_duration)).to eq(0.125)
  end

  it 'patches empty userAgentData values to a consistent browser profile' do
    browser = browser_without_idle
    script = browser.send(:navigator_patch)

    expect(script).to include('uaData.brands.length === 0')
    expect(script).to include('missingUserAgentData')
    expect(script).to include('platform: "Linux"')
    expect(script).to include('Google Chrome')
  end

  it 'owns one immutable browser identity for headers and navigator data' do
    user_agent = +'Mozilla/5.0 Chrome/123.4.5.6'
    accept_language = +'en-US,en;q=0.9'
    browser = described_class.new(user_agent: user_agent, accept_language: accept_language)

    user_agent.replace('changed')
    accept_language.replace('changed')

    headers = browser.instance_variable_get(:@default_headers)
    expect(headers).to include(
      'User-Agent' => 'Mozilla/5.0 Chrome/123.4.5.6',
      'Accept-Language' => 'en-US,en;q=0.9'
    )
    expect(headers.values_at('User-Agent', 'Accept-Language')).to all(be_frozen)
    expect(browser.send(:navigator_patch)).to include('123.4.5.6', '["en-US","en"]')
  end

  it 'owns the browser path used for lazy startup' do
    browser_path = +'/usr/bin/chromium'
    browser = described_class.new(browser_path: browser_path)
    ferrum = instance_double(Ferrum::Browser, evaluate_on_new_document: nil, quit: nil)

    browser_path.replace('/mutated/headless_shell')

    expect(Ferrum::Browser).to receive(:new).with(
      hash_including(
        browser_path: '/usr/bin/chromium',
        browser_options: hash_including('headless' => 'new', 'enable-automation' => false)
      )
    ).and_return(ferrum)

    browser.send(:ensure_browser)

    expect(browser.instance_variable_get(:@browser_path)).to eq('/usr/bin/chromium')
    expect(browser.instance_variable_get(:@browser_path)).to be_frozen
    expect(browser_path).not_to be_frozen
  ensure
    browser&.quit
  end

  it 'owns immutable browser options used for lazy startup' do
    key = +'proxy-server'
    value = +'http://proxy.example:8080'
    options = { key => value, 'nested' => [+'one', { +'two' => +'three' }] }
    browser = described_class.new(browser_path: '/usr/bin/chromium', browser_options: options)
    ferrum = instance_double(Ferrum::Browser, evaluate_on_new_document: nil, quit: nil)

    key.replace('changed-key')
    value.replace('changed-value')
    options.clear

    expect(Ferrum::Browser).to receive(:new).with(
      hash_including(
        browser_options: hash_including(
          'proxy-server' => 'http://proxy.example:8080',
          'nested' => ['one', { 'two' => 'three' }]
        )
      )
    ).and_return(ferrum)

    browser.send(:ensure_browser)

    owned_options = browser.instance_variable_get(:@browser_options)
    expect(owned_options).to be_frozen
    expect(owned_options['proxy-server']).to be_frozen
    expect(owned_options['nested']).to be_frozen
    expect(owned_options['nested'].first).to be_frozen
    expect(owned_options['nested'].last).to be_frozen
    expect(owned_options['nested'].last.keys + owned_options['nested'].last.values).to all(be_frozen)
    expect(options).not_to be_frozen
  ensure
    browser&.quit
  end

  it 'normalizes non-ascii urls before navigation' do
    browser = browser_without_idle
    ferrum = instance_double(Ferrum::Browser)
    page = instance_double('FerrumPage')

    stub_ferrum_page_creation(ferrum, page)
    allow(browser).to receive(:ensure_browser).and_return(ferrum)
    allow(page).to receive(:headers).and_return(double(set: true))
    allow(page).to receive(:bypass_csp)
    allow(page).to receive(:close)
    allow(browser).to receive(:stabilize_page)
    allow(browser).to receive(:heavy_script_page?).and_return(false)

    normalized_url = 'https://ja.wikipedia.org/wiki/%E6%97%A5%E6%9C%AC'

    expect(page).to receive(:go_to).with(normalized_url)

    browser.with_page('https://ja.wikipedia.org/wiki/日本') {}
  end

  it 'reuses the browser process across multiple with_page calls' do
    ferrum = instance_double(Ferrum::Browser)
    page1 = instance_double('FerrumPage1')
    page2 = instance_double('FerrumPage2')

    stub_ferrum_page_creation(ferrum, page1, page2)

    [page1, page2].each do |page|
      stub_page_navigation(page)
      stub_page_network(page, instance_double('FerrumNetwork', idle?: true))
      stub_page_evaluate_and_close(page, false)
    end

    browser = browser_with_idle

    results = []
    browser.with_page('https://example.com') { |p| results << p }
    browser.with_page('https://example.org') { |p| results << p }

    expect(results).to eq([page1, page2])
    expect(Ferrum::Browser).to have_received(:new).once
    expect(ferrum).to have_received(:create_page).twice
    expect(page1).to have_received(:close).once
    expect(page2).to have_received(:close).once
  end

  it 'discards a browser whose navigator setup fails' do
    failed_ferrum = instance_double(Ferrum::Browser)
    fresh_ferrum = instance_double(Ferrum::Browser)
    fresh_page = instance_double('FreshFerrumPage')

    allow(Ferrum::Browser).to receive(:new).and_return(failed_ferrum, fresh_ferrum)
    allow(failed_ferrum).to receive(:evaluate_on_new_document)
      .and_raise(Ferrum::Error, 'navigator setup failed')
    allow(failed_ferrum).to receive(:quit)
    allow(fresh_ferrum).to receive(:evaluate_on_new_document)
    allow(fresh_ferrum).to receive(:create_page).and_return(fresh_page)
    stub_page_navigation(fresh_page)
    stub_page_network(fresh_page, instance_double('FerrumNetwork', idle?: true))
    stub_page_evaluate_and_close(fresh_page, false)

    browser = browser_with_idle

    expect do
      browser.with_page('https://example.com') {}
    end.to raise_error(FetchUtil::BrowserError, 'navigator setup failed')

    expect(browser.with_page('https://example.org') { |page| page }).to equal(fresh_page)
    expect(failed_ferrum).to have_received(:quit).once
    expect(Ferrum::Browser).to have_received(:new).twice
  end

  it 'preserves a successful result when page cleanup fails' do
    browser = browser_without_idle
    page = instance_double('FerrumPage')

    allow(browser).to receive(:ensure_browser).and_return(instance_double(Ferrum::Browser))
    allow(browser).to receive(:load_page_with_retry).and_return(page)
    allow(browser).to receive(:heavy_script_page?).and_return(false)
    allow(page).to receive(:close).and_raise(Ferrum::Error, 'close failed')

    expect(browser.with_page('https://example.com') { :result }).to eq(:result)
  end

  it 'preserves a block error when page cleanup also fails' do
    browser = browser_without_idle
    page = instance_double('FerrumPage')

    allow(browser).to receive(:ensure_browser).and_return(instance_double(Ferrum::Browser))
    allow(browser).to receive(:load_page_with_retry).and_return(page)
    allow(browser).to receive(:heavy_script_page?).and_return(false)
    allow(page).to receive(:close).and_raise(Ferrum::Error, 'close failed')

    expect do
      browser.with_page('https://example.com') { raise 'block failed' }
    end.to raise_error(RuntimeError, 'block failed')
  end

  it 'shuts down the browser process on quit' do
    ferrum = instance_double(Ferrum::Browser)
    page = instance_double('FerrumPage')

    stub_ferrum_page_creation(ferrum, page)
    allow(ferrum).to receive(:quit)
    stub_page_navigation(page)
    stub_page_network(page, instance_double('FerrumNetwork', idle?: true))
    stub_page_evaluate_and_close(page, false)

    browser = browser_with_idle
    browser.with_page('https://example.com') {}
    browser.quit

    expect(ferrum).to have_received(:quit).once
  end

  it 'launches a fresh browser after shutdown fails' do
    stale_ferrum = instance_double(Ferrum::Browser)
    fresh_ferrum = instance_double(Ferrum::Browser)
    stale_page = instance_double('StaleFerrumPage')
    fresh_page = instance_double('FreshFerrumPage')

    allow(Ferrum::Browser).to receive(:new).and_return(stale_ferrum, fresh_ferrum)
    allow(stale_ferrum).to receive(:evaluate_on_new_document)
    allow(fresh_ferrum).to receive(:evaluate_on_new_document)
    allow(stale_ferrum).to receive(:create_page).and_return(stale_page)
    allow(fresh_ferrum).to receive(:create_page).and_return(fresh_page)
    allow(stale_ferrum).to receive(:quit).and_raise(Ferrum::Error, 'shutdown failed')

    [stale_page, fresh_page].each do |page|
      stub_page_navigation(page)
      stub_page_network(page, instance_double('FerrumNetwork', idle?: true))
      stub_page_evaluate_and_close(page, false)
    end

    browser = browser_with_idle
    browser.with_page('https://example.com') {}

    expect { browser.quit }.to raise_error(Ferrum::Error, 'shutdown failed')
    expect(browser.with_page('https://example.org') { |page| page }).to equal(fresh_page)
    expect(Ferrum::Browser).to have_received(:new).twice
  end

  it 'is safe to call quit without any prior with_page calls' do
    browser = browser_without_idle
    expect { browser.quit }.not_to raise_error
  end
end
