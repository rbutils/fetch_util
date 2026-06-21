# frozen_string_literal: true

RSpec.describe FetchUtil::Fetcher do
  include_context 'fetcher spec helpers'

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

  it 'relabels homepage news indexes as list content' do
    homepage_page = instance_double('FerrumPage', current_url: 'https://www.nytimes.com/')
    homepage_payload = payload.merge(
      'title' => 'The New York Times - Breaking News, US News, World News and Videos',
      'markdown' => "## New York Times - Top Stories\n\n1. Story one\n2. Story two\n3. Story three\n",
      'contentType' => 'article'
    )

    stub_browser_extraction('https://www.nytimes.com/', page: homepage_page, payload: homepage_payload)

    result = fetch_with_dependencies('https://www.nytimes.com/')

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

    stub_browser_extraction('https://www.google.com/search?q=ruby+language', page: search_page, payload: search_payload)

    result = fetch_with_dependencies('https://www.google.com/search?q=ruby+language')

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

    stub_browser_extraction('https://www.pinterest.com/search/pins/?q=ruby+programming', page: search_list_page, payload: list_payload)

    result = fetch_with_dependencies('https://www.pinterest.com/search/pins/?q=ruby+programming')

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

  it 'normalizes challenge and tracking query params from result urls' do
    challenge_page = instance_double('FerrumPage', current_url: 'https://www.freedesktop.org/software/systemd/man/latest/systemd.service.html?__goaway_challenge=meta-refresh&__goaway_id=abc123&utm_source=test')
    challenge_payload = payload.merge(
      'canonicalUrl' => 'https://www.freedesktop.org/software/systemd/man/latest/systemd.service.html?__goaway_challenge=meta-refresh&__goaway_id=abc123',
      'title' => 'systemd.service'
    )

    stub_browser_extraction('https://www.freedesktop.org/software/systemd/man/latest/systemd.service.html', page: challenge_page, payload: challenge_payload)

    result = fetch_with_dependencies('https://www.freedesktop.org/software/systemd/man/latest/systemd.service.html')

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

    stub_browser_extraction('https://www.digi24.ro/', page: tracked_page, payload: tracked_payload)

    result = fetch_with_dependencies('https://www.digi24.ro/')

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

    stub_browser_extraction('https://www.instagram.com/cristiano/', page: redirected_page, payload: redirected_payload)

    result = fetch_with_dependencies('https://www.instagram.com/cristiano/')

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
    stub_browser_extraction('https://www.instagram.com/cristiano/', page: instagram_page, payload: instagram_payload)

    result = fetch_with_dependencies('https://www.instagram.com/cristiano/')

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

    stub_browser_failure('https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.31/#pod-v1-core', FetchUtil::ExtractionError, 'timeout')
    stub_raw_docs_fallback('https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.31/#pod-v1-core', payload: fallback_payload)

    result = fetch_with_dependencies('https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.31/#pod-v1-core')

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

    stub_browser_extraction('https://caddyserver.com/docs/caddyfile/directives/reverse_proxy', page: docs_page, payload: weak_payload)
    stub_raw_docs_fallback('https://caddyserver.com/docs/caddyfile/directives/reverse_proxy', payload: fallback_payload)

    result = fetch_with_dependencies('https://caddyserver.com/docs/caddyfile/directives/reverse_proxy')

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

    stub_browser_extraction('https://example.com/go/widgets', page: redirected_page, payload: weak_payload)
    stub_raw_docs_fallback('https://example.com/go/widgets', final_url: 'https://docs.example.dev/reference/widgets', payload: fallback_payload)

    result = fetch_with_dependencies('https://example.com/go/widgets')

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

    stub_browser_failure('https://developer.hashicorp.com/terraform/language/resources/terraform-data', FetchUtil::BrowserError, 'boom')
    stub_raw_docs_fallback('https://developer.hashicorp.com/terraform/language/resources/terraform-data', payload: fallback_payload)

    result = fetch_with_dependencies('https://developer.hashicorp.com/terraform/language/resources/terraform-data')

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

    stub_browser_extraction('https://www.bild.de/', page: de_page, payload: de_payload)

    result = fetch_with_dependencies('https://www.bild.de/')

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

    stub_browser_extraction('https://www.444.hu/', page: hu_page, payload: hu_payload)

    result = fetch_with_dependencies('https://www.444.hu/')

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

    stub_browser_extraction('https://www.lemonde.fr/', page: fr_page, payload: fr_payload)

    result = fetch_with_dependencies('https://www.lemonde.fr/')

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

    stub_browser_extraction('https://www.bild.de/politik/inland/article-12345', page: article_page, payload: article_payload)

    result = fetch_with_dependencies('https://www.bild.de/politik/inland/article-12345')

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

    stub_browser_extraction('https://www.napi.hu/gazdasag/some-article', page: redirected_page, payload: redirect_payload)

    result = fetch_with_dependencies('https://www.napi.hu/gazdasag/some-article')

    expect(result.warnings).to include('cross_domain_redirect')
    expect(result.suspect).to eq(true)
  end

  it 'does not flag same-domain redirects as cross-domain' do
    same_domain_page = instance_double('FerrumPage', current_url: 'https://www.example.com/new-path')
    same_payload = payload.merge('warnings' => [])

    stub_browser_extraction('https://www.example.com/old-path', page: same_domain_page, payload: same_payload)

    result = fetch_with_dependencies('https://www.example.com/old-path')

    expect(result.warnings).not_to include('cross_domain_redirect')
  end

  it 'does not flag www-only differences as cross-domain redirects' do
    www_page = instance_double('FerrumPage', current_url: 'https://www.spectator.com/article')
    www_payload = payload.merge('warnings' => [])

    stub_browser_extraction('https://spectator.com/article', page: www_page, payload: www_payload)

    result = fetch_with_dependencies('https://spectator.com/article')

    expect(result.warnings).not_to include('cross_domain_redirect')
  end

  it 'flags cross-domain redirect for co.uk TLD changes' do
    uk_page = instance_double('FerrumPage', current_url: 'https://www.spectator.com/article')
    uk_payload = payload.merge('warnings' => [])

    stub_browser_extraction('https://www.spectator.co.uk/article', page: uk_page, payload: uk_payload)

    result = fetch_with_dependencies('https://www.spectator.co.uk/article')

    expect(result.warnings).to include('cross_domain_redirect')
  end

  it 'flags aggregator_redirect_url for news.google.com URLs' do
    google_news_page = instance_double('FerrumPage', current_url: 'https://www.reuters.com/world/europe/article-123')
    google_news_payload = payload.merge('warnings' => [])

    stub_browser_extraction('https://news.google.com/rss/articles/some-encoded-id', page: google_news_page, payload: google_news_payload)

    result = fetch_with_dependencies('https://news.google.com/rss/articles/some-encoded-id')

    expect(result.warnings).to include('aggregator_redirect_url')
    expect(result.suspect).to eq(true)
  end

  it 'flags aggregator_redirect_url for AMP cache URLs' do
    amp_page = instance_double('FerrumPage', current_url: 'https://www.example.com/article')
    amp_payload = payload.merge('warnings' => [])

    stub_browser_extraction('https://cdn.ampproject.org/c/s/www.example.com/article', page: amp_page, payload: amp_payload)

    result = fetch_with_dependencies('https://cdn.ampproject.org/c/s/www.example.com/article')

    expect(result.warnings).to include('aggregator_redirect_url')
  end

  it 'flags aggregator_redirect_url for AMP cache subdomain URLs' do
    amp_sub_page = instance_double('FerrumPage', current_url: 'https://www.example.com/article')
    amp_sub_payload = payload.merge('warnings' => [])

    stub_browser_extraction('https://www-example-com.cdn.ampproject.org/c/s/www.example.com/article', page: amp_sub_page, payload: amp_sub_payload)

    result = fetch_with_dependencies('https://www-example-com.cdn.ampproject.org/c/s/www.example.com/article')

    expect(result.warnings).to include('aggregator_redirect_url')
  end

  it 'flags aggregator_redirect_url for Google redirect URLs' do
    google_redir_page = instance_double('FerrumPage', current_url: 'https://www.example.com/article')
    google_redir_payload = payload.merge('warnings' => [])

    stub_browser_extraction('https://www.google.com/url?q=https://www.example.com/article', page: google_redir_page, payload: google_redir_payload)

    result = fetch_with_dependencies('https://www.google.com/url?q=https://www.example.com/article')

    expect(result.warnings).to include('aggregator_redirect_url')
  end

  it 'does not flag regular publisher URLs as aggregator_redirect_url' do
    regular_page = instance_double('FerrumPage', current_url: 'https://www.reuters.com/world/europe/article-123')
    regular_payload = payload.merge('warnings' => [])

    stub_browser_extraction('https://www.reuters.com/world/europe/article-123', page: regular_page, payload: regular_payload)

    result = fetch_with_dependencies('https://www.reuters.com/world/europe/article-123')

    expect(result.warnings).not_to include('aggregator_redirect_url')
  end

  it 'does not flag google.com search URLs as aggregator_redirect_url' do
    search_page = instance_double('FerrumPage', current_url: 'https://www.google.com/search?q=test')
    search_payload = payload.merge('contentType' => 'search', 'warnings' => [])

    stub_browser_extraction('https://www.google.com/search?q=test', page: search_page, payload: search_payload)

    result = fetch_with_dependencies('https://www.google.com/search?q=test')

    expect(result.warnings).not_to include('aggregator_redirect_url')
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
