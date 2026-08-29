# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'extractor integration helpers' do
  include_context 'extractor integration helpers'

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
end
