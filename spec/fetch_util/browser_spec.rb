# frozen_string_literal: true

require 'spec_helper'

RSpec.describe FetchUtil::Browser do
  it 'raises when no browser executable is available' do
    browser = described_class.new(browser_path: nil)
    browser.instance_variable_set(:@browser_path, nil)

    expect { browser.with_page('https://example.com') {} }.to raise_error(FetchUtil::BrowserError)
  end

  it 'patches empty userAgentData values to a consistent browser profile' do
    browser = described_class.new(browser_path: '/usr/bin/chromium', wait: 0)
    script = browser.send(:navigator_patch)

    expect(script).to include('uaData.brands.length === 0')
    expect(script).to include('missingUserAgentData')
    expect(script).to include('platform: "Linux"')
    expect(script).to include('Google Chrome')
  end

  it 'reuses the browser process across multiple with_page calls' do
    ferrum = instance_double(Ferrum::Browser)
    page1 = instance_double('FerrumPage1')
    page2 = instance_double('FerrumPage2')

    allow(Ferrum::Browser).to receive(:new).and_return(ferrum)
    allow(ferrum).to receive(:evaluate_on_new_document)
    allow(ferrum).to receive(:create_page).and_return(page1, page2)

    [page1, page2].each do |page|
      allow(page).to receive(:headers).and_return(double(set: true))
      allow(page).to receive(:bypass_csp)
      allow(page).to receive(:go_to)
      allow(page).to receive(:network).and_return(instance_double('FerrumNetwork', idle?: true))
      allow(page).to receive(:evaluate).and_return(false)
      allow(page).to receive(:close)
    end

    browser = described_class.new(browser_path: '/usr/bin/chromium', wait: 0, wait_for_idle: true)

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

    allow(Ferrum::Browser).to receive(:new).and_return(ferrum)
    allow(ferrum).to receive(:evaluate_on_new_document)
    allow(ferrum).to receive(:create_page).and_return(page)
    allow(ferrum).to receive(:quit)
    allow(page).to receive(:headers).and_return(double(set: true))
    allow(page).to receive(:bypass_csp)
    allow(page).to receive(:go_to)
    allow(page).to receive(:network).and_return(instance_double('FerrumNetwork', idle?: true))
    allow(page).to receive(:evaluate).and_return(false)
    allow(page).to receive(:close)

    browser = described_class.new(browser_path: '/usr/bin/chromium', wait: 0, wait_for_idle: true)
    browser.with_page('https://example.com') {}
    browser.quit

    expect(ferrum).to have_received(:quit).once
  end

  it 'is safe to call quit without any prior with_page calls' do
    browser = described_class.new(browser_path: '/usr/bin/chromium', wait: 0)
    expect { browser.quit }.not_to raise_error
  end
end
