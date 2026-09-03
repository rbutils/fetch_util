# frozen_string_literal: true

require 'spec_helper'

RSpec.describe FetchUtil::Browser do
  it 'clips retry sleeps to the remaining poll budget' do
    browser = described_class.new(browser_path: '/usr/bin/chromium')
    now = 100.0
    sleeps = []
    attempts = 0
    allow(browser).to receive(:monotonic_now) { now }
    allow(browser).to receive(:sleep) do |duration|
      sleeps << duration
      now += duration
    end

    result = browser.send(:retry_until_timeout, 0.05, interval: 0.2) do
      attempts += 1
      false
    end

    expect(result).to be(false)
    expect(attempts).to eq(1)
    expect(sleeps.length).to eq(1)
    expect(sleeps.first).to be_within(0.0001).of(0.05)
  end

  it 'makes one exact-boundary observation without sleeping again' do
    browser = described_class.new(browser_path: '/usr/bin/chromium')
    times = [100.0, 100.001]
    allow(browser).to receive(:monotonic_now) { times.shift || 100.001 }
    expect(browser).not_to receive(:sleep)
    attempts = 0

    result = browser.send(:retry_until_timeout, 0, deadline: 100.0) do
      attempts += 1
      false
    end

    expect(result).to be(false)
    expect(attempts).to eq(1)
  end

  it 'rejects readiness observed after the poll deadline' do
    browser = described_class.new(browser_path: '/usr/bin/chromium')
    now = 100.0
    allow(browser).to receive(:monotonic_now) { now }

    result = browser.send(:retry_until_timeout, 0.05) do
      now += 0.06
      true
    end

    expect(result).to be(false)
  end

  it 'shares one deadline across generic stabilization phases' do
    page = instance_double(Ferrum::Browser)
    browser = described_class.new(
      browser_path: '/usr/bin/chromium', timeout: 1.0, wait: 0.6, wait_for_idle: true
    )
    now = 100.0
    sleeps = []
    deadlines = []
    allow(browser).to receive(:monotonic_now) { now }
    allow(browser).to receive(:sleep) do |duration|
      sleeps << duration
      now += duration
    end
    allow(browser).to receive(:wait_for_anubis_challenge) do |_page, deadline:|
      deadlines << deadline
      now += 0.3
      false
    end
    allow(browser).to receive(:wait_for_idle_or_content) do |_page, deadline:|
      deadlines << deadline
      now += 0.3
      true
    end
    allow(browser).to receive(:preserve_consent_wall?).and_return(false)
    allow(browser).to receive(:dismiss_cookie_overlays).and_return(true, false)
    allow(browser).to receive(:wait_for_spa_hydration) { |_page, deadline:| deadlines << deadline }
    allow(browser).to receive(:skip_generic_interaction?).and_return(true)
    allow(browser).to receive(:wait_for_network_idle) { |_page, deadline:| deadlines << deadline }
    allow(browser).to receive(:prune_unsatisfied_images)
    allow(page).to receive(:evaluate).and_return(true)

    browser.send(:stabilize_page, page, 'https://example.test/article')

    expect(deadlines).to all(be_within(0.0001).of(101.0))
    expect(sleeps.sum).to be_within(0.0001).of(0.4)
    expect(now).to be_within(0.0001).of(101.0)
    expect(browser).not_to have_received(:wait_for_spa_hydration)
    expect(browser).not_to have_received(:wait_for_network_idle)
  end

  it 'clips final network idle sleeps to the remaining stabilization budget' do
    page = instance_double(Ferrum::Browser)
    network = instance_double('FerrumNetwork')
    browser = described_class.new(
      browser_path: '/usr/bin/chromium', timeout: 1.0, idle_duration: 0.1
    )
    now = 10.95
    sleeps = []
    allow(browser).to receive(:monotonic_now) { now }
    allow(browser).to receive(:sleep) do |duration|
      sleeps << duration
      now += duration
    end
    allow(page).to receive(:network).and_return(network)
    expect(network).to receive(:idle?).once.and_return(false)

    expect(browser.send(:wait_for_network_idle, page, deadline: 11.0)).to be(false)
    expect(sleeps.length).to eq(1)
    expect(sleeps.first).to be_within(0.0001).of(0.05)
  end

  it 'requires a continuous quiet interval before accepting network idle' do
    page = instance_double(Ferrum::Browser)
    network = instance_double('FerrumNetwork')
    browser = described_class.new(
      browser_path: '/usr/bin/chromium', timeout: 1.0, idle_duration: 0.1
    )
    now = 10.0
    allow(browser).to receive(:monotonic_now) { now }
    allow(browser).to receive(:sleep) { |duration| now += duration }
    allow(page).to receive(:network).and_return(network)
    expect(network).to receive(:idle?).twice.and_return(true)

    expect(browser.send(:wait_for_network_idle, page, deadline: 11.0)).to be(true)
    expect(now).to be_within(0.0001).of(10.1)
  end

  it 'stops generic phases after a blocking observation exhausts the deadline' do
    page = instance_double(Ferrum::Browser)
    browser = described_class.new(browser_path: '/usr/bin/chromium', timeout: 1.0)
    now = 20.0
    allow(browser).to receive(:monotonic_now) { now }
    allow(browser).to receive(:wait_for_anubis_challenge) { now = 21.1 }
    allow(browser).to receive(:wait_for_idle_or_content)

    expect(browser.send(:stabilize_page, page, 'https://example.test/article')).to be(false)
    expect(browser).not_to have_received(:wait_for_idle_or_content)
  end

  it 'does not start a social interaction after the shared deadline expires' do
    page = instance_double(Ferrum::Browser)
    browser = described_class.new(browser_path: '/usr/bin/chromium', timeout: 1.0)
    now = 30.0
    allow(browser).to receive(:monotonic_now) { now }
    allow(browser).to receive(:wait_for_idle_or_content) { now = 31.1 }
    allow(browser).to receive(:accept_instagram_cookie_dialog)

    expect(browser.send(:stabilize_instagram, page, deadline: 31.0)).to be(false)
    expect(browser).not_to have_received(:accept_instagram_cookie_dialog)
  end

  it 'marks timed-out Gerrit preparation as failed before falling through' do
    page = instance_double(Ferrum::Browser)
    browser = described_class.new(browser_path: '/usr/bin/chromium', timeout: 1.0)
    state = { 'product' => true, 'status' => 'loading' }
    allow(browser).to receive(:monotonic_now).and_return(50.0)
    allow(browser).to receive(:gerrit_change_state).and_return(state)
    allow(browser).to receive(:fail_gerrit_change_preparation)

    expect(browser.send(:stabilize_gerrit_change, page, deadline: 50.0)).to be(false)
    expect(browser).to have_received(:fail_gerrit_change_preparation).with(page)
  end

  it 'guards timed-out asynchronous forge preparation from late completion' do
    browser = described_class.new(browser_path: '/usr/bin/chromium')
    bitbucket = browser.send(:bitbucket_cloud_pull_diff_state_script)
    gerrit_change = browser.send(:gerrit_change_request_state_script)
    gerrit_file = browser.send(:gerrit_file_resource_request_state_script)

    expect(bitbucket).to include(
      "window.__fetchUtilBitbucketPullDiff !== prepared || prepared.status !== 'loading'"
    )
    expect(gerrit_change).to include(
      'window[stateKey] !== prepared || prepared.status !== "loading"'
    )
    expect(gerrit_file.scan('window[stateKey] !== prepared || prepared.status !== "loading"').length).to eq(3)
  end
end
