# frozen_string_literal: true

require 'json'

RSpec.describe 'FetchUtil declared article and media ownership' do
  include_context 'extractor integration helpers'

  def declared_article_html(hidden: false, headline: 'Measured storm conditions')
    body = 'Published measurements describe the observed electrical conditions and explain why existing protection does not eliminate every possible risk.'
    entity = { '@context' => 'https://schema.org', '@type' => 'NewsArticle', 'headline' => headline, 'articleBody' => body }
    <<~HTML
      <html><head><title>Measured storm conditions</title><meta property="og:type" content="video">
        <meta name="description" content="A short metadata description of the recorded conditions.">
        <script type="application/ld+json">#{JSON.generate(entity)}</script></head><body>
        <article><h1>Measured storm conditions</h1>
          <ul><li>Measurements distinguish the different electrical events.</li><li>The report records the limitations of existing protection.</li></ul>
          <p>The observers published a complete account explaining the measurements and the circumstances under which the observed electrical events occurred.</p>
        </article><main><article #{hidden ? "hidden" : ""}><div>#{body}</div></article></main>
      </body></html>
    HTML
  end

  def declared_media_probe(page)
    FetchUtil::Extractor.new.send(:inject_vendor_assets, page)
    directory = File.expand_path('../../../websieve', __dir__)
    source = File.readlines(File.join(directory, 'manifest.txt'), chomp: true)
                 .reject { |line| line.empty? || line.start_with?('#') }
                 .map { |file| File.read(File.join(directory, file)) }.join("\n")
    export = <<~JS
      window.declaredMediaProbe = withComposedDomRead(function() {
        var root = document.querySelector('main').cloneNode(true);
        materializeDeclaredArticleMedia(root, true);
        return { html: root.outerHTML, markdown: markdownFor(root.outerHTML, false, false, true),
          nestedAnchors: root.querySelectorAll('a a').length };
      });
      })(window);
    JS
    page.add_script_tag(content: source.sub('})(window);', export))
    page.evaluate('window.declaredMediaProbe()')
  end

  it 'keeps every linked picture, story heading and description outside added media-source links' do
    cards = (1..240).map do |number|
      <<~HTML
        <article><a href="/reports/entry-#{number}"><figure><picture>
          <img src="/images/report-#{number}.png" alt="Recorded scene #{number}">
          </picture><figcaption>Published figure #{number}</figcaption></figure>
          <h2>Report #{number}</h2><p>Complete observations for record #{number} remain in their published order.</p>
        </a></article>
      HTML
    end.join
    with_url_page('https://publication.example.test/', "<html><body><main>#{cards}</main></body></html>") do |page|
      before = page.evaluate('document.body.innerHTML')
      result = declared_media_probe(page)

      expect(result.fetch('nestedAnchors')).to eq(0)
      (1..240).each do |number|
        expect(result.fetch('markdown')).to include(
          "## [Report #{number}](https://publication.example.test/reports/entry-#{number})",
          "https://publication.example.test/images/report-#{number}.png",
          "Published figure #{number}",
          "Complete observations for record #{number} remain in their published order."
        )
        expect(result.fetch('html')).to include("href=\"/reports/entry-#{number}\"")
      end
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end

  it 'retains unlinked pictures, captions and every audio and video source without changing the physical page' do
    html = <<~HTML
      <html><body><main><figure><picture><img src="/images/scene.png" alt="Published scene"></picture>
        <figcaption>Authored scene caption.</figcaption></figure>
        <video src="/media/primary.mp4"><source src="/media/alternate.webm"></video>
        <audio><source src="/media/recording.ogg"><source src="/media/recording.mp3"></audio>
        <p>Final reporting and <a href="/references">its published references</a>.</p>
      </main></body></html>
    HTML
    with_url_page('https://publication.example.test/', html) do |page|
      before = page.evaluate('document.body.innerHTML')
      result = declared_media_probe(page)

      expect(result.fetch('nestedAnchors')).to eq(0)
      %w[images/scene.png media/primary.mp4 media/alternate.webm media/recording.ogg media/recording.mp3 references].each do |path|
        expect(result.fetch('markdown')).to include("https://publication.example.test/#{path}")
      end
      expect(result.fetch('markdown')).to include('Authored scene caption.', 'Final reporting', 'its published references')
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end

  it 'preserves an independent publisher summary and visible declared body ahead of a player teaser' do
    with_url_page('https://research.example/reports/storms', declared_article_html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload['contentType']).to eq('article')
      expect(payload['hostAware']).to be(false)
      expect(payload['markdown']).to include(
        'Measurements distinguish the different electrical events.',
        'The report records the limitations of existing protection.',
        'The observers published a complete account', 'Published measurements describe the observed electrical conditions'
      )
    end
  end

  it 'does not promote a hidden declared body over a visible media description' do
    with_url_page('https://research.example/reports/storms', declared_article_html(hidden: true)) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload['hostAware']).to be(true)
      expect(payload['markdown']).to include('A short metadata description')
      expect(payload['markdown']).not_to include('Published measurements describe')
    end
  end

  it 'does not borrow an article declaration with a conflicting headline' do
    with_url_page('https://research.example/reports/storms', declared_article_html(headline: 'Another reported event')) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload['hostAware']).to be(true)
      expect(payload['markdown']).to include('A short metadata description')
    end
  end

  it 'requires an explicit current canonical URL and unique owned headline before relaxing a stale slug' do
    url = 'https://journal.example/volcanic-eruption-forecast'
    [[url, false], ['https://journal.example/another-page', false], [url, true]].each do |canonical, competing|
      html = <<~HTML
        <html><head><title>Transport records updated</title><meta property="og:type" content="article">
          <link rel="canonical" href="#{canonical}"></head><body>#{"<h1>Competing report</h1>" if competing}<article><h1>Transport records updated</h1>
          <p>The council published detailed bus timetables and explained the revised routes, stop locations and connections with other public transport services.</p>
          <p>Readers can compare the complete schedules against the previous records, check the data collection method and inspect the decisions in their original context.</p>
        </article></body></html>
      HTML
      with_url_page(url, html) do |page|
        payload = FetchUtil::Extractor.new.extract(page)

        expect(payload['warnings'].include?('url_content_mismatch')).to eq(canonical != url || competing)
        expect(payload['warnings']).to eq(payload['warnings'].uniq)
        expect(payload['markdown']).to include('The council published detailed bus timetables', 'Readers can compare the complete schedules')
      end
    end
  end
end
