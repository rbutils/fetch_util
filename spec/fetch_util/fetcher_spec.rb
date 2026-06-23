# frozen_string_literal: true

require 'spec_helper'

RSpec.describe FetchUtil::Fetcher do
  include_context 'fetcher spec helpers'

  it 'returns a result object with metadata' do
    stub_browser_extraction('https://example.com/input', page: page, payload: payload)

    result = fetch_with_dependencies('https://example.com/input')

    expect(result).to be_a(FetchUtil::Result)
    expect(result.title).to eq('Example title')
    expect(result.final_url).to eq('https://example.com/final')
    expect(result.metadata).to include(
      content_url: 'https://example.com/final',
      canonical_url: 'https://example.com/article',
      reader_mode: true,
      content_type: 'article',
      suspect: false,
      warnings: []
    )
    expect(result.content_type).to eq('article')
    expect(result.suspect).to eq(false)
  end

  it 'uses the top-level convenience method' do
    fetcher = instance_double(described_class)
    result = instance_double(FetchUtil::Result)

    allow(described_class).to receive(:new).with(timeout: 10).and_return(fetcher)
    allow(fetcher).to receive(:fetch).with('https://example.com').and_return(result)

    expect(FetchUtil.fetch('https://example.com', timeout: 10)).to eq(result)
  end

  it 'surfaces extractor mismatch warnings as suspect' do
    mismatched_payload = payload.merge(
      'title' => 'returning multiple values in python',
      'markdown' => 'A python question about map reduce.',
      'excerpt' => 'A python question',
      'warnings' => ['url_content_mismatch']
    )

    stub_browser_extraction(
      'https://stackoverflow.com/questions/14818673/what-is-the-difference-between-proc-and-lambda-in-ruby',
      page: page, payload: mismatched_payload
    )

    result = fetch_with_dependencies('https://stackoverflow.com/questions/14818673/what-is-the-difference-between-proc-and-lambda-in-ruby')

    expect(result.suspect).to eq(true)
    expect(result.warnings).to include('url_content_mismatch')
  end

  it 'does not recompute url mismatches that the extractor did not emit' do
    so_page = instance_double('FerrumPage', current_url: 'https://stackoverflow.com/questions/14818673/what-is-the-difference-between-proc-and-lambda-in-ruby')
    mismatched_payload = payload.merge(
      'title' => 'returning multiple values in python',
      'markdown' => 'A python question about map reduce.',
      'excerpt' => 'A python question',
      'warnings' => []
    )

    stub_browser_extraction(
      'https://stackoverflow.com/questions/14818673/what-is-the-difference-between-proc-and-lambda-in-ruby',
      page: so_page, payload: mismatched_payload
    )

    result = fetch_with_dependencies('https://stackoverflow.com/questions/14818673/what-is-the-difference-between-proc-and-lambda-in-ruby')

    expect(result.suspect).to eq(false)
    expect(result.warnings).not_to include('url_content_mismatch')
  end

  it 'does not flag docs reference pages as url mismatches' do
    docs_page = instance_double('FerrumPage', current_url: 'https://developers.openai.com/api/reference/resources/chat')
    docs_payload = payload.merge(
      'title' => 'Chat',
      'markdown' => "# Chat\n\nGiven a list of messages comprising a conversation, the model will return a response.",
      'contentType' => 'article',
      'warnings' => []
    )

    stub_browser_extraction('https://developers.openai.com/api/reference/resources/chat', page: docs_page, payload: docs_payload)

    result = fetch_with_dependencies('https://developers.openai.com/api/reference/resources/chat')

    expect(result.warnings).not_to include('url_content_mismatch')
  end

  it 'does not flag structured docs articles as url mismatches even when url terms differ from section titles' do
    docs_page = instance_double('FerrumPage', current_url: 'https://pinia.vuejs.org/core-concepts/')
    docs_payload = payload.merge(
      'title' => 'Defining a Store',
      'excerpt' => 'Intuitive, type safe, light and flexible Store for Vue',
      'markdown' => <<~MARKDOWN.chomp,
        # Defining a Store

        Intuitive, type safe, light and flexible Store for Vue.

        ## Setup Stores

        Use `defineStore()` to create a setup store.

        ```ts
        export const useStore = defineStore('main', () => {})
        ```
      MARKDOWN
      'contentType' => 'article',
      'warnings' => []
    )

    stub_browser_extraction('https://pinia.vuejs.org/core-concepts/', page: docs_page, payload: docs_payload)

    result = fetch_with_dependencies('https://pinia.vuejs.org/core-concepts/')

    expect(result.warnings).not_to include('url_content_mismatch')
  end

  it 'does not flag ncbi books reference pages as url mismatches' do
    docs_page = instance_double('FerrumPage', current_url: 'https://www.ncbi.nlm.nih.gov/books/NBK553156/')
    docs_payload = payload.merge(
      'title' => 'Intra-abdominal and Pelvic Swellings',
      'markdown' => "# Intra-abdominal and Pelvic Swellings\n\nThe diagnosis of abdominal swellings follows careful clinical evaluation.",
      'contentType' => 'article',
      'warnings' => []
    )

    stub_browser_extraction('https://www.ncbi.nlm.nih.gov/books/NBK553156/', page: docs_page, payload: docs_payload)

    result = fetch_with_dependencies('https://www.ncbi.nlm.nih.gov/books/NBK553156/')

    expect(result.warnings).not_to include('url_content_mismatch')
  end

  it 'does not flag query-driven dictionary translation pages as url mismatches' do
    glossary_page = instance_double('FerrumPage', current_url: 'https://www.diki.pl/slownik-angielskiego?q=whores')
    glossary_payload = payload.merge(
      'title' => 'whore potocznie *',
      'excerpt' => 'whore - tlumaczenie na polski oraz definicja. Co znaczy i jak powiedziec whore po polsku? - zdzira, dziwka, kurwa; prostytutka',
      'markdown' => <<~MARKDOWN.chomp,
        # whore potocznie *

        whore - tlumaczenie na polski oraz definicja. Co znaczy i jak powiedziec whore po polsku? - zdzira, dziwka, kurwa; prostytutka
      MARKDOWN
      'contentType' => 'article',
      'warnings' => []
    )

    stub_browser_extraction('https://www.diki.pl/slownik-angielskiego?q=whores', page: glossary_page, payload: glossary_payload)

    result = fetch_with_dependencies('https://www.diki.pl/slownik-angielskiego?q=whores')

    expect(result.warnings).not_to include('url_content_mismatch')
  end

  it 'does not flag substantial non-latin article content as a url mismatch' do
    page = instance_double('FerrumPage', current_url: 'https://example.com/final')
    cjk_payload = payload.merge(
      'language' => 'zh-CN',
      'title' => '推进中国式现代化',
      'excerpt' => '理论研究持续深化。',
      'markdown' => '# 推进中国式现代化\n\n建设哲学社会科学体系，推进中国式现代化理论研究不断深化，形成更多高质量成果。文化传承与创新协同推进，教育改革持续展开。',
      'warnings' => []
    )

    stub_browser_extraction('https://www.cssn.cn/skgz/bwyc/202412/t20241225_5826232.shtml', page: page, payload: cjk_payload)

    result = fetch_with_dependencies('https://www.cssn.cn/skgz/bwyc/202412/t20241225_5826232.shtml')

    expect(result.warnings).not_to include('url_content_mismatch')
  end

  it 'delegates quit to the underlying browser' do
    allow(browser).to receive(:quit)

    fetcher = described_class.new(browser: browser, extractor: extractor, raw_docs_fallback: raw_docs_fallback)
    fetcher.quit

    expect(browser).to have_received(:quit).once
  end

  it 'logs each fetch with duration to the request log' do
    log = instance_double(FetchUtil::RequestLog)
    allow(log).to receive(:append)
    stub_browser_extraction('https://example.com/input', page: page, payload: payload)

    fetch_with_dependencies('https://example.com/input', request_log: log)

    expect(log).to have_received(:append).with('https://example.com/input', duration: a_value >= 0)
  end

  it 'logs duration even when fetch raises' do
    log = instance_double(FetchUtil::RequestLog)
    allow(log).to receive(:append)
    allow(browser).to receive(:with_page).and_raise(FetchUtil::BrowserError, 'boom')

    expect do
      fetch_with_dependencies('https://nonexistent.example', request_log: log)
    end.to raise_error(FetchUtil::BrowserError)

    expect(log).to have_received(:append).with('https://nonexistent.example', duration: a_value >= 0)
  end
end
