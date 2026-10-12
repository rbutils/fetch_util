# frozen_string_literal: true

RSpec.describe 'FetchUtil scoped article-ownership reads' do
  include_context 'extractor integration helpers'

  def article_read_source
    root = File.expand_path('../../..', __dir__)
    paths = File.readlines(File.join(root, 'websieve/manifest.txt'), chomp: true)
                .reject { |line| line.empty? || line.start_with?('#') }
    source = paths.map { |path| File.read(File.join(root, 'websieve', path)) }.join("\n")
    source.sub('})(window);', <<~JAVASCRIPT)
      global.withArticleRead = withArticleRouteRead;
      global.articleOwnership = articleRouteFocalContent;
      })(window);
    JAVASCRIPT
  end

  def article_read_page(html)
    with_url_page('https://publication.example.test/articles/2026/report', html) do |page|
      page.add_script_tag(content: article_read_source)
      yield page
    end
  end

  def owned_article
    <<~HTML
      <title>Owned field report</title><main><article id="report">
      <h1>Owned field report</h1>
      <p>The published field report records every observation and its attribution, including all measured details and the complete source context.</p>
      <p>The second reporting paragraph retains the explanation, the evidence and its ordering, rather than treating the article as a linked recommendation.</p>
      <p><a href="/references/report">Published reference</a></p>
      <pre>complete_example(value);</pre>
      </article></main>
    HTML
  end

  it 'reuses ownership evidence without rediscovering the source for every collection section' do
    result = article_read_page(owned_article) do |page|
      page.evaluate(<<~JAVASCRIPT)
        (() => {
          var before = document.body.innerHTML;
          var original = document.querySelectorAll;
          var descriptor = Object.getOwnPropertyDescriptor(document, 'querySelectorAll');
          var queries = 0;
          document.querySelectorAll = function() { queries += 1; return original.apply(this, arguments); };
          try {
            var expected = articleOwnership();
            var expectedOwner = articleOwnership(null, true);
            var baseline = queries;
            queries = 0;
            var answers = withArticleRead(function() {
              return Array.from({length: 200}, function() {
                return articleOwnership() === expected && articleOwnership(null, true) === expectedOwner;
              });
            });
            return {expected: expected, owner: expectedOwner.id, baseline: baseline,
              queries: queries, answers: answers, unchanged: before === document.body.innerHTML};
          } finally {
            if (descriptor) Object.defineProperty(document, 'querySelectorAll', descriptor);
            else delete document.querySelectorAll;
          }
        })()
      JAVASCRIPT
    end

    expect(result.fetch('expected')).to be(true)
    expect(result.fetch('owner')).to eq('report')
    expect(result.fetch('baseline')).to be_positive
    expect(result.fetch('queries')).to be <= result.fetch('baseline')
    expect(result.fetch('answers')).to eq(Array.new(200, true))
    expect(result.fetch('unchanged')).to be(true)
  end

  it 'rechecks ownership after metadata and rendered-content changes on the same object' do
    body_html = owned_article[%r{<h1>.*?(?=</article>)}m]
    result = article_read_page('<title>Source shell</title><main>Source shell</main>') do |page|
      page.evaluate(<<~JAVASCRIPT)
        withArticleRead(function() {
          var content = {contentType: 'article', title: 'Owned field report', byline: 'Published author',
            html: #{JSON.generate(body_html)}};
          var answers = [articleOwnership(content)];
          content.byline = null;
          answers.push(articleOwnership(content));
          content.publishedTime = '2026-04-15';
          answers.push(articleOwnership(content));
          content.html = '<p>No authored heading or complete body.</p>';
          answers.push(articleOwnership(content));
          content.html = #{JSON.generate(body_html)};
          content.contentType = 'portal';
          answers.push(articleOwnership(content));
          content.contentType = 'article';
          answers.push(articleOwnership(content));
          return answers;
        })
      JAVASCRIPT
    end

    expect(result).to eq([true, false, true, false, false, true])
  end

  it 'restores enclosing reads and keeps later source mutations fresh after an exception' do
    result = article_read_page(owned_article) do |page|
      page.evaluate(<<~JAVASCRIPT)
        (() => {
          var article = document.getElementById('report');
          var answers = [];
          try {
            withArticleRead(function() {
              answers.push(articleOwnership());
              article.hidden = true;
              try {
                withArticleRead(function() { answers.push(articleOwnership()); throw new Error('nested'); });
              } catch (error) { if (error.message !== 'nested') throw error; }
              article.hidden = false;
              answers.push(articleOwnership());
              throw new Error('outer');
            });
          } catch (error) { if (error.message !== 'outer') throw error; }
          article.hidden = true;
          answers.push(articleOwnership());
          article.hidden = false;
          answers.push(articleOwnership());
          return answers;
        })()
      JAVASCRIPT
    end

    expect(result).to eq([true, false, true, false, true])
  end
end
