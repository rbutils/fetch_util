# frozen_string_literal: true

RSpec.describe 'FetchUtil physically owned declared news portals' do
  include_context 'extractor integration helpers'

  def declared_portal_page
    declarations = [
      { '@context' => 'https://schema.org', '@type' => 'NewsMediaOrganization', name: 'Published Daily', url: 'https://publication.example.test/',
        description: 'Independent public reporting and source references.' },
      { '@context' => 'https://schema.org', '@type' => 'WebSite', name: 'Published Daily', url: 'https://publication.example.test/' }
    ]
    records = (1..180).map do |number|
      <<~HTML
        <section><h2><a href="/reporting/#{number}">Published reporting #{number}</a></h2>
        <p>The complete materialized description #{number} retains its independent source context.</p>
        <p><a href="/resources/#{number}">Source reference #{number}</a> remains available.</p>
        <div class="byline">By Linked Writer #{number}</div></section>
      HTML
    end.join
    <<~HTML
      <html><head><title>Published Daily | Public reporting</title>
      <meta property="og:site_name" content="Published Daily"><meta property="og:title" content="Published Daily">
      <meta property="og:type" content="website"><meta property="article:published_time" content="2020-01-02"><meta name="author" content="Foreign homepage author">
      <link rel="canonical" href="https://publication.example.test/"><script type="application/ld+json">#{JSON.generate(declarations)}</script>
      </head><body class="layout-no-sidebars"><nav><a href="/navigation-control">Site navigation</a></nav><main>
      <h1 hidden>Hidden alternative branding</h1>#{records}
      <section><h2>Published explanation</h2><p>Independent authorial discussion about comments, privacy and subscriptions stays material.</p></section>
      <section hidden><h2><a href="/hidden">Hidden reporting</a></h2><p>Hidden record remains hidden.</p></section>
      </main><footer>Unrelated global footer</footer></body></html>
    HTML
  end

  def declared_portal_source
    root = File.expand_path('../../..', __dir__)
    paths = File.readlines(File.join(root, 'websieve/manifest.txt'), chomp: true).reject { |path| path.empty? || path.start_with?('#') }
    paths.map { |path| File.read(File.join(root, 'websieve', path)) }.join("\n").sub('})(window);', <<~JAVASCRIPT)
      global.hasDeclaredNewsPortal = function() { return !!declaredNewsPortalContext({title: document.title}); };
      })(window);
    JAVASCRIPT
  end

  it 'retains every current physical collection without revealing hidden branding or borrowing a story date' do
    extract_from_url('https://publication.example.test/', declared_portal_page) do |payload|
      (1..180).each do |number|
        expect(payload['html']).to include("Published reporting #{number}", "description #{number}", "/resources/#{number}")
        expect(payload['markdown']).to include("Published reporting #{number}", "description #{number}", "/resources/#{number}")
      end
      positions = (1..180).map { |number| payload['markdown'].index("Published reporting #{number}]") }
      expect(positions).to eq(positions.sort)
      expect(payload['title']).to eq('Published Daily')
      expect(payload['contentType']).to eq('list')
      expect(payload['publishedTime']).to be_nil
      expect(payload['byline']).to be_nil
      expect(payload['markdown']).to include('Independent authorial discussion about comments, privacy and subscriptions')
      expect(payload['markdown']).not_to include('Hidden alternative branding', 'Hidden record', 'Site navigation', 'Unrelated global footer')
    end
  end

  it 'declines missing, foreign, conflicting, multiple and hidden physical identities' do
    html = declared_portal_page
    cases = [
      html.sub('"NewsMediaOrganization"', '"Organization"'),
      html.sub('"name":"Published Daily"', '"name":"Foreign name"'),
      html.sub('"url":"https://publication.example.test/"', '"url":"https://foreign.example.test/"'),
      html.sub('content="Published Daily"', 'content="Conflicting portal"'),
      html.sub('<main>', '<main hidden>'),
      html.sub('</main>', '</main><main><h2>Other primary region</h2></main>'),
      html.sub('rel="canonical" href="https://publication.example.test/"', 'rel="canonical" href="https://foreign.example.test/"')
    ]
    cases.each do |candidate|
      with_url_page('https://publication.example.test/', candidate) do |page|
        page.add_script_tag(content: declared_portal_source)
        expect(page.evaluate('hasDeclaredNewsPortal()')).to be false
      end
    end
    with_url_page('https://publication.example.test/reporting/1', html) do |page|
      page.add_script_tag(content: declared_portal_source)
      expect(page.evaluate('hasDeclaredNewsPortal()')).to be false
    end
    with_page(html.gsub('https://publication.example.test/', 'about:blank')) do |page|
      page.add_script_tag(content: declared_portal_source)
      expect(page.evaluate('hasDeclaredNewsPortal()')).to be false
    end
  end

  it 'keeps complete materialized clipped collections and authored newsletter-layout reporting while retaining real hidden boundaries' do
    cards = (1..12).map do |number|
      "<div style=\"flex:0 0 220px\"><h2><a href=\"/carousel/#{number}\">Carousel report #{number}</a></h2><p>Complete carousel context #{number}.</p></div>"
    end.join
    writers = (1..4).map do |number|
      "<div><p>Published writer #{number}</p><h3><a href=\"/columns/#{number}\">Published column #{number}</a></h3><p>Independent column context #{number}.</p></div>"
    end.join
    material = <<~HTML
      <section><h2>Published carousel</h2><div style="display:flex;width:220px;overflow-x:hidden">#{cards}</div></section>
      <section class="blogs-newsletter"><h2>Published columns</h2>#{writers}
      <form><input type="email"><button>Subscribe control</button></form></section>
      <figure><picture><source srcset="https://images.example.test/alternate.jpg 1600w"><img alt="Published source illustration" src="https://images.example.test/original.jpg"></picture><figcaption>Complete illustration caption.</figcaption></figure>
      <div style="display:none"><h2><a href="/display-hidden">Display-hidden reporting</a></h2></div>
      <div style="opacity:0"><h2><a href="/opacity-hidden">Opacity-hidden reporting</a></h2></div>
      <div style="visibility:hidden"><h2><a href="/visibility-hidden">Visibility-hidden reporting</a></h2></div>
    HTML
    html = declared_portal_page.sub('</main>', "#{material}</main>")
    extract_from_url('https://publication.example.test/', html) do |payload|
      (1..12).each do |number|
        expect(payload['html']).to include("Carousel report #{number}", "carousel context #{number}", "/carousel/#{number}")
        expect(payload['markdown']).to include("Carousel report #{number}", "carousel context #{number}", "/carousel/#{number}")
      end
      (1..4).each do |number|
        expect(payload['html']).to include("Published writer #{number}", "Published column #{number}", "column context #{number}", "/columns/#{number}")
        expect(payload['markdown']).to include("Published writer #{number}", "Published column #{number}", "column context #{number}", "/columns/#{number}")
      end
      expect(payload['markdown']).not_to include('Display-hidden reporting', 'Opacity-hidden reporting', 'Visibility-hidden reporting', 'Subscribe control')
      expect(payload['html']).to include('https://images.example.test/original.jpg', 'Complete illustration caption.')
      expect(payload['markdown']).to include('https://images.example.test/original.jpg', 'Complete illustration caption.')
      expect(payload['html']).not_to include('<form', '<button', 'Subscribe control')
      expect(payload['byline']).to be_nil
      expect(payload['publishedTime']).to be_nil
    end
  end
end
