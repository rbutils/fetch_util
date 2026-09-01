# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'extractor integration helpers' do
  include_context 'extractor integration helpers'

  it 'quits the browser when closing the cached page fails' do
    configuration = Object.new
    page = instance_double(Ferrum::Page)
    browser = instance_double(Ferrum::Browser)
    configuration.instance_variable_set(:@fetch_util_extractor_page, page)
    configuration.instance_variable_set(:@fetch_util_extractor_browser, browser)
    allow(page).to receive(:close).and_raise(Ferrum::Error, 'page close failed')
    expect(browser).to receive(:quit)

    expect { FetchUtil::ExtractorIntegrationResources.close(configuration) }.not_to raise_error
    expect(configuration.instance_variable_defined?(:@fetch_util_extractor_page)).to be(false)
    expect(configuration.instance_variable_defined?(:@fetch_util_extractor_browser)).to be(false)
  end

  it 'disables request interception after serving a URL fixture' do
    network = instance_double(Ferrum::Network)
    page = instance_double(Ferrum::Page, network: network)

    allow(self).to receive(:with_extractor_page).and_yield(page)
    allow(network).to receive(:intercept).with(pattern: '*')
    allow(page).to receive(:on).with(:request).and_return(17)
    allow(page).to receive(:go_to).with('https://example.test/article')
    expect(page).to receive(:command).with('Fetch.disable').ordered
    expect(page).to receive(:off).with(:request, 17).ordered

    with_url_page('https://example.test/article', '<p>Fixture</p>') { |yielded| expect(yielded).to be(page) }
  end

  it 'preserves fixture failures when interception cleanup fails' do
    network = instance_double(Ferrum::Network)
    page = instance_double(Ferrum::Page, network: network)

    allow(self).to receive(:with_extractor_page).and_yield(page)
    allow(network).to receive(:intercept).with(pattern: '*')
    allow(page).to receive(:on).with(:request).and_return(23)
    allow(page).to receive(:go_to).with('https://example.test/article')
    allow(page).to receive(:command).with('Fetch.disable').and_raise(Ferrum::Error, 'cleanup failed')
    allow(RSpec.configuration).to receive(:instance_variable_get)
      .with(:@fetch_util_extractor_page).and_return(page)
    expect(RSpec.configuration).to receive(:remove_instance_variable).with(:@fetch_util_extractor_page)
    expect(page).to receive(:close)

    expect do
      with_url_page('https://example.test/article', '<p>Fixture</p>') { raise 'fixture failed' }
    end.to raise_error(RuntimeError, 'fixture failed')
  end

  it 'discards the cached page when removing its request handler fails' do
    network = instance_double(Ferrum::Network)
    page = instance_double(Ferrum::Page, network: network)

    allow(self).to receive(:with_extractor_page).and_yield(page)
    allow(network).to receive(:intercept).with(pattern: '*')
    allow(page).to receive(:on).with(:request).and_return(29)
    allow(page).to receive(:go_to).with('https://example.test/article')
    allow(page).to receive(:command).with('Fetch.disable')
    allow(page).to receive(:off).with(:request, 29).and_raise(Ferrum::Error, 'cleanup failed')
    allow(RSpec.configuration).to receive(:instance_variable_get)
      .with(:@fetch_util_extractor_page).and_return(page)
    expect(RSpec.configuration).to receive(:remove_instance_variable).with(:@fetch_util_extractor_page)
    expect(page).to receive(:close)

    with_url_page('https://example.test/article', '<p>Fixture</p>') { |yielded| expect(yielded).to be(page) }
  end

  it 'requires Chromium for browser integration coverage by default' do
    allow(self).to receive(:browser_path).and_return(nil)
    allow(ENV).to receive(:[]).with('FETCH_UTIL_ALLOW_MISSING_CHROMIUM').and_return(nil)

    expect { required_browser_path }
      .to raise_error(RuntimeError, 'Chromium not available; set FETCH_UTIL_ALLOW_MISSING_CHROMIUM=1 to skip browser integration examples')
  end

  it 'uses the configured browser path before discovered candidates' do
    path = '/custom/chromium'
    allow(RSpec.configuration).to receive(:instance_variable_defined?)
      .with(:@fetch_util_browser_path).and_return(false)
    expect(RSpec.configuration).to receive(:instance_variable_set)
      .with(:@fetch_util_browser_path, path).and_return(path)
    allow(ENV).to receive(:[]).with('BROWSER_PATH').and_return(path)
    expect(File).not_to receive(:executable?)

    expect(browser_path).to eq(path)
  end

  it 'leaves configured path validation to the browser runtime' do
    path = '/missing/chromium'
    allow(RSpec.configuration).to receive(:instance_variable_defined?)
      .with(:@fetch_util_browser_path).and_return(false)
    expect(RSpec.configuration).to receive(:instance_variable_set)
      .with(:@fetch_util_browser_path, path).and_return(path)
    allow(ENV).to receive(:[]).with('BROWSER_PATH').and_return(path)
    expect(File).not_to receive(:executable?)

    expect(browser_path).to eq(path)
  end

  it 'memoizes unavailable browser discovery' do
    allow(RSpec.configuration).to receive(:instance_variable_defined?)
      .with(:@fetch_util_browser_path).and_return(false, true)
    expect(RSpec.configuration).to receive(:instance_variable_set)
      .with(:@fetch_util_browser_path, nil).once.and_return(nil)
    allow(RSpec.configuration).to receive(:instance_variable_get)
      .with(:@fetch_util_browser_path).and_return(nil)
    allow(ENV).to receive(:[]).with('BROWSER_PATH').and_return(nil)
    allow(File).to receive(:executable?).and_return(false)

    expect(browser_path).to be_nil
    expect(browser_path).to be_nil
  end

  it 'allows an explicit local opt-out when Chromium is unavailable' do
    allow(self).to receive(:browser_path).and_return(nil)
    allow(ENV).to receive(:[]).with('FETCH_UTIL_ALLOW_MISSING_CHROMIUM').and_return('1')
    allow(self).to receive(:skip).and_return(:skipped)

    expect(required_browser_path).to eq(:skipped)
    expect(self).to have_received(:skip).with('Chromium not available (FETCH_UTIL_ALLOW_MISSING_CHROMIUM=1)')
  end
end
