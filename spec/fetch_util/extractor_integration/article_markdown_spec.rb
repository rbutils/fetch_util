# frozen_string_literal: true

RSpec.describe 'FetchUtil extractor integration' do
  include_context 'extractor integration helpers'

  it "converts tables into markdown instead of raw html" do
    html = <<~HTML
      <html>
        <body>
          <main>
            <article>
              <h1>Table Test</h1>
              <p>Reference data follows.</p>
              <table>
                <tr><th>Name</th><th>Value</th></tr>
                <tr><td>Alpha</td><td>One</td></tr>
              </table>
            </article>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://www.pinterest.com/search/pins/?q=ruby+programming", html) do |page|
      payload = FetchUtil::Extractor.new(reader_mode: false).extract(page)

      expect(payload["contentType"]).to eq("article")
      expect(payload["markdown"]).to include("| Name | Value |")
      expect(payload["markdown"]).to include("| Alpha | One |")
      expect(payload["markdown"]).not_to include("<table")
    end
  end

  it "removes undefined image placeholder text from markdown links" do
    html = <<~HTML
      <html>
        <head><title>Compound Record</title></head>
        <body>
          <main>
            <article>
              <h1>Compound Record</h1>
              <p>
                <a href="/compound.png" title="Download the structure image of undefined">
                  Download image
                </a>
              </p>
              <p><img src="/missing-alt.png" alt="undefined"></p>
              <p>The compound summary remains readable.</p>
            </article>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://example.test/compound", html) do |page|
      payload = FetchUtil::Extractor.new(reader_mode: false).extract(page)
      markdown = payload["markdown"]

      expect(markdown).to include("[Download image](https://example.test/compound.png)")
      expect(markdown).to include("The compound summary remains readable.")
      expect(markdown).not_to match(/undefined/i)
      expect(markdown).not_to include('"Download the structure image of')
    end
  end

  it "preserves legal citation link text with emphasized section letters" do
    html = <<~HTML
      <html>
        <head><title>Regulatory Authority</title></head>
        <body>
          <main>
            <article>
              <h1>Regulatory Authority</h1>
              <p>
                Authority: <a href="https://www.govinfo.gov/link/uscode/15/78l">78<em>l,</em></a>
                <a href="https://www.govinfo.gov/link/uscode/15/78o-4">78<em>o</em>-4</a>,
                <a href="https://www.govinfo.gov/link/uscode/15/78o-7">15 U.S.C. 78<em>o</em>-7 note</a>,
                <a href="https://www.govinfo.gov/link/uscode/15/78o78q">15 U.S.C. 78<em>o</em> 78q</a>,
                <a href="https://www.govinfo.gov/link/uscode/15/78">78</a><em>q</em>,
                and <a href="https://www.ecfr.gov/current/title-17/section-240.15">Section 240.15</a><em>l</em>-1.
              </p>
            </article>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://www.ecfr.gov/current/title-17/chapter-II/part-240", html) do |page|
      payload = FetchUtil::Extractor.new(reader_mode: false).extract(page)
      markdown = payload["markdown"]

      expect(markdown).to include("[78l,](https://www.govinfo.gov/link/uscode/15/78l)")
      expect(markdown).to include("[78o-4](https://www.govinfo.gov/link/uscode/15/78o-4)")
      expect(markdown).to include("[15 U.S.C. 78o-7 note](https://www.govinfo.gov/link/uscode/15/78o-7)")
      expect(markdown).to include("[15 U.S.C. 78o 78q](https://www.govinfo.gov/link/uscode/15/78o78q)")
      expect(markdown).to include("[78q](https://www.govinfo.gov/link/uscode/15/78)")
      expect(markdown).to include("[Section 240.15l-1](https://www.ecfr.gov/current/title-17/section-240.15)")
      expect(markdown).not_to include("78_l,_")
      expect(markdown).not_to include("78_o_")
      expect(markdown).not_to include("](https://www.govinfo.gov/link/uscode/15/78)_q_")
      expect(markdown).not_to include("_l_\\-1")
    end
  end

  it "prepends the page title when generic article markdown starts mid-content" do
    html = <<~HTML
      <html>
        <head><title>Definition of STEWARDESS</title></head>
        <body>
          <main>
            <article>
              <a href="/simple/stewardess">Simplify</a>
              <p><strong>:</strong> a woman who performs the duties of a steward</p>
            </article>
          </main>
        </body>
      </html>
    HTML

    with_page(html) do |page|
      payload = FetchUtil::Extractor.new(reader_mode: false).extract(page)

      expect(payload["markdown"]).to start_with("# Definition of STEWARDESS")
      expect(payload["markdown"]).to include("a woman who performs the duties of a steward")
    end
  end

  it "falls back to a safe clone when deep DOM cloning triggers custom-element errors" do
    html = <<~HTML
      <html>
        <body>
          <main>
            <article>
              <h1>Flight updates</h1>
              <p>Primary itinerary details remain readable.</p>
              <date-calendar-component>
                <div>June 12 departure</div>
              </date-calendar-component>
            </article>
          </main>
          <script>
            (() => {
              const originalCloneNode = Node.prototype.cloneNode;
              Node.prototype.cloneNode = function(deep) {
                if (deep && this.nodeType === Node.ELEMENT_NODE && this.tagName === 'DATE-CALENDAR-COMPONENT') {
                  throw new TypeError("Cannot read properties of undefined (reading 'slice')");
                }
                return originalCloneNode.call(this, deep);
              };
            })();
          </script>
        </body>
      </html>
    HTML

    with_page(html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["markdown"]).to include("Primary itinerary details remain readable.")
      expect(payload["warnings"]).not_to include("empty_extraction")
    end
  end

  it "falls back to shared article heuristics when Readability construction fails" do
    html = <<~HTML
      <html>
        <body>
          <main>
            <article>
              <h1>Forum updates</h1>
              <p>Main post text stays visible.</p>
              <section class="comments">
                <h2>Comments</h2>
                <p>Alice: First reply stays visible.</p>
                <p>Bob: Thanks for the update.</p>
              </section>
            </article>
          </main>
        </body>
      </html>
    HTML

    with_page(html) do |page|
      page.evaluate <<~JS
        Object.defineProperty(window, 'Readability', {
          configurable: true,
          set(value) {
            const BrokenReadability = function() {
              throw new TypeError("Cannot read properties of undefined (reading 'slice')");
            };

            BrokenReadability.prototype = value.prototype;
            Object.defineProperty(window, 'Readability', {
              value: BrokenReadability,
              configurable: true,
              writable: true
            });
          },
          get() {
            return undefined;
          }
        });
      JS

      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["markdown"]).to include("Main post text stays visible.")
      expect(payload["markdown"]).to include("Comments")
      expect(payload["markdown"]).to include("Alice: First reply stays visible.")
      expect(payload["markdown"]).to include("Bob: Thanks for the update.")
      expect(payload["warnings"]).not_to include("empty_extraction")
    end
  end

  it "preserves a focused news article body over donation and footer chrome" do
    paragraphs = (1..8).map do |index|
      "<p>Article body paragraph #{index} explains the switchback experiment design with enough standalone prose to identify the real content region.</p>"
    end.join

    html = <<~HTML
      <html>
        <head><title>Switchback Experiment Design</title></head>
        <body>
          <main id="site-main">
            <aside class="donation-cta">
              <h2>Support our charity</h2>
              <p>Donate to help people learn to code and support our nonprofit mission.</p>
              <a href="/donate">Donate now</a>
            </aside>
            <article>
              <h1>Switchback Experiment Design</h1>
              <section data-test-label="post-content" class="article-content prose">
                #{paragraphs}
                <h2>How Switchback Design Restores a Clean Comparison</h2>
                <p>The whole platform alternates between treatment and control slots, so shared model capacity no longer contaminates only one user group.</p>
              </section>
            </article>
            <footer>
              <h2>About freeCodeCamp</h2>
              <p>Our mission is to help people learn to code for free.</p>
              <a href="/news/about/">About</a>
              <a href="/donate/">Donate</a>
            </footer>
          </main>
        </body>
      </html>
    HTML

    with_url_page('https://www.freecodecamp.org/news/switchback-experiments-for-ai-platform-features-in-python/', html) do |page|
      payload = FetchUtil::Extractor.new(reader_mode: false).extract(page)

      expect(payload["contentType"]).to eq("article")
      expect(payload["markdown"]).to include("Article body paragraph 8")
      expect(payload["markdown"]).to include("How Switchback Design Restores a Clean Comparison")
      expect(payload["markdown"]).not_to include("Support our charity")
    end
  end

  it "prefers a full long document body over a short reader-mode fragment" do
    articles = (1..18).map do |index|
      <<~HTML
        <section class="cxl-section">
          <h2>Article #{index}</h2>
          <p>#{index}. This official instrument keeps operative clause #{index} in the consolidated body.</p>
          <p>The document paragraph for article #{index} remains part of the same legal text.</p>
        </section>
      HTML
    end.join

    html = <<~HTML
      <html>
        <head><title>Consolidated Official Instrument</title></head>
        <body>
          <main id="MainContent">
            <article id="notice-fragment">
              <table>
                <tr><td>1.1.2030</td><td>EN</td><td>Official Journal</td><td>C 1/1</td></tr>
              </table>
              <h1>Consolidated Official Instrument</h1>
              <p>Article 1</p>
              <p>Opening clause from the first visible fragment.</p>
            </article>
            <section id="text" class="cxl-body">
              <h1>Consolidated Official Instrument</h1>
              #{articles}
            </section>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://example.test/legal-content/EN/TXT/?uri=CELEX:LONGDOC", html) do |page|
      page.evaluate <<~JS
        Object.defineProperty(window, 'Readability', {
          configurable: true,
          set(value) {
            const FragmentReadability = function() {};
            FragmentReadability.prototype.parse = function() {
              return {
                title: 'Consolidated Official Instrument',
                content: document.querySelector('#notice-fragment').outerHTML,
                textContent: document.querySelector('#notice-fragment').textContent
              };
            };

            Object.defineProperty(window, 'Readability', {
              value: FragmentReadability,
              configurable: true,
              writable: true
            });
          },
          get() {
            return undefined;
          }
        });
      JS

      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["markdown"]).to include("Article 1")
      expect(payload["markdown"]).to include("Article 18")
      expect(payload["markdown"]).to include("operative clause 18")
      expect(payload["warnings"]).not_to include("truncated_content")
    end
  end

  it "drops obvious related-entry utility sections before markdown conversion" do
    html = <<~HTML
      <html>
        <head><title>Rare Entry</title></head>
        <body>
          <main>
            <article>
              <h1>Rare Entry</h1>
              <p>The main definition should stay in markdown.</p>
              <section>
                <h2>Nearby entries</h2>
                <ul>
                  <li><a href="/entry/one">Entry One</a></li>
                  <li><a href="/entry/two">Entry Two</a></li>
                  <li><a href="/entry/three">Entry Three</a></li>
                </ul>
              </section>
            </article>
          </main>
        </body>
      </html>
    HTML

    with_page(html) do |page|
      payload = FetchUtil::Extractor.new(reader_mode: false).extract(page)

      expect(payload["markdown"]).to include("The main definition should stay in markdown.")
      expect(payload["markdown"]).not_to include("Nearby entries")
      expect(payload["markdown"]).not_to include("Entry One")
    end
  end

  it "extracts glossary pages from definition-heavy roots instead of nearby-word chrome" do
    html = <<~HTML
      <html>
        <head><title>CONFEDERATIONIST Definition &amp; Meaning - Merriam-Webster</title></head>
        <body>
          <main>
            <article id="dictionary-entry-1" class="entry-body">
              <h1>confederationist</h1>
              <h2>noun</h2>
              <div class="dtText">: a supporter or adherent of a confederation or of a policy of confederating</div>
            </article>
            <section>
              <h2>Browse Nearby Words</h2>
              <ul>
                <li><a href="/dictionary/confederative">confederative</a></li>
                <li><a href="/dictionary/confederator">confederator</a></li>
                <li><a href="/dictionary/conferee">conferee</a></li>
              </ul>
            </section>
            <section>
              <h2>More from Merriam-Webster</h2>
              <p>Top Lookups</p>
            </section>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://www.merriam-webster.com/dictionary/confederationist", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["markdown"]).to include("a supporter or adherent of a confederation")
      expect(payload["markdown"]).not_to include("Browse Nearby Words")
      expect(payload["markdown"]).not_to include("Top Lookups")
      expect(payload["warnings"]).not_to include("truncated_content")
    end
  end

  it "removes repeated HTML5 audio fallback text from pronunciation output" do
    html = <<~HTML
      <html>
        <head><title>non-Celtic | Pronunciation in English</title></head>
        <body>
          <main>
            <article class="dictionary">
              <h1>non-Celtic</h1>
              <p>Your browser doesn't support HTML5 audio</p>
              <p>UK /non-kel-tik/</p>
              <ul>
                <li>Your browser doesn't support HTML5 audio /n/ as in name</li>
                <li>Your browser doesn't support HTML5 audio /k/ as in cat</li>
              </ul>
            </article>
          </main>
        </body>
      </html>
    HTML

    with_page(html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["markdown"]).to include("UK /non-kel-tik/")
      expect(payload["markdown"]).to include("/n/ as in name")
      expect(payload["markdown"]).not_to include("Your browser doesn't support HTML5 audio")
    end
  end

  it "falls back to metadata summaries when glossary extraction is dominated by utility chrome" do
    html = <<~HTML
      <html>
        <head>
          <title>DEPOPULATOR Definition &amp; Meaning - Merriam-Webster</title>
          <meta name="description" content="The meaning of DEPOPULATOR is one that depopulates. See the full definition.">
        </head>
        <body>
          <main>
            <article>
              <h1>Definition of DEPOPULATOR</h1>
              <section>
                <h2>Word History</h2>
                <p>Middle English, devastator.</p>
              </section>
              <section>
                <h2>Browse Nearby Words</h2>
                <ul>
                  <li><a href="/dictionary/depopulate">depopulate</a></li>
                  <li><a href="/dictionary/depopulation">depopulation</a></li>
                </ul>
              </section>
              <section>
                <h2>Cite this Entry</h2>
                <p>"Depopulator." Merriam-Webster.com Dictionary.</p>
              </section>
            </article>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://www.merriam-webster.com/dictionary/depopulator", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["markdown"]).to include("one that depopulates")
      expect(payload["markdown"]).not_to include("Browse Nearby Words")
      expect(payload["markdown"]).not_to include("Cite this Entry")
    end
  end

  it "uses metadata fallback for query-driven translation dictionary pages" do
    html = <<~HTML
      <html>
        <head>
          <title>whores - Tlumaczenie po polsku - Slownik angielsko-polski Diki</title>
          <meta name="description" content="whore - tlumaczenie na polski oraz definicja. Co znaczy i jak powiedziec whore po polsku? - zdzira, dziwka, kurwa; prostytutka">
        </head>
        <body>
          <main>
            <div class="promo-links">
              <a href="/dictionary/about">O slowniku Diki</a>
              <a href="https://www.etutor.pl/">Kurs angielskiego</a>
            </div>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://example.com/lookup?q=whores", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["markdown"]).to include("tlumaczenie na polski")
      expect(payload["markdown"]).to include("prostytutka")
      expect(payload["contentType"]).to eq("article")
    end
  end

  it "pairs term and description blocks on glossary pages that use p.term and p.desc" do
    html = <<~HTML
      <html>
        <head><title>Definitions for Whores</title></head>
        <body>
          <main>
            <h1>Definitions for Whores</h1>
            <section id="definitions-list">
              <div id="wikipedia">
                <p class="term">whore</p>
                <ol>
                  <li><p class="desc">A prostitute.</p></li>
                </ol>
              </div>
              <div id="wikidata">
                <p class="term">whore</p>
                <ol>
                  <li><p class="desc">An insulting term for a promiscuous person.</p></li>
                </ol>
              </div>
            </section>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://www.definitions.net/definition/Whores", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["markdown"]).to include("A prostitute")
      expect(payload["markdown"]).to include("promiscuous person")
      expect(payload["markdown"]).not_to include("Wikidata")
    end
  end

  it "extracts recipe schema content when the visible DOM is only a teaser" do
    html = <<~HTML
      <html>
        <head>
          <title>오이냉국 황금레시피</title>
          <script type="application/ld+json">
            {
              "@context": "https://schema.org",
              "@type": "Recipe",
              "name": "오이냉국 황금레시피",
              "description": "새콤하고 시원한 오이냉국 레시피입니다.",
              "recipeYield": "2 servings",
              "recipeIngredient": ["오이 1개", "물 800ml", "식초 2큰술"],
              "recipeInstructions": [
                "오이를 얇게 썬다.",
                "양념을 물에 풀어 냉국물을 만든다.",
                "오이를 넣고 차갑게 식혀 낸다."
              ]
            }
          </script>
        </head>
        <body>
          <main>
            <article>
              <h1>오이냉국 황금레시피</h1>
              <p>물 800ml, 식초 2큰술</p>
            </article>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://www.10000recipe.com/recipe/7054210", html) do |page|
      payload = FetchUtil::Extractor.new(reader_mode: false).extract(page)

      expect(payload["markdown"]).to include("## Ingredients")
      expect(payload["markdown"]).to include("오이 1개")
      expect(payload["markdown"]).to include("## Instructions")
      expect(payload["markdown"]).to include("양념을 물에 풀어 냉국물을 만든다")
    end
  end

  it "keeps long-form article pages in article mode even when related cards are present" do
    html = <<~HTML
      <html>
        <head><title>推しカラーの取り入れ方ガイド</title></head>
        <body>
          <main>
            <article class="article-body">
              <h1>推しカラーの取り入れ方ガイド</h1>
              <p>推しカラーを日常のメイクに取り入れるときは、色そのものの強さだけでなく、質感や配置のバランスを見ることが大切です。</p>
              <p>たとえば目もとに鮮やかな色を使う場合は、チークやリップを少し落ち着かせることで全体がまとまり、派手になりすぎずに楽しめます。</p>
              <p>また、ベースカラーを肌になじむ色に整えておくと、推しカラーがアクセントとして自然に見えやすくなります。</p>
              <p>イベント当日は写真写りも意識して、ラメ感やツヤ感を部分的に足すと、色の印象がよりきれいに伝わります。</p>
            </article>
            <aside class="related-grid">
              <h2>関連記事</h2>
              <ul>
                <li><a href="/related/1">推し活メイクの基本</a></li>
                <li><a href="/related/2">赤を使ったポイントメイク</a></li>
                <li><a href="/related/3">オレンジ系シャドウのなじませ方</a></li>
                <li><a href="/related/4">グリーンメイクの抜け感</a></li>
                <li><a href="/related/5">イベント向けの写真映えテク</a></li>
                <li><a href="/related/6">推し活ポーチの中身</a></li>
              </ul>
            </aside>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://example.com/column/favorite-color", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["contentType"]).to eq("article")
      expect(payload["markdown"]).to include("推しカラーを日常のメイクに取り入れるときは")
      expect(payload["markdown"]).not_to include("- [推し活メイクの基本]")
    end
  end

  it "prefers the prose article column over CTA and recent-posts sidebars" do
    article_paragraphs = 10.times.map do |index|
      "<p>Main article paragraph #{index + 1} explains how engineering teams diagnose user-impacting software issues before they become backlog clutter.</p>"
    end.join("\n")

    recent_cards = 4.times.map do |index|
      <<~HTML
        <article class="post-card">
          <a href="/recent-#{index + 1}"><h4>Recent product post #{index + 1}</h4></a>
          <p>Short sidebar summary #{index + 1} for another post.</p>
        </article>
      HTML
    end.join

    html = <<~HTML
      <html>
        <head><title>Self-improving software</title></head>
        <body>
          <main class="page-layout">
            <article class="article-content lr-content">
              <h1>Self-improving software</h1>
              #{article_paragraphs}
              <h2>How the system works</h2>
              <p>The article body continues with concrete implementation details and customer examples.</p>
            </article>
            <aside class="sidebar-container">
              <section class="footer-cta-container">
                <h2>Stop guessing about your digital experience</h2>
                <a href="/signup">Get started for free</a>
              </section>
              <section id="recent-posts">
                <h4>Recent posts:</h4>
                #{recent_cards}
              </section>
            </aside>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://blog.example.com/self-improving-software/", html) do |page|
      page.evaluate <<~JS
        Object.defineProperty(window, 'Readability', {
          configurable: true,
          set(value) {
            const SidebarReadability = function() {};
            SidebarReadability.prototype.parse = function() {
              const sidebar = document.querySelector('.sidebar-container');
              return {
                title: 'Self-improving software',
                content: sidebar.outerHTML,
                textContent: sidebar.textContent
              };
            };

            Object.defineProperty(window, 'Readability', {
              value: SidebarReadability,
              configurable: true,
              writable: true
            });
          },
          get() {
            return undefined;
          }
        });
      JS

      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["markdown"]).to include("# Self-improving software")
      expect(payload["markdown"]).to include("Main article paragraph 10 explains")
      expect(payload["markdown"]).to include("The article body continues with concrete implementation details")
      expect(payload["markdown"]).not_to include("Recent posts")
      expect(payload["markdown"]).not_to include("Get started for free")
    end
  end

  it "compacts long glossary descriptions from repeated source blocks" do
    html = <<~HTML
      <html>
        <head><title>What does Whores mean?</title></head>
        <body>
          <main>
            <h1>Definitions for Whores</h1>
            <section id="definitions-list">
              <div id="wikipedia" class="rc5">
                <h3>Wikipedia Rate this definition: 0.0 / 0 votes</h3>
                <ol>
                  <li class="wselect-cnt">
                    <p class="term">whores</p>
                    <p class="desc">Prostitution is the business or practice of engaging in sexual activity in exchange for payment. The definition of sexual activity varies, and is often defined as an activity requiring physical contact with the customer. The requirement of physical contact also creates the risk of transferring diseases. It occurs in a variety of forms and its legal status varies from country to country.</p>
                  </li>
                </ol>
              </div>
            </section>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://www.definitions.net/definition/Whores", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["markdown"]).to include("Prostitution is the business or practice")
      expect(payload["markdown"]).not_to include("risk of transferring diseases")
      expect(payload["warnings"]).not_to include("truncated_content")
    end
  end
end
