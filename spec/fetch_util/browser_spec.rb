# frozen_string_literal: true

RSpec.describe FetchUtil::Browser do
  it 'raises when no browser executable is available' do
    browser = described_class.new(browser_path: nil)
    browser.instance_variable_set(:@browser_path, nil)

    expect { browser.with_page('https://example.com') {} }.to raise_error(FetchUtil::BrowserError)
  end

  it 'accepts visible cookie prompts by default before yielding' do
    network = instance_double('FerrumNetwork')
    ferrum = instance_double(Ferrum::Browser)
    page = instance_double('FerrumPage')

    allow(Ferrum::Browser).to receive(:new).and_return(ferrum)
    allow(ferrum).to receive(:evaluate_on_new_document)
    allow(ferrum).to receive(:create_page).and_return(page)
    allow(page).to receive(:headers).and_return(double(set: true))
    allow(page).to receive(:bypass_csp)
    allow(page).to receive(:go_to)
    allow(page).to receive(:network).and_return(network)
    allow(network).to receive(:idle?).and_return(true)
    allow(network).to receive(:wait_for_idle)
    allow(page).to receive(:evaluate).and_return(true)
    allow(page).to receive(:close)

    browser = described_class.new(browser_path: '/usr/bin/chromium', wait: 0, wait_for_idle: true)
    yielded = nil

    browser.with_page('https://example.com') { |result| yielded = result }

    expect(yielded).to eq(page)
    expect(page).to have_received(:evaluate).with(include('consentContext')).at_least(:once)
    expect(network).to have_received(:wait_for_idle).once
  end

  it 'does not perform a second idle wait when no cookie prompt was accepted' do
    network = instance_double('FerrumNetwork')
    ferrum = instance_double(Ferrum::Browser)
    page = instance_double('FerrumPage')

    allow(Ferrum::Browser).to receive(:new).and_return(ferrum)
    allow(ferrum).to receive(:evaluate_on_new_document)
    allow(ferrum).to receive(:create_page).and_return(page)
    allow(page).to receive(:headers).and_return(double(set: true))
    allow(page).to receive(:bypass_csp)
    allow(page).to receive(:go_to)
    allow(page).to receive(:network).and_return(network)
    allow(network).to receive(:idle?).and_return(true)
    allow(network).to receive(:wait_for_idle)
    allow(page).to receive(:evaluate).and_return(false)
    allow(page).to receive(:close)

    browser = described_class.new(browser_path: '/usr/bin/chromium', wait: 0, wait_for_idle: true)
    browser.with_page('https://example.com') {}

    expect(network).not_to have_received(:wait_for_idle)
  end

  it 'retries cookie acceptance after spa hydration on generic pages' do
    network = instance_double('FerrumNetwork')
    page = instance_double(Ferrum::Browser, network: network)
    browser = described_class.new(browser_path: '/usr/bin/chromium', wait: 0, wait_for_idle: true)

    allow(browser).to receive(:wait_for_idle_or_content).and_return(true)
    allow(browser).to receive(:preserve_consent_wall?).and_return(false)
    allow(browser).to receive(:accept_cookie_consent).and_return(false, false, true)
    allow(browser).to receive(:dismiss_privacy_preference_overlay).and_return(false)
    allow(browser).to receive(:wait_for_spa_hydration)
    allow(network).to receive(:wait_for_idle)

    browser.send(:stabilize_page, page, 'https://example.com')

    expect(browser).to have_received(:accept_cookie_consent).exactly(3).times
    expect(browser).to have_received(:wait_for_spa_hydration).once
    expect(network).to have_received(:wait_for_idle).once
  end

  it 'does not count hidden consent templates as handled overlays' do
    page = instance_double(Ferrum::Browser)
    allow(page).to receive(:evaluate).and_return(false)

    browser = described_class.new(browser_path: '/usr/bin/chromium', wait: 0)
    expect(browser.send(:accept_cookie_consent, page)).to eq(false)

    expect(page).to have_received(:evaluate) do |script|
      # Phase 1: dialog/modal elements check visibility
      expect(script).to include('if (!visible(el)) continue;')
      # No aria-hidden or display-none shortcuts that could miscount
      expect(script).not_to include("style.display === 'none'")
      expect(script).not_to include("style.visibility === 'hidden'")
      expect(script).not_to include("el.getAttribute('aria-hidden') === 'true'")
    end
  end

  it 'searches open shadow roots when accepting generic cookie prompts' do
    page = instance_double(Ferrum::Browser)
    allow(page).to receive(:evaluate).and_return(false)

    browser = described_class.new(browser_path: '/usr/bin/chromium', wait: 0)
    expect(browser.send(:accept_cookie_consent, page)).to eq(false)

    expect(page).to have_received(:evaluate) do |script|
      expect(script).to include('el.shadowRoot')
      expect(script).to include('parentOrHost')
      expect(script).to include('akkoord')
    end
  end

  it 'includes Amharic accept and privacy cues in the generic consent helper' do
    page = instance_double(Ferrum::Browser)
    allow(page).to receive(:evaluate).and_return(false)

    browser = described_class.new(browser_path: '/usr/bin/chromium', wait: 0)
    expect(browser.send(:accept_cookie_consent, page)).to eq(false)

    expect(page).to have_received(:evaluate) do |script|
      expect(script).to include('ተቀበል')
      expect(script).to include('ግላዊነት')
    end
  end

  it 'includes Czech consent cues in the generic consent helper' do
    page = instance_double(Ferrum::Browser)
    allow(page).to receive(:evaluate).and_return(false)

    browser = described_class.new(browser_path: '/usr/bin/chromium', wait: 0)
    expect(browser.send(:accept_cookie_consent, page)).to eq(false)

    expect(page).to have_received(:evaluate) do |script|
      expect(script).to include('pro pokračování vyberte')
      expect(script).to include('technické cookies')
      expect(script).to include('pokračovat')
    end
  end

  it 'includes generic privacy-center and cookie-information cues in the consent helper' do
    page = instance_double(Ferrum::Browser)
    allow(page).to receive(:evaluate).and_return(false)

    browser = described_class.new(browser_path: '/usr/bin/chromium', wait: 0)
    expect(browser.send(:accept_cookie_consent, page)).to eq(false)

    expect(page).to have_received(:evaluate) do |script|
      expect(script).to include('privacy preference center')
      expect(script).to include('cookie information')
      expect(script).to include('confirm my choices')
    end
  end

  it 'includes Portuguese consent cues and a body-led fallback in the generic consent helper' do
    page = instance_double(Ferrum::Browser)
    allow(page).to receive(:evaluate).and_return(false)

    browser = described_class.new(browser_path: '/usr/bin/chromium', wait: 0)
    expect(browser.send(:accept_cookie_consent, page)).to eq(false)

    expect(page).to have_received(:evaluate) do |script|
      expect(script).to include('bodyLooksLikeConsent')
      expect(script).to include('configurações avançadas de cookies')
      expect(script).to include('gerenciar cookies')
      expect(script).to include('aceitar cookies')
    end
  end

  it 'tries common privacy-preference action labels when a privacy overlay is present' do
    page = instance_double(Ferrum::Browser)
    browser = described_class.new(browser_path: '/usr/bin/chromium', wait: 0)

    allow(browser).to receive(:safe_evaluate).and_return(true)
    allow(browser).to receive(:click_visible_button_by_text).and_return(true)

    expect(browser.send(:dismiss_privacy_preference_overlay, page)).to eq(true)
    expect(browser).to have_received(:click_visible_button_by_text).with(
      page,
      include('Accept All', 'Allow all', 'Confirm My Choices', 'Save preferences', 'Customize Choices'),
      include('Essential only', 'Reject All'),
      selectors: 'button, [role="button"], a, input[type="button"], input[type="submit"]'
    )
  end

  it 'patches empty userAgentData values to a consistent browser profile' do
    browser = described_class.new(browser_path: '/usr/bin/chromium', wait: 0)
    script = browser.send(:navigator_patch)

    expect(script).to include('uaData.brands.length === 0')
    expect(script).to include('missingUserAgentData')
    expect(script).to include('platform: "Linux"')
    expect(script).to include('Google Chrome')
  end

  it 'preserves google consent prompts instead of auto-accepting them' do
    network = instance_double('FerrumNetwork')
    ferrum = instance_double(Ferrum::Browser)
    page = instance_double('FerrumPage')

    allow(Ferrum::Browser).to receive(:new).and_return(ferrum)
    allow(ferrum).to receive(:evaluate_on_new_document)
    allow(ferrum).to receive(:create_page).and_return(page)
    allow(page).to receive(:headers).and_return(double(set: true))
    allow(page).to receive(:bypass_csp)
    allow(page).to receive(:go_to)
    allow(page).to receive(:network).and_return(network)
    allow(network).to receive(:idle?).and_return(true)
    allow(network).to receive(:wait_for_idle)
    allow(page).to receive(:close)
    allow(page).to receive(:evaluate) do |script|
      if script.include?('title: document.title')
        { 'title' => 'Before you continue to Google', 'text' => 'We use cookies and data. Accept all. Reject all.' }
      elsif script.include?('__NEXT_DATA__') || script.include?('__reactFiber')
        # SPA framework detection / hydration check — return nil (no SPA detected)
        nil
      else
        raise 'unexpected cookie click evaluation'
      end
    end

    browser = described_class.new(browser_path: '/usr/bin/chromium', wait: 0, wait_for_idle: true)
    browser.with_page('https://www.google.com/webhp?hl=en') {}

    expect(network).not_to have_received(:wait_for_idle)
  end

  it 'falls back cleanly when consent evaluation times out on a heavy page' do
    network = instance_double('FerrumNetwork')
    ferrum = instance_double(Ferrum::Browser)
    page = instance_double('FerrumPage')

    allow(Ferrum::Browser).to receive(:new).and_return(ferrum)
    allow(ferrum).to receive(:evaluate_on_new_document)
    allow(ferrum).to receive(:create_page).and_return(page)
    allow(page).to receive(:headers).and_return(double(set: true))
    allow(page).to receive(:bypass_csp)
    allow(page).to receive(:go_to)
    allow(page).to receive(:network).and_return(network)
    allow(network).to receive(:idle?).and_return(true)
    allow(network).to receive(:wait_for_idle)
    allow(page).to receive(:evaluate).and_raise(Ferrum::TimeoutError)
    allow(page).to receive(:close)

    browser = described_class.new(browser_path: '/usr/bin/chromium', wait: 0, wait_for_idle: true)
    browser.with_page('https://example.com') {}

    expect(network).not_to have_received(:wait_for_idle)
  end

  it 'retries navigation on PendingConnectionsError before raising' do
    network = instance_double('FerrumNetwork')
    ferrum = instance_double(Ferrum::Browser)
    page = instance_double('FerrumPage')

    allow(Ferrum::Browser).to receive(:new).and_return(ferrum)
    allow(ferrum).to receive(:evaluate_on_new_document)
    allow(ferrum).to receive(:create_page).and_return(page)
    allow(page).to receive(:headers).and_return(double(set: true))
    allow(page).to receive(:bypass_csp)
    call_count = 0
    allow(page).to receive(:go_to) do
      call_count += 1
      raise Ferrum::PendingConnectionsError, nil if call_count < 3
    end
    allow(page).to receive(:network).and_return(network)
    allow(network).to receive(:idle?).and_return(true)
    allow(network).to receive(:wait_for_idle)
    # page_loaded_enough? returns false on retries, then consent/stabilize evaluate calls return false
    allow(page).to receive(:evaluate).and_return(false)
    allow(page).to receive(:close)

    browser = described_class.new(browser_path: '/usr/bin/chromium', wait: 0, wait_for_idle: true)
    yielded = nil

    browser.with_page('https://example.com') { |result| yielded = result }

    expect(yielded).to eq(page)
    expect(call_count).to eq(3)
  end

  it 'raises after exhausting navigation retries' do
    ferrum = instance_double(Ferrum::Browser)
    page = instance_double('FerrumPage')

    allow(Ferrum::Browser).to receive(:new).and_return(ferrum)
    allow(ferrum).to receive(:evaluate_on_new_document)
    allow(ferrum).to receive(:create_page).and_return(page)
    allow(page).to receive(:headers).and_return(double(set: true))
    allow(page).to receive(:bypass_csp)
    allow(page).to receive(:go_to).and_raise(Ferrum::PendingConnectionsError.new(nil))
    # page_loaded_enough? always returns false
    allow(page).to receive(:evaluate).and_return(false)
    allow(page).to receive(:close)

    browser = described_class.new(browser_path: '/usr/bin/chromium', wait: 0, wait_for_idle: true)

    expect { browser.with_page('https://example.com') {} }.to raise_error(FetchUtil::BrowserError)
    expect(page).to have_received(:go_to).exactly(3).times
  end

  it 'continues after initial navigation timeout when page content already exists' do
    network = instance_double('FerrumNetwork')
    ferrum = instance_double(Ferrum::Browser)
    page = instance_double('FerrumPage')

    allow(Ferrum::Browser).to receive(:new).and_return(ferrum)
    allow(ferrum).to receive(:evaluate_on_new_document)
    allow(ferrum).to receive(:create_page).and_return(page)
    allow(page).to receive(:headers).and_return(double(set: true))
    allow(page).to receive(:bypass_csp)
    allow(page).to receive(:go_to).and_raise(Ferrum::TimeoutError)
    allow(page).to receive(:network).and_return(network)
    allow(network).to receive(:idle?).and_return(true)
    allow(network).to receive(:wait_for_idle)
    allow(page).to receive(:evaluate).and_return(true, false, false)
    allow(page).to receive(:close)

    browser = described_class.new(browser_path: '/usr/bin/chromium', wait: 0, wait_for_idle: true)
    yielded = nil

    browser.with_page('https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.31/#pod-v1-core') { |result| yielded = result }

    expect(yielded).to eq(page)
  end

  it 'treats stable page content as ready before network idle' do
    network = instance_double('FerrumNetwork', idle?: false)
    page = instance_double(Ferrum::Browser, network: network)
    browser = described_class.new(browser_path: '/usr/bin/chromium', wait: 0, wait_for_idle: true, idle_duration: 0)

    allow(page).to receive(:evaluate).and_return(true)

    expect(browser.send(:wait_for_idle_or_content, page)).to eq(true)
  end

  it 'uses fast reddit stabilization instead of idle waits and cookie clicks' do
    network = instance_double('FerrumNetwork')
    ferrum = instance_double(Ferrum::Browser)
    page = instance_double('FerrumPage')

    allow(Ferrum::Browser).to receive(:new).and_return(ferrum)
    allow(ferrum).to receive(:evaluate_on_new_document)
    allow(ferrum).to receive(:create_page).and_return(page)
    allow(page).to receive(:headers).and_return(double(set: true))
    allow(page).to receive(:bypass_csp)
    allow(page).to receive(:go_to)
    allow(page).to receive(:network).and_return(network)
    allow(network).to receive(:wait_for_idle)
    allow(page).to receive(:at_xpath).and_return(nil)
    allow(page).to receive(:evaluate).and_return(true)
    allow(page).to receive(:close)

    browser = described_class.new(browser_path: '/usr/bin/chromium', wait: 0, wait_for_idle: true)
    browser.with_page('https://www.reddit.com/r/ruby/comments/1') {}

    expect(network).not_to have_received(:wait_for_idle)
    expect(page).to have_received(:evaluate).at_least(:twice)
  end

  it 'uses ebay search stabilization instead of generic idle waits' do
    network = instance_double('FerrumNetwork')
    ferrum = instance_double(Ferrum::Browser)
    page = instance_double('FerrumPage')

    allow(Ferrum::Browser).to receive(:new).and_return(ferrum)
    allow(ferrum).to receive(:evaluate_on_new_document)
    allow(ferrum).to receive(:create_page).and_return(page)
    allow(page).to receive(:headers).and_return(double(set: true))
    allow(page).to receive(:bypass_csp)
    allow(page).to receive(:go_to)
    allow(page).to receive(:network).and_return(network)
    allow(network).to receive(:wait_for_idle)
    allow(page).to receive(:evaluate).and_return({ 'clicked' => false, 'itemCount' => 4, 'challengeVisible' => false })
    allow(page).to receive(:close)

    browser = described_class.new(browser_path: '/usr/bin/chromium', wait: 0, wait_for_idle: true)
    browser.with_page('https://www.ebay.com/sch/i.html?_nkw=ruby+programming') {}

    expect(network).not_to have_received(:wait_for_idle)
    expect(page).to have_received(:evaluate).at_least(:once)
  end

  it 'configures reddit cookie dismissal through the shared overlay helper' do
    page = instance_double(Ferrum::Browser)
    allow(page).to receive(:evaluate).and_return(true)

    browser = described_class.new(browser_path: '/usr/bin/chromium', wait: 0)
    expect(browser.send(:dismiss_reddit_cookie_dialog, page)).to eq(true)

    expect(page).to have_received(:evaluate).with(include('before you continue to reddit'))
    expect(page).to have_received(:evaluate).with(include('shreddit-experience-tree'))
  end

  it 'reuses the shared text-button helper for ebay cookie acceptance' do
    page = instance_double(Ferrum::Browser)
    allow(page).to receive(:evaluate) do |script|
      if script.include?('labelGroups')
        false
      else
        { 'itemCount' => 4, 'challengeVisible' => false }
      end
    end

    browser = described_class.new(browser_path: '/usr/bin/chromium', wait: 0)
    browser.send(:stabilize_ebay_search, page)

    expect(page).to have_received(:evaluate).with(include('accept all cookies'))
    expect(page).to have_received(:evaluate).with(include('input[type='))
  end

  it 'configures facebook cookie dismissal through the shared text-button helper' do
    page = instance_double(Ferrum::Browser)
    allow(page).to receive(:evaluate).and_return(true)

    browser = described_class.new(browser_path: '/usr/bin/chromium', wait: 0)
    expect(browser.send(:dismiss_facebook_cookie_dialog, page)).to eq(true)

    expect(page).to have_received(:evaluate) do |script|
      expect(script).to include('decline optional cookies')
      expect(script).to include('allow all cookies')
    end
  end

  it 'configures instagram login dismissal through the shared overlay helper' do
    page = instance_double(Ferrum::Browser)
    allow(page).to receive(:evaluate).and_return(true)

    browser = described_class.new(browser_path: '/usr/bin/chromium', wait: 0)
    expect(browser.send(:dismiss_instagram_login_modal, page)).to eq(true)

    expect(page).to have_received(:evaluate) do |script|
      expect(script).to include('allowEmptyCloseLabel')
      expect(script).to include('don.?t have an account')
      expect(script).to include('^(?:close|dismiss|x|×)?$')
      expect(script).to include('position: fixed')
      expect(script).to include('withinMatchingNode')
    end
  end

  it 'configures instagram cookie acceptance through the shared text-button helper' do
    page = instance_double(Ferrum::Browser)
    allow(page).to receive(:evaluate).and_return(true)

    browser = described_class.new(browser_path: '/usr/bin/chromium', wait: 0)
    expect(browser.send(:accept_instagram_cookie_dialog, page)).to eq(true)

    expect(page).to have_received(:evaluate) do |script|
      expect(script).to include('accept all cookies')
      expect(script).to include('allow all cookies')
    end
  end

  it 'uses a fixed post-overlay pause when wait is zero' do
    browser = described_class.new(browser_path: '/usr/bin/chromium', wait: 0)
    allow(browser).to receive(:sleep)

    browser.send(:social_login_phase_pause)

    expect(browser).to have_received(:sleep).with(0.3)
  end

  it 'reuses the shared settling helper for post-overlay pauses when wait is positive' do
    browser = described_class.new(browser_path: '/usr/bin/chromium', wait: 0.75)
    allow(browser).to receive(:settle_after_stabilization)

    browser.send(:social_login_phase_pause)

    expect(browser).to have_received(:settle_after_stabilization).with(0.3)
  end

  it 'uses the shared post-overlay pause sequence for instagram stabilization' do
    page = instance_double(Ferrum::Browser)
    browser = described_class.new(browser_path: '/usr/bin/chromium', wait: 0, wait_for_idle: true)

    expect(browser).to receive(:wait_for_idle_or_content).with(page).ordered
    expect(browser).to receive(:accept_instagram_cookie_dialog).with(page).ordered.and_return(true)
    expect(browser).to receive(:social_login_phase_pause).ordered
    expect(browser).to receive(:accept_instagram_cookie_dialog).with(page).ordered.and_return(true)
    expect(browser).to receive(:retry_until_timeout).with(5.0).ordered.and_yield
    expect(browser).to receive(:dismiss_instagram_login_modal).with(page).ordered.and_return(true)
    expect(browser).to receive(:social_login_phase_pause).ordered
    expect(browser).to receive(:dismiss_instagram_login_modal).with(page).ordered.and_return(true)

    browser.send(:stabilize_instagram, page)
  end

  it 'uses the shared post-overlay pause sequence for facebook stabilization' do
    page = instance_double(Ferrum::Browser)
    browser = described_class.new(browser_path: '/usr/bin/chromium', wait: 0, wait_for_idle: true)

    expect(browser).to receive(:wait_for_idle_or_content).with(page).ordered
    expect(browser).to receive(:social_login_phase_pause).ordered
    expect(browser).to receive(:dismiss_facebook_cookie_dialog).with(page).ordered
    expect(browser).to receive(:social_login_phase_pause).ordered
    expect(browser).to receive(:retry_until_timeout).with(5.0).ordered.and_yield
    expect(browser).to receive(:dismiss_facebook_login_dialog).with(page).ordered.and_return(true)
    expect(browser).to receive(:social_login_phase_pause).ordered

    browser.send(:stabilize_facebook, page)
  end

  it 'reuses the browser process across multiple with_page calls' do
    ferrum = instance_double(Ferrum::Browser)
    page1 = instance_double('FerrumPage1')
    page2 = instance_double('FerrumPage2')

    allow(Ferrum::Browser).to receive(:new).and_return(ferrum)
    allow(ferrum).to receive(:evaluate_on_new_document)
    allow(ferrum).to receive(:create_page).and_return(page1, page2)

    [page1, page2].each do |page|
      allow(page).to receive(:headers).and_return(double(set: true))
      allow(page).to receive(:bypass_csp)
      allow(page).to receive(:go_to)
      allow(page).to receive(:network).and_return(instance_double('FerrumNetwork', idle?: true))
      allow(page).to receive(:evaluate).and_return(false)
      allow(page).to receive(:close)
    end

    browser = described_class.new(browser_path: '/usr/bin/chromium', wait: 0, wait_for_idle: true)

    results = []
    browser.with_page('https://example.com') { |p| results << p }
    browser.with_page('https://example.org') { |p| results << p }

    expect(results).to eq([page1, page2])
    expect(Ferrum::Browser).to have_received(:new).once
    expect(ferrum).to have_received(:create_page).twice
    expect(page1).to have_received(:close).once
    expect(page2).to have_received(:close).once
  end

  it 'shuts down the browser process on quit' do
    ferrum = instance_double(Ferrum::Browser)
    page = instance_double('FerrumPage')

    allow(Ferrum::Browser).to receive(:new).and_return(ferrum)
    allow(ferrum).to receive(:evaluate_on_new_document)
    allow(ferrum).to receive(:create_page).and_return(page)
    allow(ferrum).to receive(:quit)
    allow(page).to receive(:headers).and_return(double(set: true))
    allow(page).to receive(:bypass_csp)
    allow(page).to receive(:go_to)
    allow(page).to receive(:network).and_return(instance_double('FerrumNetwork', idle?: true))
    allow(page).to receive(:evaluate).and_return(false)
    allow(page).to receive(:close)

    browser = described_class.new(browser_path: '/usr/bin/chromium', wait: 0, wait_for_idle: true)
    browser.with_page('https://example.com') {}
    browser.quit

    expect(ferrum).to have_received(:quit).once
  end

  it 'is safe to call quit without any prior with_page calls' do
    browser = described_class.new(browser_path: '/usr/bin/chromium', wait: 0)
    expect { browser.quit }.not_to raise_error
  end
end
