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

  it 'keeps combined Facebook login and consent wall warnings as an interstitial' do
    html = <<~HTML
      <html><head><title>Meta | Facebook</title></head><body><main><h1>Allow the use of cookies from Facebook on this browser?</h1><p>We use cookies and similar technologies to help provide and improve content on Meta Products.</p><p>Log in to continue.</p></main></body></html>
    HTML

    with_url_page('https://www.facebook.com/Meta', html) do |page|
      payload = synthetic_social_payload(page, <<~JS)
        window.registerHostAwareProfile(/(^|\\.)facebook\\.com$/, function() {
          return { title: 'Meta', html: '<article><p>Fallback summary.</p></article>', markdown: '# Meta\\n\\nFallback summary.', textContent: 'Fallback summary.', readerMode: false, contentType: 'article' };
        });
      JS

      expect(payload['contentType']).to eq('interstitial')
      expect(payload['suspect']).to be(true)
      expect_warnings(payload, include: %w[meta_login_wall consent_interstitial])
      expect_empty_social_fields(payload)
    end
  end

  it 'keeps a readable public Facebook profile despite inline consent copy' do
    html = <<~HTML
      <html><head><title>Example Page | Facebook</title></head><body><aside><p>Allow the use of cookies from Facebook on this browser?</p><p>We use cookies and similar technologies to help provide and improve content on Meta Products.</p><button>Accept all cookies</button></aside><main role="main"><div>Page · Community</div><div>12K followers</div><div>Intro</div><p>Public updates for the local community, events, workshops, volunteer opportunities, neighborhood news, and resources for residents and visitors.</p><p>Our organizers share schedules, speaker announcements, accessibility details, and practical guides for every event.</p><p>Members can read public recaps, connect with local volunteers, and find links to upcoming workshops.</p></main></body></html>
    HTML

    with_url_page('https://www.facebook.com/example-page/', html) do |page|
      payload = extract_payload(page)

      expect(payload).to include('contentType' => 'social', 'socialKind' => 'profile', 'platform' => 'Facebook', 'handle' => '@example-page')
      expect(payload['markdown']).not_to include('Allow the use of cookies')
    end
  end

  it 'types a visible public Instagram post' do
    html = <<~HTML
      <html><head><title>Ronaldo on Instagram: &quot;Training day&quot;</title><meta property="og:description" content="10 likes - ronaldo on April 1, 2026: &quot;Training day&quot;."><meta property="og:image" content="javascript:unsafeImage()"><meta property="og:video" content="ftp://files.example.test/video.mp4"></head><body><main><article><img src="https://example.test/post.jpg" alt="Training"><p>Training day</p></article></main></body></html>
    HTML

    with_url_page('https://www.instagram.com/ronaldo/p/example/', html) do |page|
      payload = extract_payload(page)

      expect(payload).to include('contentType' => 'social', 'socialKind' => 'post', 'platform' => 'Instagram', 'handle' => '@ronaldo')
      expect(payload['markdown']).not_to include('javascript:', 'ftp:')
    end
  end

  it 'falls back to a safe Open Graph video after unsafe media values' do
    html = '<html><head><title>Metadata media</title><meta property="og:image" content="javascript:unsafeImage()"><meta property="og:image" content="/safe-image.png"><meta property="og:video" content="ftp://files.example.test/video.mp4"><meta property="og:video" content="/safe-video.mp4"><meta property="og:video:url" content="/alias-video.mp4"></head><body><main>Visible profile content</main></body></html>'

    with_url_page('https://social-contract.test/metadata-media', html) do |page|
      payload = synthetic_social_payload(page, <<~JS)
        window.registerHostAwareProfile(/social-contract\\.test$/, function(metadata) {
          var media = [metadata.image && 'Image: ' + metadata.image, metadata.video && 'Video: ' + metadata.video].filter(Boolean);
          return {
            title: 'Metadata media',
            html: '<article><p>Visible profile content.</p></article>',
            markdown: '# Metadata media\\n\\n' + media.join('\\n'),
            textContent: media.join(' '),
            readerMode: false,
            contentType: 'social',
            socialKind: 'profile',
            platform: 'Example Network'
          };
        });
      JS

      expect(payload['markdown']).to include(
        'Image: https://social-contract.test/safe-image.png',
        'Video: https://social-contract.test/safe-video.mp4'
      )
      expect(payload['markdown']).not_to include('alias-video', 'javascript:', 'ftp:')
    end
  end

  it 'sanitizes nested URL-bearing HTML contexts from profile output' do
    html = '<html><head><title>Nested output</title></head><body><main>Visible profile content</main></body></html>'

    with_url_page('https://social-contract.test/nested-output', html) do |page|
      payload = synthetic_social_payload(page, <<~JS)
        window.registerHostAwareProfile(/social-contract\\.test$/, function() {
          return {
            title: 'Nested output',
            html: '<style>.unsafe { background: url(javascript:unsafeStyle()) }</style><meta property="og:image" content="javascript:unsafeBodyMetadata()"><meta http-equiv="refresh" content="0;url=javascript:unsafeRefresh()"><iframe srcdoc="<a href=&quot;javascript:unsafeNested()&quot;>Nested action</a><img src=&quot;/safe-nested.png&quot;>"></iframe><template><a href="javascript:unsafeTemplate()">Template action</a><img src="/safe-template.png"><template><a href="mailto:deep@example.test">Deep template action</a><img src="/safe-deep-template.png"><style>.deep { background: url(javascript:deepStyle()) }</style><meta http-equiv="refresh" content="0;url=javascript:deepRefresh()"></template></template><img srcset="/nested-zoom.png 1e2x, /nested-zero.png 0x"><form action="/submit"><button formaction="javascript:unsafeForm()">Submit</button></form><blockquote cite="/source">Source</blockquote><table background="javascript:unsafeBackground()"><tr><td>Cell</td></tr></table><img longdesc="/long-description" usemap="#map"><div profile="/profile" manifest="/manifest" codebase="/codebase" classid="javascript:unsafeClass()" itemid="/item">Rare attributes</div>',
            markdown: '# Nested output\\n\\nVisible profile content.',
            textContent: 'Visible profile content.',
            readerMode: false,
            contentType: 'social',
            socialKind: 'profile',
            platform: 'Example Network'
          };
        });
      JS

      expect(payload['html']).to include(
        'Nested action',
        'Template action',
        'Deep template action',
        'https://social-contract.test/safe-nested.png',
        'https://social-contract.test/safe-template.png',
        'https://social-contract.test/safe-deep-template.png',
        'srcset="https://social-contract.test/nested-zoom.png 1e2x"',
        'action="https://social-contract.test/submit"',
        'cite="https://social-contract.test/source"',
        'longdesc="https://social-contract.test/long-description"',
        'usemap="https://social-contract.test/nested-output#map"',
        'profile="https://social-contract.test/profile"',
        'manifest="https://social-contract.test/manifest"',
        'codebase="https://social-contract.test/codebase"',
        'itemid="https://social-contract.test/item"'
      )
      expect(payload['html']).not_to include(
        'javascript:', 'mailto:', 'nested-zero', '<style', '<meta', 'formaction=', 'background=', 'classid='
      )
    end
  end

  it 'materializes active Markdown destinations while preserving literal code syntax' do
    markdown = <<~'MARKDOWN'.chomp
      # Markdown boundary

      [Safe guide](/guides/final_(copy) "Guide title")
      [Safe titled guide](/guides/titled "Title ) survives")
      [Unsafe action](javascript:inline())
      [Unsafe titled action](javascript:titled() "Title ) still unsafe")
      [Multiline unsafe
      action](javascript:multiline())
      <https://docs.example.test/path_(copy)>
      <javascript:auto()>
      <a href="/raw_(copy)">Raw safe</a>
      <a href="javascript:raw()">Raw action</a>
      <a
       href="javascript:rawMultiline()">Raw multiline action</a>

      [unsafe-reference]:
        javascript:reference()
      [Unsafe reference][unsafe-reference]

      [unsafe\]]: javascript:escapedReference()
      [Escaped reference][unsafe\]]
      > [quoted-reference]: javascript:quotedReference()
      > [Quoted reference][quoted-reference]

      \[Escaped literal](javascript:escaped())

          [Indented literal](javascript:indented())

      `[Inline literal](javascript:inlineCode())`

      `multiline
      [Multiline literal](javascript:multiCode())
      span`

      ```text
      [Fenced literal](javascript:fenced())
      ```

      > ```text
      > [Quoted fenced literal](javascript:quotedFenced())
      > ```

      ``` invalid`
      [Unsafe after invalid fence](javascript:invalidFence())

      Trailing `unclosed
      [Unsafe after unmatched span](javascript:unmatchedSpan())
    MARKDOWN
    markdown = markdown.gsub("\n", "\r\n")
    html = '<html><head><title>Markdown boundary</title></head><body><main>Visible profile content</main></body></html>'

    with_url_page('https://social-contract.test/markdown-boundary', html) do |page|
      payload = synthetic_social_payload(page, <<~JS)
        window.registerHostAwareProfile(/social-contract\\.test$/, function() {
          return {
            title: 'Markdown boundary',
            html: '<article><p>Visible profile content.</p></article>',
            markdown: #{JSON.generate(markdown)},
            textContent: 'Visible profile content.',
            readerMode: false,
            contentType: 'social',
            socialKind: 'profile',
            platform: 'Example Network'
          };
        });
      JS

      materialized = payload['markdown']
      expect(materialized).to include(
        '[Safe guide](https://social-contract.test/guides/final_%28copy%29 "Guide title")',
        '[Safe titled guide](https://social-contract.test/guides/titled "Title ) survives")',
        '<https://docs.example.test/path_%28copy%29>',
        '<a href="https://social-contract.test/raw_%28copy%29">Raw safe</a>',
        '<a>Raw action</a>',
        '<a>Raw multiline action</a>',
        'javascript&#58;auto()',
        '[Unsafe reference][unsafe-reference]',
        '[Escaped reference][unsafe\\]]',
        '> [Quoted reference][quoted-reference]'
      )
      expect(materialized).not_to include(
        '[Unsafe action](',
        '[Unsafe titled action](',
        '[Multiline unsafe',
        '[Unsafe after invalid fence](',
        '[Unsafe after unmatched span](',
        '[unsafe-reference]:',
        '[unsafe\\]]:',
        '[quoted-reference]:',
        'href="javascript:'
      )
      expect(materialized).to include(
        '\\[Escaped literal](javascript:escaped())',
        '    [Indented literal](javascript:indented())',
        '`[Inline literal](javascript:inlineCode())`',
        "`multiline\n[Multiline literal](javascript:multiCode())\nspan`",
        "```text\n[Fenced literal](javascript:fenced())\n```",
        "> ```text\n> [Quoted fenced literal](javascript:quotedFenced())\n> ```"
      )
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
