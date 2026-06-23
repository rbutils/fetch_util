# frozen_string_literal: true

require 'spec_helper'

RSpec.describe FetchUtil::Browser do
  it 'retries navigation on PendingConnectionsError before raising' do
    network = instance_double('FerrumNetwork')
    ferrum = instance_double(Ferrum::Browser)
    page = instance_double('FerrumPage')

    allow(Ferrum::Browser).to receive(:new).and_return(ferrum)
    allow(ferrum).to receive(:evaluate_on_new_document)
    allow(ferrum).to receive(:create_page).and_return(page)
    allow(page).to receive(:headers).and_return(double(set: true))
    allow(page).to receive(:bypass_csp)
    call_count = 0
    allow(page).to receive(:go_to) do
      call_count += 1
      raise Ferrum::PendingConnectionsError, nil if call_count < 3
    end
    allow(page).to receive(:network).and_return(network)
    allow(network).to receive(:idle?).and_return(true)
    allow(network).to receive(:wait_for_idle)
    # page_loaded_enough? returns false on retries, then consent/stabilize evaluate calls return false
    allow(page).to receive(:evaluate).and_return(false)
    allow(page).to receive(:close)

    browser = described_class.new(browser_path: '/usr/bin/chromium', wait: 0, wait_for_idle: true)
    yielded = nil

    browser.with_page('https://example.com') { |result| yielded = result }

    expect(yielded).to eq(page)
    expect(call_count).to eq(3)
  end

  it 'raises after exhausting navigation retries' do
    ferrum = instance_double(Ferrum::Browser)
    page = instance_double('FerrumPage')

    allow(Ferrum::Browser).to receive(:new).and_return(ferrum)
    allow(ferrum).to receive(:evaluate_on_new_document)
    allow(ferrum).to receive(:create_page).and_return(page)
    allow(page).to receive(:headers).and_return(double(set: true))
    allow(page).to receive(:bypass_csp)
    allow(page).to receive(:go_to).and_raise(Ferrum::PendingConnectionsError.new(nil))
    # page_loaded_enough? always returns false
    allow(page).to receive(:evaluate).and_return(false)
    allow(page).to receive(:close)

    browser = described_class.new(browser_path: '/usr/bin/chromium', wait: 0, wait_for_idle: true)

    expect { browser.with_page('https://example.com') {} }.to raise_error(FetchUtil::BrowserError)
    expect(page).to have_received(:go_to).exactly(3).times
  end

  it 'continues after initial navigation timeout when page content already exists' do
    network = instance_double('FerrumNetwork')
    ferrum = instance_double(Ferrum::Browser)
    page = instance_double('FerrumPage')

    allow(Ferrum::Browser).to receive(:new).and_return(ferrum)
    allow(ferrum).to receive(:evaluate_on_new_document)
    allow(ferrum).to receive(:create_page).and_return(page)
    allow(page).to receive(:headers).and_return(double(set: true))
    allow(page).to receive(:bypass_csp)
    allow(page).to receive(:go_to).and_raise(Ferrum::TimeoutError)
    allow(page).to receive(:network).and_return(network)
    allow(network).to receive(:idle?).and_return(true)
    allow(network).to receive(:wait_for_idle)
    allow(page).to receive(:evaluate).and_return(true, false, false)
    allow(page).to receive(:close)

    browser = described_class.new(browser_path: '/usr/bin/chromium', wait: 0, wait_for_idle: true)
    yielded = nil

    browser.with_page('https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.31/#pod-v1-core') { |result| yielded = result }

    expect(yielded).to eq(page)
  end

  it 'treats stable page content as ready before network idle' do
    network = instance_double('FerrumNetwork', idle?: false)
    page = instance_double(Ferrum::Browser, network: network)
    browser = described_class.new(browser_path: '/usr/bin/chromium', wait: 0, wait_for_idle: true, idle_duration: 0)

    allow(page).to receive(:evaluate).and_return(true)

    expect(browser.send(:wait_for_idle_or_content, page)).to eq(true)
  end
end
