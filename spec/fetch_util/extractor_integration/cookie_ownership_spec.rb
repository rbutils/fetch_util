# frozen_string_literal: true

RSpec.describe 'Cookie notice ownership' do
  include_context 'extractor integration helpers'

  def cookie_ownership(body)
    root = File.expand_path('../../..', __dir__)
    source = File.readlines(File.join(root, 'websieve/manifest.txt'), chomp: true).filter_map do |path|
      next if path.empty? || path.start_with?('#')

      content = File.read(File.join(root, 'websieve', path))
      next content unless path == '99_outro.js'

      <<~JS + content
        global.__cookieOwnership = function() {
          var before = document.documentElement.outerHTML;
          var notices = Array.from(document.querySelectorAll("[data-probe]"));
          var cookieCleaned = document.body.cloneNode(true);
          cleanupCookieChrome(cookieCleaned);
          var cleaned = cleanClone(document.body);
          return {
            body: cookieChromeNode(document.body),
            notices: notices.map(function(node) { return cookieChromeNode(node); }),
            cleaned: cleaned.textContent,
            cookieCleanedMediaCount: cookieCleaned.querySelectorAll("iframe, embed, object, picture").length,
            cookieCleanedIframeSrc: (cookieCleaned.querySelector("iframe") || {}).src || null,
            mutated: before !== document.documentElement.outerHTML
          };
        };
      JS
    end.join("\n")
    with_url_page('https://publisher.example/', "<html><body>#{body}</body></html>") do |page|
      page.add_script_tag(content: source)
      return JSON.parse(page.evaluate('JSON.stringify(window.__cookieOwnership())'))
    end
  end

  it 'retains a short homepage whose only consent wording belongs to policy links' do
    result = cookie_ownership(<<~HTML)
      <div data-probe>
        <main><h1>Travel with confidence</h1><p>Choose the service that fits your journey.</p>
          <a href="/enrollment">Enrollment locations</a><a href="/mobile">Mobile service</a></main>
        <footer><a href="/privacy">Privacy Policy</a><a href="/cookies">Cookie Policy</a>
          <a href="/choices">Your privacy choices</a></footer>
      </div>
    HTML

    expect(result.values_at('body', 'notices')).to eq([false, [false]])
    expect(result['cleaned']).to include('Travel with confidence', 'Enrollment locations', 'Mobile service')
  end

  it 'continues recognizing unbranded notices with real consent prose' do
    result = cookie_ownership(<<~HTML)
      <div data-probe><p>We use cookies to improve your experience.</p>
        <a href="/privacy">Privacy Policy</a><button>Accept all</button></div>
    HTML

    expect(result.values_at('body', 'notices')).to eq([true, [true]])
    expect(result['cleaned']).to be_empty
  end

  it 'continues removing vendor containers and explicit consent dialogs' do
    result = cookie_ownership(<<~HTML)
      <main><h1>Public information</h1><p>Service hours and locations.</p></main>
      <div id="onetrust-banner-sdk" data-probe><a href="/privacy">Privacy Policy</a></div>
      <div role="dialog" data-probe><a href="/privacy">Privacy Policy</a>
        <a href="/cookies">Cookie Settings</a><button>Accept all</button></div>
    HTML

    expect(result['body']).to be(false)
    expect(result['notices']).to eq([true, true])
    expect(result['cleaned']).to include('Public information', 'Service hours and locations.')
    expect(result['cleaned']).not_to include('Privacy Policy', 'Cookie Settings')
  end

  it 'preserves layout tokens and attributes that merely contain abbreviated vendor names' do
    result = cookie_ownership(<<~HTML)
      <main><h1>Regional dispatches</h1>
        <div class="sticky-top" data-probe><p>Harbour dispatch.</p></div>
        <div class="sticky top-[--column-sticky-top]" data-probe><p>Valley dispatch.</p></div>
        <div class="min-h-[--ot-sdk-content]" data-probe><p>Mountain dispatch.</p></div>
        <section class="top-[--ot-scroll-top]" data-probe><p>Forest dispatch.</p></section>
        <div id="city-cky-plan" aria-label="Guide to ot-controls" data-testid="card-cky-text" data-probe>
          <p>Island dispatch.</p>
        </div>
      </main>
    HTML

    expect(result['notices']).to eq([false, false, false, false, false])
    expect(result['cleaned']).to include(
      'Harbour dispatch.', 'Valley dispatch.', 'Mountain dispatch.', 'Forest dispatch.', 'Island dispatch.'
    )
  end

  it 'recognizes abbreviated vendor class and id tokens without requiring notice prose' do
    result = cookie_ownership(<<~HTML)
      <main><h1>Public service information</h1><p>Visit the local office.</p></main>
      <div class="panel CKY-CONSENT-CONTAINER" data-probe>Vendor panel alpha</div>
      <div class="cky-overlay" data-probe>Vendor panel beta</div>
      <div id="ot-pc-content" data-probe>Vendor panel gamma</div>
      <div class="panel ot-sdk-container" data-probe>Vendor panel delta</div>
    HTML

    expect(result['body']).to be(false)
    expect(result['notices']).to eq([true, true, true, true])
    expect(result['cleaned']).to include('Public service information', 'Visit the local office.')
    expect(result['cleaned']).not_to include('Vendor panel')
  end

  it 'removes bounded external-content consent placeholders without matching publisher prose' do
    result = cookie_ownership(<<~HTML)
      <main><h1>Public service information</h1><p>Visit the local office.</p>
        <div class="CMPPlaceholder__Wrapper-sc-a1b2c3-0" data-probe>
          External content requires consent before third-party posts can be shown.
        </div>
        <div class="external-content-consent-placeholder" data-probe>
          <p>Choose whether to load content from another provider.</p><button>Continue</button>
        </div>
        <div class="external-content-consent-card" data-probe>
          <h2>External consent documentation</h2>
          <p>This guide explains how editors review third-party media.</p>
        </div>
        <article class="consent-placeholder-analysis" data-probe>
          <h2>How embedded media consent works</h2>
          <p>Publishers increasingly ask readers before loading external media.</p>
          <p>This report compares the privacy effects across several platforms.</p>
          <p>Researchers describe which consent designs give readers a meaningful choice.</p>
        </article>
        <div class="CMPPlaceholder__Wrapper-sc-a1b2c3-0" data-probe>
          <h2>Recorded briefing</h2><iframe src="https://video.example/embed/briefing"></iframe>
        </div>
        <div class="campaign-placeholder" data-probe><p>Community campaign schedule.</p></div>
      </main>
    HTML

    expect(result['notices']).to eq([true, true, false, false, false, false])
    expect(result['cleaned']).to include(
      'Public service information',
      'External consent documentation',
      'How embedded media consent works',
      'Recorded briefing',
      'Community campaign schedule.'
    )
    expect(result['cleaned']).not_to include(
      'External content requires consent',
      'Choose whether to load content'
    )
    expect(result['mutated']).to be(false)
  end

  it 'requires explicit placeholder markers and preserves marked media or substantive reporting' do
    result = cookie_ownership(<<~HTML)
      <main><h1>Media policy</h1><p>Current editorial standards.</p>
        <div class="embed-content-consent-placeholder" data-probe>Inactive embed one</div>
        <div class="third-party-embed-privacy-placeholder" data-probe>Inactive embed two</div>
        <div class="oembed-consent-placeholder" data-probe>Inactive embed three</div>
        <div data-testid="iframe-privacy-placeholder" data-probe>Inactive embed four</div>
        <div id="oembed-consent-placeholder" data-probe>Inactive embed five</div>
        <div class="external-content-consent-placeholder" data-probe>
          <h2>Consent design study</h2>
          <p>Researchers compare how newsrooms explain external media choices.</p>
          <p>The study records reader outcomes without loading any third-party script.</p>
          <ul><li>Transparency</li><li>Control</li></ul>
        </div>
        <iframe class="embed-consent-placeholder" src="https://video.example/frame" data-probe></iframe>
        <embed class="embedded-content-consent-placeholder" src="https://video.example/object" data-probe>
        <object class="external-content-privacy-placeholder" data="https://video.example/object" data-probe></object>
        <picture class="iframe-consent-placeholder" data-probe><img src="briefing.jpg" alt="Recorded briefing"></picture>
        <h2 class="external-content-consent-placeholder" data-probe>Embedded consent study</h2>
        <div class="external-content-consent-placeholder-analysis" data-probe>Independent consent analysis.</div>
        <div class="cmpplaceholder-report" data-probe>CMP implementation report.</div>
        <div class="external-content-consent-placeholder" data-probe>#{"Long policy analysis. " * 45}</div>
      </main>
    HTML

    expect(result['notices']).to eq(
      [
        true, true, true, true, true,
        false, false, false, false, false, false, false, false, false
      ]
    )
    expect(result['cleaned']).to include(
      'Media policy', 'Current editorial standards.', 'Consent design study', 'Transparency', 'Control',
      'Embedded consent study', 'Independent consent analysis.', 'CMP implementation report.', 'Long policy analysis.'
    )
    expect(result['cleaned']).not_to include('Inactive embed')
    expect(result.values_at('cookieCleanedMediaCount', 'cookieCleanedIframeSrc')).to eq(
      [4, 'https://video.example/frame']
    )
    expect(result['mutated']).to be(false)
  end
end
