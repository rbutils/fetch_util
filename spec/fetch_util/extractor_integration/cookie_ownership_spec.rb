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
          var notices = Array.from(document.querySelectorAll("[data-probe]"));
          return {
            body: cookieChromeNode(document.body),
            notices: notices.map(function(node) { return cookieChromeNode(node); }),
            cleaned: cleanClone(document.body).textContent
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
end
