# frozen_string_literal: true

RSpec.describe 'FetchUtil declared homepage collection headings' do
  include_context 'extractor integration helpers'

  def subsection_homepage_html
    declarations = {
      '@context' => 'https://schema.org', '@graph' => [
        { '@type' => 'WebPage', '@id' => 'https://publication.example.test/', url: 'https://publication.example.test/',
          name: 'Public reporting | Independent Publisher', datePublished: '2020-01-02',
          isPartOf: { '@id' => 'https://publication.example.test/#website' } },
        { '@type' => 'WebSite', '@id' => 'https://publication.example.test/#website', url: 'https://publication.example.test/',
          name: 'Independent Publisher' }
      ]
    }
    sections = [1..201, 202..402, 403..603].each_with_index.map do |numbers, index|
      records = numbers.map do |number|
        <<~HTML
          <li class="wp-block-post"><h2 class="wp-block-post-title"><a href="/reporting/#{number}">Reporting record #{number}</a></h2>
            <p>Complete authored description #{number} discusses comments, privacy and public reporting.</p>
            <p><a href="/sources/#{number}">Independent source #{number}</a> remains available.</p></li>
        HTML
      end.join
      heading = index == 1 ? '<h1>A separately headed interview collection</h1>' : "<h2>Collection #{index + 1}</h2>"
      <<~HTML
        <section class="wp-block-group">#{heading}<div class="wp-block-query">
          <ul class="wp-block-post-template">#{records}</ul></div></section>
      HTML
    end.join
    <<~HTML
      <html><head><title>Public reporting | Independent Publisher</title>
        <meta name="generator" content="WordPress"><meta name="author" content="Unowned global writer">
        <meta property="og:type" content="website"><meta property="og:title" content="Public reporting">
        <meta property="og:site_name" content="Independent Publisher"><meta property="og:url" content="https://publication.example.test/">
        <link rel="canonical" href="https://publication.example.test/">
        <script type="application/ld+json">#{JSON.generate(declarations)}</script></head>
        <body><nav><a href="/menu">Navigation control</a></nav><div class="entry-content wp-block-post-content">#{sections}
          <p>Independent reporting context remains visible outside the interview section.</p>
          <noscript>Unrendered fallback marker <img src="/unrendered-fallback.png"></noscript>
          <template>Unrendered template marker <a href="/unrendered-template">Unrendered template link</a></template>
          <p>Published literal <code>&lt;noscript&gt;authored example&lt;/noscript&gt;</code> remains part of the reporting.</p>
          <section hidden><h2><a href="/hidden">Hidden reporting</a></h2></section>
        </div><footer>Global footer control</footer></body></html>
    HTML
  end

  def subsection_homepage_source
    root = File.expand_path('../../..', __dir__)
    paths = File.readlines(File.join(root, 'websieve/manifest.txt'), chomp: true).reject { |path| path.empty? || path.start_with?('#') }
    paths.map { |path| File.read(File.join(root, 'websieve', path)) }.join("\n").sub('})(window);', <<~JAVASCRIPT)
      global.subsectionHomepageOwns = function() {
        var root = document.querySelector('.wp-block-post-content');
        return homepageFragmentPageRoot(root) === document.body;
      };
      })(window);
    JAVASCRIPT
  end

  it 'retains all page collections without borrowing the later subsection identity or a creation date' do
    extract_from_url('https://publication.example.test/', subsection_homepage_html) do |payload|
      (1..603).each do |number|
        %w[html markdown].each do |format|
          expect(payload.fetch(format)).to include("Reporting record #{number}", "description #{number}", "/sources/#{number}")
        end
      end
      positions = (1..603).map { |number| payload.fetch('markdown').index("Reporting record #{number}]") }
      expect(positions).to eq(positions.sort)
      expect(payload.fetch('title')).to eq('Public reporting')
      expect(payload.fetch('contentType')).to eq('list')
      expect(payload['byline']).to be_nil
      expect(payload['publishedTime']).to be_nil
      expect(payload.fetch('markdown')).to include('Independent reporting context remains visible', 'A separately headed interview collection')
      expect(payload.fetch('markdown')).not_to include('Hidden reporting', 'Navigation control', 'Global footer control')
      expect(payload.fetch('html')).not_to include('<noscript', '<template', 'Unrendered fallback marker', 'Unrendered template marker')
      expect(payload.fetch('markdown')).not_to include('Unrendered fallback marker', 'Unrendered template marker', '/unrendered-fallback.png', '/unrendered-template')
      expect(payload.fetch('html')).to include('&lt;noscript&gt;authored example&lt;/noscript&gt;')
      expect(payload.fetch('markdown')).to include('`<noscript>authored example</noscript>`')
    end
  end

  it 'declines conflicting page declarations, unbounded headings and missing earlier query ownership with fresh source reads' do
    with_url_page('https://publication.example.test/', subsection_homepage_html) do |page|
      page.execute(subsection_homepage_source)
      result = page.evaluate(<<~'JAVASCRIPT')
        (() => {
          var original = document.documentElement.innerHTML;
          var mutations = [
            function() { document.querySelector("meta[property='og:url']").content = 'https://foreign.example.test/'; },
            function() { document.querySelector("meta[property='og:type']").content = 'article'; },
            function() { var meta = document.createElement('meta'); meta.setAttribute('property', 'og:title'); meta.content = 'Conflicting page'; document.head.appendChild(meta); },
            function() { var node = document.querySelector('h1'); document.querySelector('.wp-block-post-content').prepend(node); },
            function() { document.querySelector('.wp-block-group').remove(); },
            function() { document.querySelector('h1').textContent = 'Public reporting'; },
            function() { document.querySelector('h1').hidden = true; },
            function() { var node = document.createElement('h1'); node.textContent = 'Another primary heading'; document.querySelector('.wp-block-post-content').appendChild(node); },
            function() { var node = document.createElement('script'); node.type = 'application/ld+json'; node.textContent = JSON.stringify({'@type':'NewsArticle',headline:'A separately headed interview collection',url:location.href}); document.head.appendChild(node); }
          ];
          var outcomes = mutations.map(function(mutate) {
            document.documentElement.innerHTML = original;
            mutate();
            var declined = !window.subsectionHomepageOwns();
            document.documentElement.innerHTML = original;
            return {declined:declined,restored:window.subsectionHomepageOwns()};
          });
          return {outcomes:outcomes,unchanged:document.documentElement.innerHTML === original};
        })()
      JAVASCRIPT
      expect(result.fetch('outcomes')).to eq(Array.new(9) { { 'declined' => true, 'restored' => true } })
      expect(result.fetch('unchanged')).to be(true)
    end
  end
end
