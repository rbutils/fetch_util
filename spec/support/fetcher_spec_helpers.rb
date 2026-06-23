# frozen_string_literal: true

RSpec.shared_context 'fetcher spec helpers' do
  let(:page) do
    instance_double('FerrumPage', current_url: 'https://example.com/final')
  end

  let(:browser) do
    instance_double(FetchUtil::Browser)
  end

  let(:extractor) do
    instance_double(FetchUtil::Extractor)
  end

  let(:raw_docs_fallback) do
    instance_double(FetchUtil::RawDocsFallback, fetch: nil)
  end

  let(:payload) do
    {
      'title' => 'Example title',
      'byline' => 'Jane Author',
      'excerpt' => 'Short summary',
      'siteName' => 'Example',
      'publishedTime' => '2026-03-22T10:00:00Z',
      'canonicalUrl' => 'https://example.com/article',
      'language' => 'en',
      'html' => '<p>Hello</p>',
      'markdown' => 'Hello',
      'readerMode' => true,
      'contentType' => 'article',
      'suspect' => false,
      'warnings' => []
    }
  end

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
