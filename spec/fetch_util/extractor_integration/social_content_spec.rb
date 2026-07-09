# frozen_string_literal: true

RSpec.describe 'FetchUtil social result contract' do
  include_context 'extractor integration helpers'

  def synthetic_social_payload(page, javascript)
    extract_payload(page, reader_mode: false)
    page.evaluate("(function() { #{javascript}\nreturn window.FetchUtilExtract.extract({ reader_mode: false }); })()")
  end

  def expect_empty_social_fields(payload)
    expect(payload.values_at('socialKind', 'platform', 'handle', 'replyCount', 'community', 'score')).to all(be_nil)
  end

  it 'serializes normalized handler evidence without discovering social pages by host' do
    html = <<~HTML
      <html><head><title>Evidence-backed discussion</title></head><body><article><h1>Evidence-backed discussion</h1><p>Public discussion body.</p></article></body></html>
    HTML

    with_url_page('https://social-contract.test/discussion', html) do |page|
      payload = synthetic_social_payload(page, <<~JS)
        window.registerHostAwareProfile(/(^|\\.)social-contract\\.test$/, function() {
          return { title: 'Evidence-backed discussion', html: '<article><h1>Evidence-backed discussion</h1><p>Public discussion body.</p></article>', markdown: '# Evidence-backed discussion\\n\\nPublic discussion body.', textContent: 'Public discussion body.', readerMode: false, contentType: 'social', socialKind: 'thread', platform: '  Example Network  ', handle: '  @ada  ', replyCount: '0', community: '  r/ruby  ', score: '-2' };
        });
      JS

      expect(payload['contentType']).to eq('social')
      expect(payload).to include('socialKind' => 'thread', 'platform' => 'Example Network', 'handle' => '@ada', 'replyCount' => 0, 'community' => 'r/ruby', 'score' => -2)
    end
  end

  it 'rejects invalid handler social kinds' do
    html = <<~HTML
      <html><head><title>Invalid social result</title></head><body><article><h1>Invalid social result</h1><p>Public body.</p></article></body></html>
    HTML

    with_url_page('https://social-contract.test/invalid', html) do |page|
      payload = synthetic_social_payload(page, <<~JS)
        window.registerHostAwareProfile(/(^|\\.)social-contract\\.test$/, function() {
          return { title: 'Invalid social result', html: '<article><h1>Invalid social result</h1><p>Public body.</p></article>', markdown: '# Invalid social result\\n\\nPublic body.', textContent: 'Public body.', readerMode: false, contentType: 'social', socialKind: 'story', platform: 'Example Network', replyCount: 'many' };
        });
      JS

      expect(payload['contentType']).to eq('article')
      expect_empty_social_fields(payload)
    end
  end

  it 'does not classify generic article and list fixtures as social' do
    article_html = <<~HTML
      <html><head><title>Generic article</title></head><body><article><h1>Generic article</h1><p>This is ordinary editorial content with enough detail to remain an article rather than a host-provided social result.</p></article></body></html>
    HTML
    list_html = <<~HTML
      <html><head><title>Generic list</title></head><body><main><article><h2><a href='/one'>One item</a></h2></article><article><h2><a href='/two'>Two item</a></h2></article><article><h2><a href='/three'>Three item</a></h2></article><article><h2><a href='/four'>Four item</a></h2></article></main></body></html>
    HTML

    with_url_page('https://social-contract.test/article', article_html) do |page|
      payload = extract_payload(page, reader_mode: false)
      expect(payload['contentType']).to eq('article')
      expect_empty_social_fields(payload)
    end

    with_url_page('https://social-contract.test/category', list_html) do |page|
      payload = extract_payload(page, reader_mode: false)
      expect(payload['contentType']).to eq('list')
      expect_empty_social_fields(payload)
    end
  end

  it 'clears handler social fields when a login shell is finalized as an interstitial' do
    html = <<~HTML
      <html><head><title>Log in</title></head><body><main><h1>Log in</h1><p>Log in to view this discussion.</p><form><input type='email'><input type='password'></form></main></body></html>
    HTML

    with_url_page('https://social-contract.test/login', html) do |page|
      payload = synthetic_social_payload(page, <<~JS)
        window.registerHostAwareProfile(/(^|\\.)social-contract\\.test$/, function() {
          return { title: 'Log in', html: '<main><h1>Log in</h1><p>Log in to view this discussion.</p></main>', markdown: '# Log in\\n\\nLog in to view this discussion.', textContent: 'Log in to view this discussion.', readerMode: false, contentType: 'interstitial', socialKind: 'thread', platform: 'Example Network', handle: '@ada', replyCount: 3, community: 'r/ruby', score: 9 };
        });
      JS

      expect(payload['contentType']).to eq('interstitial')
      expect_empty_social_fields(payload)
    end
  end

  it 'keeps handler evidence when removable consent chrome accompanies public content' do
    body = ('Public discussion body with enough context to establish visible content. ' * 12).strip
    html = <<~HTML
      <html><head><title>Public discussion</title></head><body><div class='cookie-banner'><p>We use cookies.</p><button>Accept all</button></div><article><h1>Public discussion</h1><p>#{body}</p></article></body></html>
    HTML

    with_url_page('https://social-contract.test/public', html) do |page|
      payload = synthetic_social_payload(page, <<~JS)
        window.registerHostAwareProfile(/(^|\\.)social-contract\\.test$/, function() {
          return { title: 'Public discussion', html: document.querySelector('article').outerHTML, markdown: '# Public discussion\\n\\n' + document.querySelector('article p').textContent, textContent: document.querySelector('article').textContent, readerMode: false, contentType: 'social', socialKind: 'post', platform: 'Example Network' };
        });
      JS

      expect(payload).to include('contentType' => 'social', 'socialKind' => 'post', 'platform' => 'Example Network')
      expect(payload['warnings']).not_to include('consent_interstitial')
    end
  end

  it 'types a visible public Facebook profile' do
    html = <<~HTML
      <html><head><title>Example Page | Facebook</title></head><body><main role="main"><div>Page · Community</div><div>12K followers</div><div>Intro</div><p>Public updates for the local community, events, workshops, volunteer opportunities, neighborhood news, and resources for residents and visitors.</p><p>Our organizers share schedules, speaker announcements, accessibility details, and practical guides for every event.</p><p>Members can read public recaps, connect with local volunteers, and find links to upcoming workshops.</p></main></body></html>
    HTML

    with_url_page('https://www.facebook.com/example-page/', html) do |page|
      payload = extract_payload(page)

      expect(payload).to include('contentType' => 'social', 'socialKind' => 'profile', 'platform' => 'Facebook', 'handle' => '@example-page')
    end
  end

  it 'keeps a Facebook login shell as an interstitial' do
    html = <<~HTML
      <html><head><title>Facebook - Log In</title><meta name="description" content="Log in to Facebook"></head><body><main><h1>Log in to Facebook</h1><p>Create new account</p></main></body></html>
    HTML

    with_url_page('https://www.facebook.com/example-page/', html) do |page|
      payload = extract_payload(page)

      expect_content_type(payload, 'interstitial')
      expect_empty_social_fields(payload)
      expect_warnings(payload, include: 'meta_login_wall')
    end
  end

  it 'types a visible public Instagram post' do
    html = <<~HTML
      <html><head><title>Ronaldo on Instagram: &quot;Training day&quot;</title><meta property="og:description" content="10 likes - ronaldo on April 1, 2026: &quot;Training day&quot;."></head><body><main><article><img src="https://example.test/post.jpg" alt="Training"><p>Training day</p></article></main></body></html>
    HTML

    with_url_page('https://www.instagram.com/ronaldo/p/example/', html) do |page|
      payload = extract_payload(page)

      expect(payload).to include('contentType' => 'social', 'socialKind' => 'post', 'platform' => 'Instagram', 'handle' => '@ronaldo')
    end
  end

  it 'types a visible public Threads profile' do
    html = <<~HTML
      <html><head><title>Ada Lovelace (@ada) • Threads</title><meta name="description" content="2K Followers • 18 Threads • Computing notes."></head><body><main><h1>Ada Lovelace</h1><p>@ada</p><p>2K Followers</p><p>Computing notes.</p></main></body></html>
    HTML

    with_url_page('https://www.threads.net/@ada', html) do |page|
      payload = extract_payload(page)

      expect(payload).to include('contentType' => 'social', 'socialKind' => 'profile', 'platform' => 'Threads', 'handle' => '@ada')
    end
  end

  it 'keeps a Threads login shell as an interstitial' do
    html = <<~HTML
      <html><head><title>Threads • Log in</title><meta name="description" content="Join Threads to share ideas. Log in with your Instagram."></head><body><main><h1>Log in with your Instagram</h1></main></body></html>
    HTML

    with_url_page('https://www.threads.net/@ada', html) do |page|
      payload = extract_payload(page)

      expect_content_type(payload, 'interstitial')
      expect_empty_social_fields(payload)
      expect_warnings(payload, include: 'meta_login_wall')
    end
  end
end
