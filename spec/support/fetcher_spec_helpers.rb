# frozen_string_literal: true

RSpec.shared_context 'fetcher spec helpers' do
  def stub_browser_extraction(url, page:, payload:)
    allow(browser).to receive(:with_page).with(url).and_yield(page)
    allow(extractor).to receive(:extract).with(page).and_return(payload)
  end

  def stub_browser_failure(url, error_class, message)
    allow(browser).to receive(:with_page).with(url).and_raise(error_class, message)
  end

  def stub_raw_docs_fallback(request_url, payload:, final_url: request_url)
    allow(raw_docs_fallback).to receive(:fetch).with(request_url).and_return([final_url, payload])
  end

  def fetch_with_dependencies(url, **options)
    described_class.new(
      browser: browser, extractor: extractor, raw_docs_fallback: raw_docs_fallback, **options
    ).fetch(url)
  end
end
