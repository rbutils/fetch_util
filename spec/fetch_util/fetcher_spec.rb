# frozen_string_literal: true

RSpec.describe FetchUtil::Fetcher do
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

  it 'returns a result object with metadata' do
    allow(browser).to receive(:with_page).with('https://example.com/input').and_yield(page)
    allow(extractor).to receive(:extract).with(page).and_return(payload)

    result = described_class.new(browser: browser, extractor: extractor, raw_docs_fallback: raw_docs_fallback).fetch('https://example.com/input')

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

    allow(browser).to receive(:with_page).with('https://stackoverflow.com/questions/14818673/what-is-the-difference-between-proc-and-lambda-in-ruby').and_yield(page)
    allow(extractor).to receive(:extract).with(page).and_return(mismatched_payload)

    result = described_class.new(browser: browser, extractor: extractor, raw_docs_fallback: raw_docs_fallback).fetch('https://stackoverflow.com/questions/14818673/what-is-the-difference-between-proc-and-lambda-in-ruby')

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

    allow(browser).to receive(:with_page).with('https://stackoverflow.com/questions/14818673/what-is-the-difference-between-proc-and-lambda-in-ruby').and_yield(so_page)
    allow(extractor).to receive(:extract).with(so_page).and_return(mismatched_payload)

    result = described_class.new(browser: browser, extractor: extractor, raw_docs_fallback: raw_docs_fallback).fetch('https://stackoverflow.com/questions/14818673/what-is-the-difference-between-proc-and-lambda-in-ruby')

    expect(result.suspect).to eq(false)
    expect(result.warnings).not_to include('url_content_mismatch')
  end

  it 'relabels homepage news indexes as list content' do
    homepage_page = instance_double('FerrumPage', current_url: 'https://www.nytimes.com/')
    homepage_payload = payload.merge(
      'title' => 'The New York Times - Breaking News, US News, World News and Videos',
      'markdown' => "## New York Times - Top Stories\n\n1. Story one\n2. Story two\n3. Story three\n",
      'contentType' => 'article'
    )

    allow(browser).to receive(:with_page).with('https://www.nytimes.com/').and_yield(homepage_page)
    allow(extractor).to receive(:extract).with(homepage_page).and_return(homepage_payload)

    result = described_class.new(browser: browser, extractor: extractor, raw_docs_fallback: raw_docs_fallback).fetch('https://www.nytimes.com/')

    expect(result.content_type).to eq('list')
    expect(result.warnings).to include('homepage_index_page')
  end

  it 'keeps search result pages as search content' do
    search_page = instance_double('FerrumPage', current_url: 'https://www.google.com/search?q=ruby+language')
    search_payload = payload.merge(
      'title' => 'ruby language - Google Search',
      'markdown' => "- [Ruby Programming Language](https://www.ruby-lang.org/) - Official site\n- [Ruby - Wikipedia](https://en.wikipedia.org/wiki/Ruby_(programming_language))\n",
      'contentType' => 'search',
      'warnings' => []
    )

    allow(browser).to receive(:with_page).with('https://www.google.com/search?q=ruby+language').and_yield(search_page)
    allow(extractor).to receive(:extract).with(search_page).and_return(search_payload)

    result = described_class.new(browser: browser, extractor: extractor, raw_docs_fallback: raw_docs_fallback).fetch('https://www.google.com/search?q=ruby+language')

    expect(result.content_type).to eq('search')
    expect(result.warnings).not_to include('homepage_index_page')
    expect(result.warnings).not_to include('url_content_mismatch')
  end

  it 'does not flag query-driven list pages as url mismatches' do
    search_list_page = instance_double('FerrumPage', current_url: 'https://www.pinterest.com/search/pins/?q=ruby+programming')
    list_payload = payload.merge(
      'title' => 'Pinterest results for ruby programming',
      'markdown' => "- [ruby programming poster](https://www.pinterest.com/pin/1/)\n- [ruby reference sheet](https://www.pinterest.com/pin/2/)\n",
      'contentType' => 'list',
      'warnings' => []
    )

    allow(browser).to receive(:with_page).with('https://www.pinterest.com/search/pins/?q=ruby+programming').and_yield(search_list_page)
    allow(extractor).to receive(:extract).with(search_list_page).and_return(list_payload)

    result = described_class.new(browser: browser, extractor: extractor, raw_docs_fallback: raw_docs_fallback).fetch('https://www.pinterest.com/search/pins/?q=ruby+programming')

    expect(result.content_type).to eq('list')
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

    allow(browser).to receive(:with_page).with('https://developers.openai.com/api/reference/resources/chat').and_yield(docs_page)
    allow(extractor).to receive(:extract).with(docs_page).and_return(docs_payload)

    result = described_class.new(browser: browser, extractor: extractor, raw_docs_fallback: raw_docs_fallback).fetch('https://developers.openai.com/api/reference/resources/chat')

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

    allow(browser).to receive(:with_page).with('https://pinia.vuejs.org/core-concepts/').and_yield(docs_page)
    allow(extractor).to receive(:extract).with(docs_page).and_return(docs_payload)

    result = described_class.new(browser: browser, extractor: extractor, raw_docs_fallback: raw_docs_fallback).fetch('https://pinia.vuejs.org/core-concepts/')

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

    allow(browser).to receive(:with_page).with('https://www.ncbi.nlm.nih.gov/books/NBK553156/').and_yield(docs_page)
    allow(extractor).to receive(:extract).with(docs_page).and_return(docs_payload)

    result = described_class.new(browser: browser, extractor: extractor, raw_docs_fallback: raw_docs_fallback).fetch('https://www.ncbi.nlm.nih.gov/books/NBK553156/')

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

    allow(browser).to receive(:with_page).with('https://www.diki.pl/slownik-angielskiego?q=whores').and_yield(glossary_page)
    allow(extractor).to receive(:extract).with(glossary_page).and_return(glossary_payload)

    result = described_class.new(browser: browser, extractor: extractor, raw_docs_fallback: raw_docs_fallback).fetch('https://www.diki.pl/slownik-angielskiego?q=whores')

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

    allow(browser).to receive(:with_page).with('https://www.cssn.cn/skgz/bwyc/202412/t20241225_5826232.shtml').and_yield(page)
    allow(extractor).to receive(:extract).with(page).and_return(cjk_payload)

    result = described_class.new(browser: browser, extractor: extractor, raw_docs_fallback: raw_docs_fallback).fetch('https://www.cssn.cn/skgz/bwyc/202412/t20241225_5826232.shtml')

    expect(result.warnings).not_to include('url_content_mismatch')
  end

  it 'normalizes challenge and tracking query params from result urls' do
    challenge_page = instance_double('FerrumPage', current_url: 'https://www.freedesktop.org/software/systemd/man/latest/systemd.service.html?__goaway_challenge=meta-refresh&__goaway_id=abc123&utm_source=test')
    challenge_payload = payload.merge(
      'canonicalUrl' => 'https://www.freedesktop.org/software/systemd/man/latest/systemd.service.html?__goaway_challenge=meta-refresh&__goaway_id=abc123',
      'title' => 'systemd.service'
    )

    allow(browser).to receive(:with_page).with('https://www.freedesktop.org/software/systemd/man/latest/systemd.service.html').and_yield(challenge_page)
    allow(extractor).to receive(:extract).with(challenge_page).and_return(challenge_payload)

    result = described_class.new(browser: browser, extractor: extractor, raw_docs_fallback: raw_docs_fallback).fetch('https://www.freedesktop.org/software/systemd/man/latest/systemd.service.html')

    expect(result.final_url).to eq('https://www.freedesktop.org/software/systemd/man/latest/systemd.service.html')
    expect(result.canonical_url).to eq('https://www.freedesktop.org/software/systemd/man/latest/systemd.service.html')
    expect(result.metadata[:content_url]).to eq('https://www.freedesktop.org/software/systemd/man/latest/systemd.service.html')
  end

  it 'normalizes Digi24-style gr tracking query params from result urls' do
    tracked_page = instance_double('FerrumPage', current_url: 'https://www.digi24.ro/?__grsc=cookieIsUndef0&__grts=59151633&__grua=06b4a7e6274c16710a1f6ac7ae09eff9&__grrn=1')
    tracked_payload = payload.merge(
      'canonicalUrl' => 'https://www.digi24.ro/?__grsc=cookieIsUndef0&__grts=59151633&__grua=06b4a7e6274c16710a1f6ac7ae09eff9&__grrn=1',
      'title' => 'Digi24 - Stiri - Informația la putere!',
      'contentType' => 'list',
      'warnings' => ['homepage_index_page']
    )

    allow(browser).to receive(:with_page).with('https://www.digi24.ro/').and_yield(tracked_page)
    allow(extractor).to receive(:extract).with(tracked_page).and_return(tracked_payload)

    result = described_class.new(browser: browser, extractor: extractor, raw_docs_fallback: raw_docs_fallback).fetch('https://www.digi24.ro/')

    expect(result.final_url).to eq('https://www.digi24.ro/')
    expect(result.canonical_url).to eq('https://www.digi24.ro/')
    expect(result.metadata[:content_url]).to eq('https://www.digi24.ro/')
  end

  it 'preserves instagram next redirect targets when the current session is bounced to login' do
    redirected_page = instance_double('FerrumPage', current_url: 'https://www.instagram.com/accounts/login/?next=%2Fcristiano%2F&utm_source=ig_web')
    redirected_payload = payload.merge(
      'title' => 'Cristiano Ronaldo (@cristiano)',
      'markdown' => '# Cristiano Ronaldo (@cristiano)\n\nOriginal content on this Instagram page for cristiano is not available without login.',
      'canonicalUrl' => 'https://www.instagram.com/accounts/login/?next=%2Fcristiano%2F&utm_source=ig_web',
      'siteName' => 'Instagram'
    )

    allow(browser).to receive(:with_page).with('https://www.instagram.com/cristiano/').and_yield(redirected_page)
    allow(extractor).to receive(:extract).with(redirected_page).and_return(redirected_payload)

    result = described_class.new(browser: browser, extractor: extractor, raw_docs_fallback: raw_docs_fallback).fetch('https://www.instagram.com/cristiano/')

    expect(result.final_url).to eq('https://www.instagram.com/accounts/login/?next=%2Fcristiano%2F')
    expect(result.canonical_url).to eq('https://www.instagram.com/accounts/login/?next=%2Fcristiano%2F')
    expect(result.metadata[:content_url]).to eq('https://www.instagram.com/accounts/login/?next=%2Fcristiano%2F')
  end

  it 'does not inspect instagram network traffic for login-required payloads' do
    instagram_page = instance_double('FerrumPage', current_url: 'https://www.instagram.com/cristiano/')
    instagram_payload = payload.merge(
      'title' => 'Cristiano Ronaldo (@cristiano)',
      'excerpt' => '673M Followers, 643 Following, 4,027 Posts.',
      'siteName' => 'Instagram',
      'markdown' => [
        '# Cristiano Ronaldo (@cristiano)',
        '- Access notice: Instagram login required',
        '- Image: https://cdn.example.test/cristiano.jpg',
        '',
        'Original content on this Instagram page for cristiano is not available without login.'
      ].join("\n")
    )

    expect(instagram_page).not_to receive(:network)
    allow(browser).to receive(:with_page).with('https://www.instagram.com/cristiano/').and_yield(instagram_page)
    allow(extractor).to receive(:extract).with(instagram_page).and_return(instagram_payload)

    result = described_class.new(browser: browser, extractor: extractor, raw_docs_fallback: raw_docs_fallback).fetch('https://www.instagram.com/cristiano/')

    expect(result.markdown).to eq(instagram_payload['markdown'])
    expect(result.excerpt).to eq('673M Followers, 643 Following, 4,027 Posts.')
  end

  it 'falls back to raw docs extraction when browser extraction fails on docs pages' do
    fallback_payload = payload.merge(
      'title' => 'Pod v1 core',
      'markdown' => '# Pod v1 core\n\nPod is a collection of containers.',
      'canonicalUrl' => 'https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.31/',
      'siteName' => 'kubernetes.io'
    )

    allow(browser).to receive(:with_page).with('https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.31/#pod-v1-core').and_raise(FetchUtil::ExtractionError, 
                                                                                                                                             'timeout')
    allow(raw_docs_fallback).to receive(:fetch).with('https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.31/#pod-v1-core').and_return([
                                                                                                                                                      'https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.31/#pod-v1-core',
                                                                                                                                                      fallback_payload
                                                                                                                                                    ])

    result = described_class.new(browser: browser, extractor: extractor, raw_docs_fallback: raw_docs_fallback).fetch('https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.31/#pod-v1-core')

    expect(result.title).to eq('Pod v1 core')
    expect(result.final_url).to eq('https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.31/#pod-v1-core')
    expect(result.warnings).to eq([])
  end

  it 'replaces obviously bad docs output with raw docs fallback content' do
    docs_page = instance_double('FerrumPage', current_url: 'https://caddyserver.com/docs/caddyfile/directives/reverse_proxy')
    weak_payload = payload.merge(
      'title' => 'Caddy - The Ultimate Server with Automatic HTTPS',
      'markdown' => "# Caddy - The Ultimate Server with Automatic HTTPS\n\n# reverse_proxy\n\nProxies requests to one or more backends.",
      'canonicalUrl' => 'https://caddyserver.com/docs/caddyfile/directives/reverse_proxy',
      'warnings' => []
    )
    fallback_payload = payload.merge(
      'title' => 'reverse_proxy',
      'markdown' => '# reverse_proxy\n\nProxies requests to one or more backends.',
      'canonicalUrl' => 'https://caddyserver.com/docs/caddyfile/directives/reverse_proxy',
      'siteName' => 'Caddy Documentation'
    )

    allow(browser).to receive(:with_page).with('https://caddyserver.com/docs/caddyfile/directives/reverse_proxy').and_yield(docs_page)
    allow(extractor).to receive(:extract).with(docs_page).and_return(weak_payload)
    allow(raw_docs_fallback).to receive(:fetch).with('https://caddyserver.com/docs/caddyfile/directives/reverse_proxy').and_return([
                                                                                                                                     'https://caddyserver.com/docs/caddyfile/directives/reverse_proxy',
                                                                                                                                     fallback_payload
                                                                                                                                   ])

    result = described_class.new(browser: browser, extractor: extractor, raw_docs_fallback: raw_docs_fallback).fetch('https://caddyserver.com/docs/caddyfile/directives/reverse_proxy')

    expect(result.title).to eq('reverse_proxy')
    expect(result.markdown).to include('Proxies requests to one or more backends')
  end

  it 'allows docs fallback when the extracted final url looks docs-like even if the requested url did not' do
    redirected_page = instance_double('FerrumPage', current_url: 'https://docs.example.dev/reference/widgets')
    weak_payload = payload.merge(
      'title' => 'Documentation Portal',
      'markdown' => "# Documentation Portal\n\n# Widgets\n\nReference content.",
      'canonicalUrl' => 'https://docs.example.dev/reference/widgets',
      'warnings' => []
    )
    fallback_payload = payload.merge(
      'title' => 'Widgets',
      'markdown' => '# Widgets\n\nReference content.',
      'canonicalUrl' => 'https://docs.example.dev/reference/widgets',
      'siteName' => 'Example Docs'
    )

    allow(browser).to receive(:with_page).with('https://example.com/go/widgets').and_yield(redirected_page)
    allow(extractor).to receive(:extract).with(redirected_page).and_return(weak_payload)
    allow(raw_docs_fallback).to receive(:fetch).with('https://example.com/go/widgets').and_return([
                                                                                                    'https://docs.example.dev/reference/widgets',
                                                                                                    fallback_payload
                                                                                                  ])

    result = described_class.new(browser: browser, extractor: extractor, raw_docs_fallback: raw_docs_fallback).fetch('https://example.com/go/widgets')

    expect(result.title).to eq('Widgets')
    expect(result.final_url).to eq('https://docs.example.dev/reference/widgets')
    expect(result.site_name).to eq('Example Docs')
  end

  it 'uses raw docs fallback for developer-hosted docs urls after browser failure' do
    fallback_payload = payload.merge(
      'title' => 'terraform_data',
      'markdown' => '# terraform_data\n\nManages arbitrary values in Terraform.',
      'canonicalUrl' => 'https://developer.hashicorp.com/terraform/language/resources/terraform-data',
      'siteName' => 'HashiCorp Developer'
    )

    allow(browser).to receive(:with_page).with('https://developer.hashicorp.com/terraform/language/resources/terraform-data').and_raise(FetchUtil::BrowserError, 'boom')
    allow(raw_docs_fallback).to receive(:fetch).with('https://developer.hashicorp.com/terraform/language/resources/terraform-data').and_return([
                                                                                                                                                 'https://developer.hashicorp.com/terraform/language/resources/terraform-data',
                                                                                                                                                 fallback_payload
                                                                                                                                               ])

    result = described_class.new(browser: browser, extractor: extractor, raw_docs_fallback: raw_docs_fallback).fetch('https://developer.hashicorp.com/terraform/language/resources/terraform-data')

    expect(result.title).to eq('terraform_data')
    expect(result.final_url).to eq('https://developer.hashicorp.com/terraform/language/resources/terraform-data')
    expect(result.site_name).to eq('HashiCorp Developer')
  end

  it 'relabels German homepage indexes as list content' do
    de_page = instance_double('FerrumPage', current_url: 'https://www.bild.de/')
    de_payload = payload.merge(
      'title' => 'BILD.de: Aktuelle Nachrichten',
      'markdown' => "## Aktuelle Nachrichten\n\n1. Bundestag beschließt neues Gesetz\n2. Scholz trifft Macron\n3. Neue Studie zur Inflation\n",
      'contentType' => 'article'
    )

    allow(browser).to receive(:with_page).with('https://www.bild.de/').and_yield(de_page)
    allow(extractor).to receive(:extract).with(de_page).and_return(de_payload)

    result = described_class.new(browser: browser, extractor: extractor, raw_docs_fallback: raw_docs_fallback).fetch('https://www.bild.de/')

    expect(result.content_type).to eq('list')
    expect(result.warnings).to include('homepage_index_page')
  end

  it 'relabels Hungarian homepage indexes as list content' do
    hu_page = instance_double('FerrumPage', current_url: 'https://www.444.hu/')
    hu_payload = payload.merge(
      'title' => '444 - Pair - legfrissebb hírek',
      'markdown' => "## Legfrissebb\n\n- Orbán felszólalt a parlamentben\n- Új intézkedések a járvány ellen\n- Sport: Fradi győzött\n",
      'contentType' => 'article'
    )

    allow(browser).to receive(:with_page).with('https://www.444.hu/').and_yield(hu_page)
    allow(extractor).to receive(:extract).with(hu_page).and_return(hu_payload)

    result = described_class.new(browser: browser, extractor: extractor, raw_docs_fallback: raw_docs_fallback).fetch('https://www.444.hu/')

    expect(result.content_type).to eq('list')
    expect(result.warnings).to include('homepage_index_page')
  end

  it 'relabels French homepage indexes as list content' do
    fr_page = instance_double('FerrumPage', current_url: 'https://www.lemonde.fr/')
    fr_payload = payload.merge(
      'title' => 'Le Monde.fr - Actualités et Infos en France et dans le monde - À la une',
      'markdown' => "## À la une\n\n- Macron annonce un plan de relance\n- Réforme des retraites\n- Européennes 2026\n",
      'contentType' => 'article'
    )

    allow(browser).to receive(:with_page).with('https://www.lemonde.fr/').and_yield(fr_page)
    allow(extractor).to receive(:extract).with(fr_page).and_return(fr_payload)

    result = described_class.new(browser: browser, extractor: extractor, raw_docs_fallback: raw_docs_fallback).fetch('https://www.lemonde.fr/')

    expect(result.content_type).to eq('list')
    expect(result.warnings).to include('homepage_index_page')
  end

  it 'does not relabel non-homepage article pages with matching phrases' do
    article_page = instance_double('FerrumPage', current_url: 'https://www.bild.de/politik/inland/article-12345')
    article_payload = payload.merge(
      'title' => 'Aktuelle Nachrichten zur Bundestagswahl',
      'markdown' => "# Aktuelle Nachrichten zur Bundestagswahl\n\nDie neuesten Ergebnisse der Wahl zeigen...",
      'contentType' => 'article'
    )

    allow(browser).to receive(:with_page).with('https://www.bild.de/politik/inland/article-12345').and_yield(article_page)
    allow(extractor).to receive(:extract).with(article_page).and_return(article_payload)

    result = described_class.new(browser: browser, extractor: extractor, raw_docs_fallback: raw_docs_fallback).fetch('https://www.bild.de/politik/inland/article-12345')

    expect(result.content_type).to eq('article')
    expect(result.warnings).not_to include('homepage_index_page')
  end

  it 'flags cross-domain redirects in warnings' do
    redirected_page = instance_double('FerrumPage', current_url: 'https://www.economx.hu/gazdasag/some-article')
    redirect_payload = payload.merge(
      'title' => 'Gazdasági hírek',
      'markdown' => "# Gazdasági hírek\n\nA magyar gazdaság...",
      'warnings' => []
    )

    allow(browser).to receive(:with_page).with('https://www.napi.hu/gazdasag/some-article').and_yield(redirected_page)
    allow(extractor).to receive(:extract).with(redirected_page).and_return(redirect_payload)

    result = described_class.new(browser: browser, extractor: extractor, raw_docs_fallback: raw_docs_fallback).fetch('https://www.napi.hu/gazdasag/some-article')

    expect(result.warnings).to include('cross_domain_redirect')
    expect(result.suspect).to eq(true)
  end

  it 'does not flag same-domain redirects as cross-domain' do
    same_domain_page = instance_double('FerrumPage', current_url: 'https://www.example.com/new-path')
    same_payload = payload.merge('warnings' => [])

    allow(browser).to receive(:with_page).with('https://www.example.com/old-path').and_yield(same_domain_page)
    allow(extractor).to receive(:extract).with(same_domain_page).and_return(same_payload)

    result = described_class.new(browser: browser, extractor: extractor, raw_docs_fallback: raw_docs_fallback).fetch('https://www.example.com/old-path')

    expect(result.warnings).not_to include('cross_domain_redirect')
  end

  it 'does not flag www-only differences as cross-domain redirects' do
    www_page = instance_double('FerrumPage', current_url: 'https://www.spectator.com/article')
    www_payload = payload.merge('warnings' => [])

    allow(browser).to receive(:with_page).with('https://spectator.com/article').and_yield(www_page)
    allow(extractor).to receive(:extract).with(www_page).and_return(www_payload)

    result = described_class.new(browser: browser, extractor: extractor, raw_docs_fallback: raw_docs_fallback).fetch('https://spectator.com/article')

    expect(result.warnings).not_to include('cross_domain_redirect')
  end

  it 'flags cross-domain redirect for co.uk TLD changes' do
    uk_page = instance_double('FerrumPage', current_url: 'https://www.spectator.com/article')
    uk_payload = payload.merge('warnings' => [])

    allow(browser).to receive(:with_page).with('https://www.spectator.co.uk/article').and_yield(uk_page)
    allow(extractor).to receive(:extract).with(uk_page).and_return(uk_payload)

    result = described_class.new(browser: browser, extractor: extractor, raw_docs_fallback: raw_docs_fallback).fetch('https://www.spectator.co.uk/article')

    expect(result.warnings).to include('cross_domain_redirect')
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
    allow(browser).to receive(:with_page).with('https://example.com/input').and_yield(page)
    allow(extractor).to receive(:extract).with(page).and_return(payload)

    described_class.new(browser: browser, extractor: extractor, raw_docs_fallback: raw_docs_fallback, request_log: log).fetch('https://example.com/input')

    expect(log).to have_received(:append).with('https://example.com/input', duration: a_value >= 0)
  end

  it 'logs duration even when fetch raises' do
    log = instance_double(FetchUtil::RequestLog)
    allow(log).to receive(:append)
    allow(browser).to receive(:with_page).and_raise(FetchUtil::BrowserError, 'boom')

    expect do
      described_class.new(browser: browser, extractor: extractor, raw_docs_fallback: raw_docs_fallback, request_log: log).fetch('https://nonexistent.example')
    end.to raise_error(FetchUtil::BrowserError)

    expect(log).to have_received(:append).with('https://nonexistent.example', duration: a_value >= 0)
  end
end
