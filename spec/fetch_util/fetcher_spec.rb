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

  it 'builds one payload snapshot for Ruby finalization' do
    snapshot_class = described_class.const_get(:PayloadSnapshot)
    allow(snapshot_class).to receive(:new).and_call_original
    stub_browser_extraction('https://example.com/input', page: page, payload: payload)

    fetch_with_dependencies('https://example.com/input')

    expect(snapshot_class).to have_received(:new).once.with(
      payload: payload,
      requested_url: 'https://example.com/input',
      final_url: 'https://example.com/final',
      canonical_url: 'https://example.com/article',
      raw_final_url: 'https://example.com/final',
      raw_canonical_url: 'https://example.com/article'
    )
  end

  it 'uses the top-level convenience method' do
    fetcher = instance_double(described_class)
    result = instance_double(FetchUtil::Result)

    allow(described_class).to receive(:new).with(timeout: 10).and_return(fetcher)
    allow(fetcher).to receive(:fetch).with('https://example.com').and_return(result)

    expect(FetchUtil.fetch('https://example.com', timeout: 10)).to eq(result)
  end

  it 'surfaces extractor mismatch warnings as suspect' do
    mismatched_payload = payload_with(
      title: 'returning multiple values in python',
      markdown: 'A python question about map reduce.',
      excerpt: 'A python question',
      warnings: ['url_content_mismatch']
    )

    stub_browser_extraction(
      'https://stackoverflow.com/questions/14818673/what-is-the-difference-between-proc-and-lambda-in-ruby',
      page: page, payload: mismatched_payload
    )

    result = fetch_with_dependencies('https://stackoverflow.com/questions/14818673/what-is-the-difference-between-proc-and-lambda-in-ruby')

    expect(result.suspect).to eq(true)
    expect(result.warnings).to include('url_content_mismatch')
  end

  it 'flags auth redirects from browse paths as login interstitials' do
    login_page = page_at('https://readthedocs.org/accounts/login/')
    login_payload = payload_with(
      title: 'Log in - Read the Docs Community',
      markdown: <<~MARKDOWN.chomp,
        # Log in - Read the Docs Community

        Read the Docs supports GitHub OAuth app login for connected accounts.
      MARKDOWN
      excerpt: 'Connect your GitHub account.',
      contentType: 'list',
      warnings: []
    )

    stub_browser_extraction('https://readthedocs.org/projects/', page: login_page, payload: login_payload)

    result = fetch_with_dependencies('https://readthedocs.org/projects/')

    expect(result.suspect).to eq(true)
    expect(result.warnings).to include('auth_or_login_interstitial')
  end

  it 'does not flag direct login paths as unexpected auth interstitials' do
    login_page = page_at('https://example.com/login/')
    login_payload = payload_with(
      title: 'Log in - Example',
      markdown: '# Log in - Example\n\nUse your account password.',
      warnings: []
    )

    stub_browser_extraction('https://example.com/login/', page: login_page, payload: login_payload)

    result = fetch_with_dependencies('https://example.com/login/')

    expect(result.warnings).not_to include('auth_or_login_interstitial')
  end

  it 'falls back to public HTML when Novinky redirects headless Chrome to Seznam CMP' do
    url = 'https://www.novinky.cz/clanek/domaci-zemrel-namestek-ministryne-pro-mistni-rozvoj-endal-40586881'
    cmp_page = page_at('https://cmp.seznam.cz/nastaveni-souhlasu?service=bcr&return_url=https%3A%2F%2Fwww.novinky.cz%2Fclanek%2Fdomaci-zemrel-namestek-ministryne-pro-mistni-rozvoj-endal-40586881%3Fcwreturn%3D1')
    cmp_payload = payload_with(
      title: 'Nastavení souhlasu s personalizací',
      canonicalUrl: 'https://cmp.seznam.cz/nastaveni-souhlasu',
      markdown: '# Nastavení souhlasu s personalizací\n\nTechnical details: Unable to load CMP script.',
      warnings: []
    )
    article_payload = payload_with(
      title: 'Zemřel náměstek ministryně pro místní rozvoj Endal',
      canonicalUrl: url,
      markdown: 'Ve věku 51 let zemřel náměstek ministryně pro místní rozvoj Filip Endal.',
      warnings: []
    )

    stub_browser_extraction(url, page: cmp_page, payload: cmp_payload)
    stub_raw_docs_fallback(url, payload: article_payload)

    result = fetch_with_dependencies(url)

    expect(result.final_url).to eq(url)
    expect(result.content_type).to eq('article')
    expect(result.markdown).to include('Filip Endal')
    expect(result.warnings).not_to include('cross_domain_redirect')
    expect(result.warnings).not_to include('consent_interstitial')
  end

  it 'flags specific DOI content paths redirected to generic node pages as not found' do
    node_page = page_at('https://www.biorxiv.org/node/')
    node_payload = payload_with(
      title: '| bioRxiv',
      canonicalUrl: 'https://www.biorxiv.org/node',
      markdown: <<~MARKDOWN.chomp,
        - [Editorial Board](https://www.biorxiv.org/content/editorial-board)
        - [Institutions](https://www.biorxiv.org/content/institutions)
        - [Advertisers](https://www.biorxiv.org/content/advertisers)
      MARKDOWN
      contentType: 'list',
      warnings: []
    )

    stub_browser_extraction('https://www.biorxiv.org/content/10.1101/2021.01.01.425000v1', page: node_page, payload: node_payload)

    result = fetch_with_dependencies('https://www.biorxiv.org/content/10.1101/2021.01.01.425000v1')

    expect(result.content_type).to eq('list')
    expect(result.suspect).to eq(true)
    expect(result.warnings).to include('not_found_interstitial')
  end

  it 'does not flag valid DOI content paths that resolve to matching article pages' do
    article_page = page_at('https://www.biorxiv.org/content/10.1101/2024.01.01.123456v1')
    article_payload = payload_with(
      title: 'A live preprint title',
      canonicalUrl: 'https://www.biorxiv.org/content/10.1101/2024.01.01.123456v1',
      markdown: '# A live preprint title\n\nThis preprint reports a complete article abstract and methods summary.',
      contentType: 'article',
      warnings: []
    )

    stub_browser_extraction('https://www.biorxiv.org/content/10.1101/2024.01.01.123456v1', page: article_page, payload: article_payload)

    result = fetch_with_dependencies('https://www.biorxiv.org/content/10.1101/2024.01.01.123456v1')

    expect(result.content_type).to eq('article')
    expect(result.suspect).to eq(false)
    expect(result.warnings).not_to include('not_found_interstitial')
  end

  it 'does not recompute url mismatches that the extractor did not emit' do
    so_page = page_at('https://stackoverflow.com/questions/14818673/what-is-the-difference-between-proc-and-lambda-in-ruby')
    mismatched_payload = payload_with(
      title: 'returning multiple values in python',
      markdown: 'A python question about map reduce.',
      excerpt: 'A python question',
      warnings: []
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
    docs_page = page_at('https://developers.openai.com/api/reference/resources/chat')
    docs_payload = payload_with(
      title: 'Chat',
      markdown: "# Chat\n\nGiven a list of messages comprising a conversation, the model will return a response.",
      contentType: 'article',
      warnings: []
    )

    stub_browser_extraction('https://developers.openai.com/api/reference/resources/chat', page: docs_page, payload: docs_payload)

    result = fetch_with_dependencies('https://developers.openai.com/api/reference/resources/chat')

    expect(result.warnings).not_to include('url_content_mismatch')
  end

  it 'does not flag structured docs articles as url mismatches even when url terms differ from section titles' do
    docs_page = page_at('https://pinia.vuejs.org/core-concepts/')
    docs_payload = payload_with(
      title: 'Defining a Store',
      excerpt: 'Intuitive, type safe, light and flexible Store for Vue',
      markdown: <<~MARKDOWN.chomp,
        # Defining a Store

        Intuitive, type safe, light and flexible Store for Vue.

        ## Setup Stores

        Use `defineStore()` to create a setup store.

        ```ts
        export const useStore = defineStore('main', () => {})
        ```
      MARKDOWN
      contentType: 'article',
      warnings: []
    )

    stub_browser_extraction('https://pinia.vuejs.org/core-concepts/', page: docs_page, payload: docs_payload)

    result = fetch_with_dependencies('https://pinia.vuejs.org/core-concepts/')

    expect(result.warnings).not_to include('url_content_mismatch')
  end

  it 'does not flag ncbi books reference pages as url mismatches' do
    docs_page = page_at('https://www.ncbi.nlm.nih.gov/books/NBK553156/')
    docs_payload = payload_with(
      title: 'Intra-abdominal and Pelvic Swellings',
      markdown: "# Intra-abdominal and Pelvic Swellings\n\nThe diagnosis of abdominal swellings follows careful clinical evaluation.",
      contentType: 'article',
      warnings: []
    )

    stub_browser_extraction('https://www.ncbi.nlm.nih.gov/books/NBK553156/', page: docs_page, payload: docs_payload)

    result = fetch_with_dependencies('https://www.ncbi.nlm.nih.gov/books/NBK553156/')

    expect(result.warnings).not_to include('url_content_mismatch')
  end

  it 'does not flag query-driven dictionary translation pages as url mismatches' do
    glossary_page = page_at('https://www.diki.pl/slownik-angielskiego?q=whores')
    glossary_payload = payload_with(
      title: 'whore potocznie *',
      excerpt: 'whore - tlumaczenie na polski oraz definicja. Co znaczy i jak powiedziec whore po polsku? - zdzira, dziwka, kurwa; prostytutka',
      markdown: <<~MARKDOWN.chomp,
        # whore potocznie *

        whore - tlumaczenie na polski oraz definicja. Co znaczy i jak powiedziec whore po polsku? - zdzira, dziwka, kurwa; prostytutka
      MARKDOWN
      contentType: 'article',
      warnings: []
    )

    stub_browser_extraction('https://www.diki.pl/slownik-angielskiego?q=whores', page: glossary_page, payload: glossary_payload)

    result = fetch_with_dependencies('https://www.diki.pl/slownik-angielskiego?q=whores')

    expect(result.warnings).not_to include('url_content_mismatch')
  end

  it 'does not flag substantial non-latin article content as a url mismatch' do
    page = page_at('https://example.com/final')
    cjk_payload = payload_with(
      language: 'zh-CN',
      title: '推进中国式现代化',
      excerpt: '理论研究持续深化。',
      markdown: '# 推进中国式现代化\n\n建设哲学社会科学体系，推进中国式现代化理论研究不断深化，形成更多高质量成果。文化传承与创新协同推进，教育改革持续展开。',
      warnings: []
    )

    stub_browser_extraction('https://www.cssn.cn/skgz/bwyc/202412/t20241225_5826232.shtml', page: page, payload: cjk_payload)

    result = fetch_with_dependencies('https://www.cssn.cn/skgz/bwyc/202412/t20241225_5826232.shtml')

    expect(result.warnings).not_to include('url_content_mismatch')
  end

  it 'keeps long legal judgments on view paths classified as articles' do
    page = page_at('https://www.example.test/cgi-bin/viewdoc/au/cases/cth/HCA/1992/23.html')
    paragraphs = (1..18).map do |i|
      "The High Court considered Mabo v Queensland and explained the reasons for judgment. " \
        "The appellant and respondent addressed counsel on native title, Crown sovereignty, and common law. " \
        "The reasons mention government services, citizens, business licences, and public permits as background context. " \
        "Paragraph #{i} is continuous judicial reasoning rather than a result index."
    end.join("\n\n")
    judgment_payload = payload_with(
      title: 'Mabo v Queensland (No 2) [1992] HCA 23',
      markdown: <<~MARKDOWN.chomp,
        # Mabo v Queensland (No 2) [1992] HCA 23

        ## HIGH COURT OF AUSTRALIA

        MABO AND OTHERS v. QUEENSLAND (No. 2) [1992] HCA 23; (1992) 175 CLR 1

        - [High Court judgment 1](https://www.example.test/au/cases/cth/HCA/1992/1.html)
        - [High Court judgment 2](https://www.example.test/au/cases/cth/HCA/1992/2.html)
        - [High Court judgment 3](https://www.example.test/au/cases/cth/HCA/1992/3.html)
        - [High Court judgment 4](https://www.example.test/au/cases/cth/HCA/1992/4.html)

        #{paragraphs}
      MARKDOWN
      contentType: 'article',
      warnings: []
    )

    stub_browser_extraction(page.current_url, page: page, payload: judgment_payload)

    result = fetch_with_dependencies(page.current_url)

    expect(result.content_type).to eq('article')
  end

  it 'keeps homepage index reclassification behavior through the payload snapshot' do
    homepage_page = page_at('https://news.example.test/')
    homepage_payload = payload_with(
      title: 'Latest news and headlines',
      canonicalUrl: 'https://news.example.test/',
      markdown: <<~MARKDOWN.chomp,
        # Latest news and headlines

        - [Story one](https://news.example.test/story-one)
        - [Story two](https://news.example.test/story-two)
        - [Story three](https://news.example.test/story-three)
      MARKDOWN
      contentType: 'article',
      warnings: []
    )
    stub_browser_extraction('https://news.example.test/', page: homepage_page, payload: homepage_payload)

    result = fetch_with_dependencies('https://news.example.test/')

    expect(result.content_type).to eq('list')
    expect(result.warnings).to include('homepage_index_page')
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

  it 'returns a structured suspect result for browser DNS failures' do
    log = instance_double(FetchUtil::RequestLog)
    allow(log).to receive(:append)
    stub_browser_failure(
      'https://missing.example.test/',
      FetchUtil::BrowserError,
      'Request https://missing.example.test/ failed (net::ERR_NAME_NOT_RESOLVED)'
    )

    result = fetch_with_dependencies('https://missing.example.test/', request_log: log)

    expect(result).to be_a(FetchUtil::Result)
    expect(result.markdown).to eq('')
    expect(result.content_type).to eq('error')
    expect(result.suspect).to eq(true)
    expect(result.warnings).to eq(['dns_resolution_failed'])
    expect(result.error_message).to include('net::ERR_NAME_NOT_RESOLVED')
    expect(log).to have_received(:append).with('https://missing.example.test/', duration: a_value >= 0)
  end

  it 'returns a structured suspect result for pending connection failures' do
    log = instance_double(FetchUtil::RequestLog)
    allow(log).to receive(:append)
    stub_browser_failure(
      'https://slow.example.test/',
      FetchUtil::BrowserError,
      'Request https://slow.example.test/ reached server, but there are still pending connections'
    )

    result = fetch_with_dependencies('https://slow.example.test/', request_log: log)

    expect(result).to be_a(FetchUtil::Result)
    expect(result.markdown).to eq('')
    expect(result.content_type).to eq('error')
    expect(result.suspect).to eq(true)
    expect(result.warnings).to eq(['network_error'])
    expect(result.error_message).to include('pending connections')
    expect(log).to have_received(:append).with('https://slow.example.test/', duration: a_value >= 0)
  end

  it 'retries the full fetch once for pending connection browser failures' do
    log = instance_double(FetchUtil::RequestLog)
    attempts = 0
    page = instance_double('FerrumPage', current_url: 'https://example.com/final')

    allow(log).to receive(:append)
    allow(extractor).to receive(:extract).with(page).and_return(payload)
    allow(browser).to receive(:with_page) do |_url, &block|
      attempts += 1
      raise FetchUtil::BrowserError, 'Request https://slow.example.test/ reached server, but there are still pending connections' if attempts == 1

      block.call(page)
    end

    result = fetch_with_dependencies('https://slow.example.test/', request_log: log)

    expect(result).to be_a(FetchUtil::Result)
    expect(result.content_type).to eq('article')
    expect(attempts).to eq(2)
    expect(log).to have_received(:append).with('https://slow.example.test/', duration: a_value >= 0)
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
