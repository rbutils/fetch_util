# frozen_string_literal: true

require 'spec_helper'

RSpec.describe FetchUtil::Browser do
  include_context 'browser spec helpers'

  it 'retries navigation on PendingConnectionsError before raising' do
    network = instance_double('FerrumNetwork')
    ferrum = instance_double(Ferrum::Browser)
    page = instance_double('FerrumPage')

    stub_ferrum_page_creation(ferrum, page)
    allow(page).to receive(:headers).and_return(double(set: true))
    allow(page).to receive(:bypass_csp)
    call_count = 0
    allow(page).to receive(:go_to) do
      call_count += 1
      raise Ferrum::PendingConnectionsError, nil if call_count < 3
    end
    stub_page_network(page, network, idle: true, wait_for_idle: true)
    # page_loaded_enough? returns false on retries, then consent/stabilize evaluate calls return false
    allow(page).to receive(:evaluate).and_return(false)
    allow(page).to receive(:close)

    browser = browser_with_idle
    yielded = nil

    browser.with_page('https://example.com') { |result| yielded = result }

    expect(yielded).to eq(page)
    expect(call_count).to eq(3)
  end

  it 'raises after exhausting navigation retries' do
    ferrum = instance_double(Ferrum::Browser)
    page = instance_double('FerrumPage')

    stub_ferrum_page_creation(ferrum, page)
    allow(page).to receive(:headers).and_return(double(set: true))
    allow(page).to receive(:bypass_csp)
    allow(page).to receive(:go_to).and_raise(Ferrum::PendingConnectionsError.new(nil))
    # page_loaded_enough? always returns false
    allow(page).to receive(:evaluate).and_return(false)
    allow(page).to receive(:close)

    browser = browser_with_idle

    expect { browser.with_page('https://example.com') {} }.to raise_error(FetchUtil::BrowserError)
    expect(page).to have_received(:go_to).exactly(3).times
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
    yielded = nil

    browser.with_page('https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.31/#pod-v1-core') { |result| yielded = result }

    expect(yielded).to eq(page)
  end

  it 'retries browser-level network errors before giving up' do
    network = instance_double('FerrumNetwork')
    ferrum = instance_double(Ferrum::Browser)
    page = instance_double('FerrumPage')

    stub_ferrum_page_creation(ferrum, page)
    allow(page).to receive(:headers).and_return(double(set: true))
    allow(page).to receive(:bypass_csp)
    stub_page_network(page, network, idle: true, wait_for_idle: true)
    call_count = 0
    allow(page).to receive(:go_to) do
      call_count += 1
      raise Ferrum::Error, 'Request https://missing.example.test/ failed (net::ERR_NAME_NOT_RESOLVED)' if call_count < 2
    end
    allow(page).to receive(:evaluate).and_return(false)
    allow(page).to receive(:close)

    browser = browser_with_idle
    yielded = nil

    browser.with_page('https://missing.example.test/') { |result| yielded = result }

    expect(yielded).to eq(page)
    expect(call_count).to eq(2)
  end

  it 'treats stable page content as ready before network idle' do
    network = instance_double('FerrumNetwork', idle?: false)
    page = instance_double(Ferrum::Browser, network: network)
    browser = browser_with_idle(idle_duration: 0)

    allow(page).to receive(:evaluate).and_return(true)

    expect(browser.send(:wait_for_idle_or_content, page)).to eq(true)
  end
end
