# frozen_string_literal: true

RSpec.describe 'FetchUtil declared software landing ownership' do
  include_context 'extractor integration helpers'

  def software_landing_html
    application = {
      '@context' => 'https://schema.org', '@type' => 'SoftwareApplication', name: 'Example Reader',
      url: 'https://publication.example.test/', operatingSystem: 'Web',
      offers: %w[Free Premium Archive].map { |name| { '@type' => 'Offer', name: name, price: '0', priceCurrency: 'USD' } }
    }
    features = (1..603).map do |number|
      <<~HTML
        <section><h2>Published feature #{number}</h2>
          <p>Complete feature #{number} discusses comments, subscriptions and privacy without becoming a control.</p>
          <p><a href="/guide/#{number}">Feature resource #{number}</a> remains published.</p></section>
      HTML
    end.join
    <<~HTML
      <html><head><title>Example Reader — Public software</title><meta property="og:title" content="Example Reader - Public software">
        <meta property="og:type" content="website"><meta property="og:url" content="https://publication.example.test/">
        <meta name="author" content="Unowned developer"><meta name="date" content="2020-01-02">
        <meta name="description" content="Example Reader offers complete public features, plans and documentation.">
        <script type="application/ld+json">#{JSON.generate(application)}</script></head><body>
        <div hidden><h2>Hidden application interface</h2><a href="/hidden">Hidden control</a></div>
        <div id="software-page"><img src="/logo.png" alt="Example Reader">#{features}
          <section id="plans"><h2>Published plans</h2><div>Free</div><button>Premium</button><div>Archive</div>
            <p>Repeated published plan information.</p><p>Repeated published plan information.</p>
            <p>Repeated published plan information.</p><p>Repeated published plan information.</p></section>
          <section><h2>Published questions</h2><h3><button>Can I read comments?</button></h3><p>Yes, published replies remain available.</p></section>
          <section><h2>Community updates</h2><ul><li><a href="https://community.example.test/topic/404">RSS error 404 discussion</a></li></ul></section>
          <form><label for="email">Email</label><input id="email" type="email"><input type="password">
            <span>Please sign in</span><button>Register</button>
            <p>Authored form context <a href="/terms">Published terms</a> remains visible.</p></form>
          <pre><code>const sample = "&lt;noscript&gt;literal&lt;/noscript&gt;";</code></pre>
          <noscript>Unrendered fallback marker</noscript><template>Unrendered template marker</template>
          <footer><p>Published product attribution <a href="/creator">Example Developer</a>.</p><a href="/api">API reference</a></footer>
        </div></body></html>
    HTML
  end

  def software_landing_probe_source
    root = File.expand_path('../../..', __dir__)
    paths = File.readlines(File.join(root, 'websieve/manifest.txt'), chomp: true).reject { |path| path.empty? || path.start_with?('#') }
    paths.map { |path| File.read(File.join(root, 'websieve', path)) }.join("\n").sub('})(window);', <<~JAVASCRIPT)
      global.softwareLandingOwns = function() { return !!sourceOwnedSoftwareLandingContext(collectMetadata()); };
      })(window);
    JAVASCRIPT
  end

  it 'retains every public feature, plan, reference, repeated paragraph, program and footer without borrowing topic identity' do
    extract_from_url('https://publication.example.test/', software_landing_html) do |payload|
      (1..603).each do |number|
        %w[html markdown].each do |format|
          expect(payload.fetch(format)).to include("Published feature #{number}", "Complete feature #{number}", "/guide/#{number}")
        end
      end
      positions = (1..603).map { |number| payload.fetch('markdown').index("Published feature #{number}\n") }
      expect(positions).to eq(positions.sort)
      expect(payload.fetch('title')).to eq('Example Reader - Public software')
      expect(payload.fetch('contentType')).to eq('product')
      expect(payload['byline']).to be_nil
      expect(payload['publishedTime']).to be_nil
      expect(payload['price']).to be_nil
      %w[html markdown].each do |format|
        expect(payload.fetch(format)).to include('Free', 'Premium', 'Archive', 'Can I read comments?', '/terms', '/creator', '/api', '/topic/404')
        expect(payload.fetch(format).scan('Repeated published plan information.').length).to eq(4)
        expect(payload.fetch(format)).not_to include('Hidden application interface', '/hidden', 'Unrendered fallback marker', 'Unrendered template marker')
      end
      expect(payload.fetch('html')).not_to match(/<(?:input|select|textarea|button|form|noscript|template)\b/)
      expect(payload.fetch('markdown')).to include('const sample = "<noscript>literal</noscript>";')
      expect(payload.fetch('warnings')).not_to include('not_found_interstitial', 'auth_or_login_interstitial')
    end
  end

  it 'retains a genuine login-only classification despite an application declaration' do
    html = software_landing_html.split('<body>').first + <<~HTML
      <body><main><h1>Sign in to continue</h1><form>
        <input type="email"><input type="password"><button>Sign in</button>
      </form></main></body></html>
    HTML
    extract_from_url('https://publication.example.test/', html) do |payload|
      expect(payload.fetch('contentType')).to eq('interstitial')
      expect(payload.fetch('warnings')).to include('auth_or_login_interstitial')
    end
  end

  it 'declines foreign, incomplete, hidden, competing and unbounded ownership and rechecks restored physical sources' do
    with_url_page('https://publication.example.test/', software_landing_html) do |page|
      page.execute(software_landing_probe_source)
      result = page.evaluate(<<~'JAVASCRIPT')
        (() => {
          var original = document.documentElement.innerHTML;
          var mutations = [
            function() { var script = document.querySelector('script[type="application/ld+json"]'); var value = JSON.parse(script.textContent); value.url = 'https://foreign.example.test/'; script.textContent = JSON.stringify(value); },
            function() { document.querySelector("meta[property='og:url']").content = 'https://foreign.example.test/'; },
            function() { document.querySelector("meta[property='og:title']").content = 'Foreign application'; },
            function() { document.querySelector('#plans').remove(); },
            function() { document.querySelector('#plans').hidden = true; },
            function() { document.querySelector('img[alt]').alt = 'Different product'; },
            function() { var node = document.createElement('p'); node.textContent = 'Independent outside reporting'; document.body.appendChild(node); },
            function() { var node = document.createElement('article'); node.textContent = 'Competing article owner'; document.querySelector('#software-page').appendChild(node); },
            function() { var node = document.createElement('script'); node.type = 'application/ld+json'; node.textContent = JSON.stringify({'@type':'NewsArticle',headline:'Competing article',url:location.href}); document.head.appendChild(node); },
            function() { document.querySelector('#software-page').hidden = true; },
            function() { var node = document.createElement('section'); node.innerHTML = '<h2>Independent outside section</h2><p>Separate material.</p>'; document.body.appendChild(node); }
          ];
          var outcomes = mutations.map(function(mutate) {
            document.documentElement.innerHTML = original;
            mutate();
            var declined = !window.softwareLandingOwns();
            document.documentElement.innerHTML = original;
            return {declined:declined,restored:window.softwareLandingOwns()};
          });
          return {outcomes:outcomes,unchanged:document.documentElement.innerHTML === original};
        })()
      JAVASCRIPT
      expect(result.fetch('outcomes')).to eq(Array.new(11) { { 'declined' => true, 'restored' => true } })
      expect(result.fetch('unchanged')).to be(true)
    end
  end
end
