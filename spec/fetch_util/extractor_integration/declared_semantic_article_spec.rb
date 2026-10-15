# frozen_string_literal: true

require 'spec_helper'
require 'support/extractor_integration_helpers'
require 'nokogiri'

RSpec.describe 'FetchUtil complete declared semantic article ownership' do
  include_context 'extractor integration helpers'

  def declared_article_page(paragraphs, supplemental: '')
    headline = 'A complete source-owned reporting article'
    declaration = {
      '@type' => 'NewsArticle', 'url' => 'https://publication.example.test/article/report',
      'headline' => headline, 'articleBody' => paragraphs.join(' '),
      'author' => { '@type' => 'Person', 'name' => 'Source Writer' }, 'datePublished' => '2026-10-07'
    }
    <<~HTML
      <html><head><title>#{headline} | Reference publication</title>
      <link rel="canonical" href="https://publication.example.test/article/report">
      <meta property="og:type" content="article"><meta property="og:title" content="#{headline}">
      <meta name="author" content="Source Writer"><meta property="article:published_time" content="2026-10-07">
      <script type="application/ld+json">#{JSON.generate(declaration)}</script></head><body>
      <nav>Foreign navigation</nav><main><article><header><h1>#{headline}</h1>
      <p>By <a rel="author" href="/writers/source">Source Writer</a></p>
      <time itemprop="datePublished" datetime="2026-10-07">October 7, 2026</time></header>
      <div>#{paragraphs.map { |text| "<p>#{text}</p>" }.join}#{supplemental}</div></article></main>
      <footer>Foreign footer</footer></body></html>
    HTML
  end

  def declared_article_source
    root = File.expand_path('../../..', __dir__)
    paths = File.readlines(File.join(root, 'websieve/manifest.txt'), chomp: true)
                .reject { |line| line.empty? || line.start_with?('#') }
    paths.map { |path| File.read(File.join(root, 'websieve', path)) }.join("\n").sub(
      '})(window);', 'window.hasDeclaredArticle = function() { return !!declaredSemanticArticleContext(); }; })(window);'
    )
  end

  def paired_publication_page
    html = declared_article_page(['The first complete reporting paragraph.', 'The second complete reporting paragraph.'])
    html.sub('"datePublished":"2026-10-07"', '"datePublished":"2026-10-07 03:03:00"')
        .sub('<meta property="article:published_time" content="2026-10-07">', '')
        .sub('<time itemprop="datePublished" datetime="2026-10-07">October 7, 2026</time>', <<~HTML)
          <span class="publication-dates">
          <time class="published" itemprop="datePublished" datetime="October 7, 2026">October 7, 2026</time>
          <time class="updated" itemprop="dateModified" datetime="2020-02-24T17:29:39+02:00">07.10.2026 • 03:03</time>
          </span>
        HTML
  end

  it 'retains every physical reporting paragraph and all owned sections, captions, references and replies' do
    paragraphs = (1..30).map { |index| "Reporting paragraph #{index} contains complete published observations and source context." }
    supplemental = <<~HTML
      <h2>Independent owned section</h2><p>The article also discusses privacy and subscription services.</p>
      <figure><img src="/images/owned.png" alt="Owned photograph"><figcaption>Source-proved photograph caption.</figcaption></figure>
      <blockquote><p>Published quotation outside the declared reporting string.</p></blockquote>
      <p><a href="/references/complete">Complete published reference</a></p>
      <div id="comments"><article class="comment"><h3>Published reader</h3><div class="comment-body">
      <p>A real published reply with substantive reporting observations.</p></div></article></div>
      <p hidden>Hidden reporting must remain hidden.</p>
    HTML
    extract_from_url('https://publication.example.test/article/report', declared_article_page(paragraphs, supplemental: supplemental)) do |payload|
      %w[html markdown].each do |format|
        previous = -1
        paragraphs.each do |paragraph|
          current = payload[format].index(paragraph, previous + 1)
          expect(current).not_to be_nil
          previous = current
        end
        expect(payload[format]).to include(
          'Independent owned section', 'privacy and subscription services',
          'Source-proved photograph caption.', 'Published quotation outside the declared reporting string.',
          'Complete published reference', '/references/complete', '/images/owned.png',
          'A real published reply with substantive reporting observations.'
        )
        expect(payload[format]).not_to include('Hidden reporting must remain hidden.', 'Foreign navigation', 'Foreign footer')
      end
      expect(payload['title']).to eq('A complete source-owned reporting article')
      expect(payload['byline']).to eq('Source Writer')
      expect(payload['publishedTime']).to eq('2026-10-07')
      expect(payload['contentType']).to eq('article')
      expect(payload['readerMode']).to be(false)
    end
  end

  it 'declines foreign, hidden, ambiguous, conflicting and JSON-only reporting owners' do
    valid = declared_article_page(['The first complete reporting paragraph.', 'The second complete reporting paragraph.'])
    conflicting = { '@type' => 'NewsArticle', 'url' => 'https://publication.example.test/article/report', 'headline' => 'Conflicting reporting' }
    cases = [
      valid.sub('"url":"https://publication.example.test/article/report"', '"url":"https://publication.example.test/article/foreign"'),
      valid.sub('<article>', '<article hidden>'),
      valid.sub('<h1>A complete source-owned reporting article</h1>', '<h1>Other printed identity</h1>'),
      valid.sub('"headline":"A complete source-owned reporting article"', '"headline":"Foreign declared identity"'),
      valid.sub('</header>', '<h1>A complete source-owned reporting article</h1></header>'),
      valid.sub('<p>The second complete reporting paragraph.</p>', ''),
      valid.sub('<p>The second complete reporting paragraph.</p>', '<p hidden>The second complete reporting paragraph.</p>'),
      valid.sub('</article></main>', '</article><article><h1>Foreign source</h1><p>The first complete reporting paragraph.</p></article></main>'),
      valid.sub('</script>', "</script><script type=\"application/ld+json\">#{JSON.generate(conflicting)}</script>")
    ]
    cases.each do |html|
      with_url_page('https://publication.example.test/article/report', html) do |page|
        page.add_script_tag(content: declared_article_source)
        expect(page.evaluate('hasDeclaredArticle()')).to be(false)
      end
    end
  end

  it 'keeps a proved current news article on a story route despite media and engagement controls' do
    paragraphs = ['The first complete current reporting paragraph.', 'The second complete current reporting paragraph.']
    supplemental = '<figure><img src="/images/source.png" alt="Source photograph"><figcaption>Owned caption.</figcaption></figure>' \
                   '<button>Share</button><button>Like</button>'
    html = declared_article_page(paragraphs, supplemental: supplemental).gsub('/article/report', '/story/report')
    extract_from_url('https://publication.example.test/story/report', html) do |payload|
      expect(payload['contentType']).to eq('article')
      expect(payload['socialKind']).to be_nil
      expect(payload['platform']).to be_nil
      %w[html markdown].each do |format|
        paragraphs.each { |text| expect(payload[format]).to include(text) }
        expect(payload[format]).to include('Owned caption.', '/images/source.png')
      end
    end
  end

  it 'resolves paired publication and modification fields without joining their printed labels' do
    extract_from_url('https://publication.example.test/article/report', paired_publication_page) do |payload|
      expect(payload['publishedTime']).to eq('2026-10-07 03:03:00')
      expect(payload['byline']).to eq('Source Writer')
      %w[html markdown].each do |format|
        expect(payload[format]).to include(
          'October 7, 2026', '07.10.2026 • 03:03',
          'The first complete reporting paragraph.', 'The second complete reporting paragraph.'
        )
      end
    end
  end

  it 'does not override conflicting or ambiguous page publication metadata with a paired widget' do
    head = '<meta property="article:published_time" content="2026-10-08 03:03:00">'
    pages = [paired_publication_page.sub('</head>', "#{head}</head>"),
             paired_publication_page.sub('</head>', "#{head}<meta property=\"article:published_time\" content=\"2026-10-09 03:03:00\"></head>")]
    pages.each do |html|
      extract_from_url('https://publication.example.test/article/report', html) do |payload|
        expect(payload['publishedTime']).to be_nil
        expect(payload['markdown']).to include('The first complete reporting paragraph.', 'The second complete reporting paragraph.')
      end
    end
  end

  it 'declines foreign, duplicate, disagreeing and prose-bearing paired date evidence' do
    html = paired_publication_page
    pages = [
      html.sub('"url":"https://publication.example.test/article/report"', '"url":"https://publication.example.test/article/foreign"'),
      html.sub('itemprop="dateModified"', 'itemprop="datePublished"'),
      html.sub('datetime="October 7, 2026"', 'datetime="October 6, 2026"'),
      html.sub('<span class="publication-dates">', '<span class="publication-dates">Unrelated authored context ')
    ]
    pages.each do |page|
      extract_from_url('https://publication.example.test/article/report', page) do |payload|
        expect(payload['publishedTime']).not_to eq('2026-10-07 03:03:00')
        expect(payload['markdown']).to include('The first complete reporting paragraph.', 'The second complete reporting paragraph.')
      end
    end
  end

  it 'does not request visibility for physical paragraphs outside the declaration' do
    unrelated = (1..120).map { |index| "<p data-unrelated>Unrelated published description #{index}.</p>" }.join
    html = declared_article_page(['First reporting paragraph.', 'Second reporting paragraph.']).sub('<main>', "#{unrelated}<main>")
    with_url_page('https://publication.example.test/article/report', html) do |page|
      page.add_script_tag(content: declared_article_source)
      result = page.evaluate(<<~JAVASCRIPT)
        (() => {
          const original = window.getComputedStyle;
          let calls = 0;
          window.getComputedStyle = function(node) {
            if (node && node.hasAttribute('data-unrelated')) calls++;
            return original.apply(this, arguments);
          };
          try { return { owned: hasDeclaredArticle(), calls: calls }; }
          finally { window.getComputedStyle = original; }
        })()
      JAVASCRIPT
      expect(result).to eq('owned' => true, 'calls' => 0)
    end
  end

  it 'retains ordinary edition and structured offer references and every published media encoding' do
    edition = 'This reporting appears in the current edition. Continue when you subscribe to AD.'
    paragraphs = ['The complete reporting identifies the physical objects and their published resources.', edition]
    supplemental = <<~HTML
      <h2>Owned reference objects</h2><div class="product-offer__cta-block">
      <a href="/objects/reference" rel="sponsored"><span><span>4200 credits</span><p>Source Workshop</p><p>Shop at</p></span></a></div>
      <figure><video><source src="/media/first.mp4" type="video/mp4"><source src="/media/second.webm" type="video/webm"></video>
      <figcaption>Published moving-image caption.</figcaption></figure>
      <figure><img src="/images/unlabelled.png" alt=""><figcaption>Published unlabelled photograph caption.</figcaption></figure>
      <p data-fetchutil-declared-reference="fetch-util-declared-reference-0">Authored attribute must remain untouched.</p>
      <p><a href="/login">Sign in</a></p>
      <form><input type="email"><button>Subscribe</button></form>
    HTML
    html = declared_article_page(paragraphs, supplemental: supplemental).sub(
      "<p>#{edition}</p>",
      '<p><em>This reporting appears in the current edition. Continue when you <a href="/edition">subscribe to</a></em> <a href="/edition">AD</a>.</p>'
    )
    extract_from_url('https://publication.example.test/article/report', html) do |payload|
      %w[html markdown].each do |format|
        expect(payload[format]).to include(
          'Source Workshop', 'Shop at', '4200 credits', '/objects/reference',
          'subscribe to', 'AD', '/edition', '/media/first.mp4', '/media/second.webm',
          '/images/unlabelled.png', 'Published moving-image caption.',
          'Published unlabelled photograph caption.', 'Authored attribute must remain untouched.'
        )
      end
      document = Nokogiri::HTML5.fragment(payload['html'])
      expect(document.at_css('p[data-fetchutil-declared-reference]')['data-fetchutil-declared-reference']).to eq('fetch-util-declared-reference-0')
      expect(document.css('a').select { |anchor| anchor['href'].end_with?('/edition') }.map(&:text)).to eq(['subscribe to', 'AD'])
      expect(document.css('form,input,button')).to be_empty
      expect(document.css('a').any? { |anchor| anchor['href'].end_with?('/login') }).to be(false)
    end
  end
end
