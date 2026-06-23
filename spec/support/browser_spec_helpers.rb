# frozen_string_literal: true

RSpec.shared_context 'browser spec helpers' do
  def browser_with_idle(**options)
    described_class.new(browser_path: '/usr/bin/chromium', wait: 0, wait_for_idle: true, **options)
  end

  def browser_without_idle(**options)
    described_class.new(browser_path: '/usr/bin/chromium', wait: 0, **options)
  end

  def stub_ferrum_page_creation(ferrum, *pages)
    allow(Ferrum::Browser).to receive(:new).and_return(ferrum)
    allow(ferrum).to receive(:evaluate_on_new_document)
    allow(ferrum).to receive(:create_page).and_return(*pages)
  end

  def stub_page_navigation(page)
    allow(page).to receive(:headers).and_return(double(set: true))
    allow(page).to receive(:bypass_csp)
    allow(page).to receive(:go_to)
  end

  def stub_page_network(page, network, idle: nil, wait_for_idle: nil)
    allow(page).to receive(:network).and_return(network)
    allow(network).to receive(:idle?).and_return(idle) unless idle.nil?
    allow(network).to receive(:wait_for_idle) unless wait_for_idle.nil?
  end

  def stub_page_evaluate_and_close(page, result)
    allow(page).to receive(:evaluate).and_return(result)
    allow(page).to receive(:close)
  end
end
