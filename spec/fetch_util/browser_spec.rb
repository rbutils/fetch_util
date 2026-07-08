# frozen_string_literal: true

require 'spec_helper'

RSpec.describe FetchUtil::Browser do
  include_context 'browser spec helpers'

  it 'raises when no browser executable is available' do
    browser = described_class.new(browser_path: nil)
    browser.instance_variable_set(:@browser_path, nil)

    expect { browser.with_page('https://example.com') {} }.to raise_error(FetchUtil::BrowserError)
  end

  it 'patches empty userAgentData values to a consistent browser profile' do
    browser = browser_without_idle
    script = browser.send(:navigator_patch)

    expect(script).to include('uaData.brands.length === 0')
    expect(script).to include('missingUserAgentData')
    expect(script).to include('platform: "Linux"')
    expect(script).to include('Google Chrome')
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

  it 'is safe to call quit without any prior with_page calls' do
    browser = browser_without_idle
    expect { browser.quit }.not_to raise_error
  end
end
