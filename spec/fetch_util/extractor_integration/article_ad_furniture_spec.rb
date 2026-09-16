# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'generic article advertisement cleanup' do
  include_context 'extractor integration helpers'

  def article_ad_furniture_source
    root = File.expand_path('../../..', __dir__)
    source = File.readlines(File.join(root, 'websieve/manifest.txt'), chomp: true)
                 .reject { |line| line.empty? || line.start_with?('#') }
                 .map { |path| File.read(File.join(root, 'websieve', path)) }.join("\n")
    source.sub(
      '})(window);',
      'global.__genericArticleAdFurniture = genericArticleAdFurniture; })(window);'
    )
  end

  it 'removes exact ads furniture while preserving similarly named editorial content' do
    html = <<~HTML
      <!doctype html>
      <html><head><title>Regional reporting</title></head><body>
        <main><article>
          <h1>Regional reporting</h1>
          <p>Residents described how the river restoration changed daily travel and protected homes during the winter storms.</p>
          <p class="ads-story">The editorial desk documented the engineering decisions, funding sources, and public consultation behind the project.</p>
          <p>The completed work now reconnects several neighborhoods while preserving the wetlands beside the old railway bridge.</p>
          <div class="feature ads compact">Subscribe to the digital edition</div>
        </article></main>
      </body></html>
    HTML

    with_url_page('https://example.test/reporting/river-restoration', html) do |page|
      source_html = page.evaluate('document.body.innerHTML')
      result = extract(page)

      expect(result.fetch('markdown')).to include('The editorial desk documented the engineering decisions')
      expect(result.fetch('markdown')).not_to include('Subscribe to the digital edition')
      expect(result.fetch('html')).not_to include('Subscribe to the digital edition')
      expect(result.fetch('textContent')).not_to include('Subscribe to the digital edition')
      expect(page.evaluate('document.body.innerHTML')).to eq(source_html)
    end
  end

  it 'preserves substantive prose inside an exact ads owner' do
    article = <<~HTML
      <!doctype html>
      <html><head><title>Advertising industry analysis</title></head><body>
        <main><article>
          <h1>Advertising industry analysis</h1>
          <section class="ads">
            <p>Independent publishers are changing how they measure campaigns as privacy rules alter the data available to editorial businesses.</p>
            <p>The analysis compares direct subscriptions, sponsorships, and conventional advertising across several regional publications.</p>
            <p>Editors said the transition requires clearer labeling while preserving the reporting that readers expect from local newsrooms.</p>
          </section>
        </article></main>
      </body></html>
    HTML

    with_url_page('https://example.test/analysis/advertising', article) do |page|
      result = extract(page)

      expect(result.fetch('markdown')).to include('Independent publishers are changing how they measure campaigns')
      expect(result.fetch('markdown')).to include('The analysis compares direct subscriptions')
      expect(result.fetch('markdown')).to include('Editors said the transition requires clearer labeling')
    end
  end

  it 'preserves long single-paragraph and short multi-paragraph exact ads owners' do
    html = <<~HTML
      <!doctype html>
      <html><head><title>Editorial boundary report</title></head><body>
        <main><article>
          <h1>Editorial boundary report</h1>
          <div id="long-prose" class="ads">
            <p>#{"This long editorial paragraph documents the public-interest investigation and its independently verified findings. " * 4}</p>
          </div>
          <div id="short-paragraphs" class="ads">
            <p>First concise finding remains material.</p>
            <p>Second concise finding remains material.</p>
          </div>
          <p id="short-editorial" class="ads">A concise editorial correction remains material.</p>
          <h2 id="short-heading" class="ads">Community investigation</h2>
        </article></main>
      </body></html>
    HTML

    with_url_page('https://example.test/reporting/editorial-boundaries', html) do |page|
      page.add_script_tag(content: article_ad_furniture_source)
      decisions = page.evaluate(<<~JS)
        ['long-prose', 'short-paragraphs', 'short-editorial', 'short-heading'].map(function(id) {
          return window.__genericArticleAdFurniture(document.getElementById(id));
        });
      JS

      expect(decisions).to eq([false, false, false, false])
    end
  end

  it 'preserves a link-rich non-English collection inside an exact ads owner' do
    html = <<~HTML
      <!doctype html>
      <html><head><title>地域ニュース</title></head><body>
        <main><article>
          <h1>地域ニュース</h1>
          <div id="regional-links" class="ads">
            <a href="/region/one">地域調査の第一報</a>
            <a href="/region/two">地域調査の第二報</a>
            <a href="/region/three">地域調査の第三報</a>
          </div>
          <p>この特集では地域で進められている公共事業について詳しく報告します。</p>
        </article></main>
      </body></html>
    HTML

    with_url_page('https://example.test/reporting/region', html) do |page|
      page.add_script_tag(content: article_ad_furniture_source)

      expect(page.evaluate(<<~JS)).to eq(false)
        window.__genericArticleAdFurniture(document.getElementById('regional-links'));
      JS
    end
  end

  it 'preserves a substantive semantic article nested in an exact ads owner' do
    html = <<~HTML
      <!doctype html>
      <html><head><title>Community archive opens</title></head><body>
        <main class="ads">
          <article itemprop="articleBody">
            <h1>Community archive opens</h1>
            <p>The new archive brings together oral histories, photographs, and maps donated by families across the county.</p>
            <p>Researchers catalogued the collection over three years and created public indexes for schools and local historians.</p>
            <p>The reading room opens this month with weekly workshops led by volunteers who helped preserve the original material.</p>
          </article>
        </main>
      </body></html>
    HTML

    with_url_page('https://example.test/culture/archive-opens', html) do |page|
      result = extract(page)

      expect(result.fetch('markdown')).to include('The new archive brings together oral histories')
      expect(result.fetch('markdown')).to include('The reading room opens this month')
    end
  end

  it 'recognizes tokenized semantic ownership inside exact ads owners' do
    html = <<~HTML
      <!doctype html>
      <html><head><title>Semantic ownership report</title></head><body>
        <main><article>
          <h1>Semantic ownership report</h1>
          <div id="role-owner" class="ads">
            <section role="main region">
              <p>Role-based focal reporting remains visible.</p>
            </section>
          </div>
          <section id="itemprop-owner" class="ads" itemprop="articleBody headline">
            <p>Itemprop-based focal reporting remains visible.</p>
          </section>
        </article></main>
      </body></html>
    HTML

    with_url_page('https://example.test/reporting/semantic-ownership', html) do |page|
      page.add_script_tag(content: article_ad_furniture_source)
      decisions = page.evaluate(<<~JS)
        ['role-owner', 'itemprop-owner'].map(function(id) {
          return window.__genericArticleAdFurniture(document.getElementById(id));
        });
      JS

      expect(decisions).to eq([false, false])
    end
  end
end
