# frozen_string_literal: true

require 'spec_helper'

RSpec.describe FetchUtil::Browser do
  include_context 'browser spec helpers'

  it 'retries full navigation once when pending connections hit network idle' do
    ferrum = instance_double(Ferrum::Browser)
    page1 = instance_double('FerrumPage')
    page2 = instance_double('FerrumPage')
    network1 = instance_double('FerrumNetwork')
    network2 = instance_double('FerrumNetwork')

    stub_ferrum_page_creation(ferrum, page1, page2)
    stub_page_navigation(page1)
    stub_page_navigation(page2)
    stub_page_network(page1, network1, idle: true, wait_for_idle: true)
    stub_page_network(page2, network2, idle: true, wait_for_idle: true)
    allow(page1).to receive(:evaluate).and_return(false)
    allow(page2).to receive(:evaluate).and_return(false)
    allow(page1).to receive(:close)
    allow(page2).to receive(:close)
    browser = browser_with_idle
    allow(browser).to receive(:sleep)
    allow(browser).to receive(:accept_cookie_consent).and_return(true)
    allow(browser).to receive(:dismiss_privacy_preference_overlay).and_return(false)
    allow(browser).to receive(:wait_for_spa_hydration).and_return(true)
    allow(browser).to receive(:heavy_script_page?).and_return(false)
    allow(network1).to receive(:wait_for_idle).and_raise(
      Ferrum::PendingConnectionsError,
      'Request to https://example.com reached server, but there are still pending connections'
    )
    allow(network2).to receive(:wait_for_idle).and_return(true)

    yielded = nil

    browser.with_page('https://example.com') { |result| yielded = result }

    expect(yielded).to be(page2)
    expect(ferrum).to have_received(:create_page).twice
  end

  it 'bubbles pending connections from network idle without retrying them' do
    network = instance_double('FerrumNetwork')
    page = instance_double('FerrumPage')
    browser = browser_with_idle
    call_count = 0

    allow(page).to receive(:network).and_return(network)
    allow(network).to receive(:wait_for_idle) do
      call_count += 1
      raise Ferrum::PendingConnectionsError, 'Request to https://example.com reached server, but there are still pending connections'
    end

    expect { browser.send(:wait_for_network_idle, page) }.to raise_error(Ferrum::PendingConnectionsError)
    expect(call_count).to eq(1)
  end

  it 'retries pending-connection navigation errors twice before giving up' do
    ferrum = instance_double(Ferrum::Browser)
    page1 = instance_double('FerrumPage')
    page2 = instance_double('FerrumPage')
    page3 = instance_double('FerrumPage')

    stub_ferrum_page_creation(ferrum, page1, page2, page3)
    stub_page_navigation(page1)
    stub_page_navigation(page2)
    stub_page_navigation(page3)
    allow(page1).to receive(:go_to).and_raise(Ferrum::PendingConnectionsError.new(nil))
    allow(page2).to receive(:go_to).and_raise(Ferrum::PendingConnectionsError.new(nil))
    allow(page3).to receive(:go_to).and_raise(Ferrum::PendingConnectionsError.new(nil))
    allow(page1).to receive(:close)
    allow(page2).to receive(:close)
    allow(page3).to receive(:close)

    browser = browser_with_idle
    allow(browser).to receive(:sleep)
    allow(browser).to receive(:heavy_script_page?).and_return(false)

    expect { browser.with_page('https://example.com') {} }.to raise_error(FetchUtil::BrowserError)
    expect(page1).to have_received(:go_to).once
    expect(page2).to have_received(:go_to).once
    expect(page3).to have_received(:go_to).once
  end

  it 'settles briefly before extraction on heavy-script pages' do
    page = instance_double('FerrumPage')
    browser = browser_with_idle

    allow(browser).to receive(:ensure_browser).and_return(instance_double(Ferrum::Browser))
    allow(browser).to receive(:load_page_with_retry).and_return(page)
    allow(browser).to receive(:heavy_script_page?).and_return(true)
    allow(page).to receive(:close)
    allow(browser).to receive(:sleep)

    yielded = nil

    browser.with_page('https://example.com') { |result| yielded = result }

    expect(browser).to have_received(:sleep).with(FetchUtil::Browser::PRE_EXTRACTION_SETTLE_WAIT)
    expect(yielded).to be(page)
  end

  it 'continues after initial navigation timeout when page content already exists' do
    network = instance_double('FerrumNetwork')
    ferrum = instance_double(Ferrum::Browser)
    page = instance_double('FerrumPage')

    stub_ferrum_page_creation(ferrum, page)
    allow(page).to receive(:headers).and_return(double(set: true))
    allow(page).to receive(:bypass_csp)
    allow(page).to receive(:go_to).and_raise(Ferrum::TimeoutError)
    stub_page_network(page, network, idle: true, wait_for_idle: true)
    allow(page).to receive(:evaluate).and_return(true, false, false)
    allow(page).to receive(:close)

    browser = browser_with_idle
    allow(browser).to receive(:heavy_script_page?).and_return(false)
    yielded = nil

    browser.with_page('https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.31/#pod-v1-core') { |result| yielded = result }

    expect(yielded).to eq(page)
  end

  it 'does not retry DNS failures' do
    ferrum = instance_double(Ferrum::Browser)
    page = instance_double('FerrumPage')

    stub_ferrum_page_creation(ferrum, page)
    stub_page_navigation(page)
    allow(page).to receive(:go_to).and_raise(Ferrum::Error, 'Request https://missing.example.test/ failed (net::ERR_NAME_NOT_RESOLVED)')
    allow(page).to receive(:close)

    browser = browser_with_idle

    expect { browser.with_page('https://missing.example.test/') {} }.to raise_error(FetchUtil::BrowserError)
    expect(page).to have_received(:go_to).once
  end

  it 'treats stable page content as ready before network idle' do
    network = instance_double('FerrumNetwork', idle?: false)
    page = instance_double(Ferrum::Browser, network: network)
    browser = browser_with_idle(idle_duration: 0)

    allow(page).to receive(:evaluate).and_return(true)

    expect(browser.send(:wait_for_idle_or_content, page)).to eq(true)
  end
end
