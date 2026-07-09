# frozen_string_literal: true

RSpec.describe 'FetchUtil native social network profiles' do
  include_context 'extractor integration helpers'

  def expect_social(payload, kind:, platform:, handle: nil, reply_count: nil)
    expect(payload).to include('contentType' => 'social', 'socialKind' => kind, 'platform' => platform)
    expect(payload['handle']).to eq(handle) unless handle.nil?
    expect(payload['replyCount']).to eq(reply_count) unless reply_count.nil?
  end

  def expect_no_social(payload)
    expect(payload['contentType']).not_to eq('social')
    expect(payload.values_at('socialKind', 'platform', 'handle', 'replyCount')).to all(be_nil)
  end

  it 'classifies an X profile only when its native header contains public content' do
    html = <<~HTML
      <html><head><title>Ada (@ada) / X</title></head><body><main><div data-testid="UserName">Ada Lovelace @ada</div><div data-testid="UserDescription">Public notes on computing history.</div><a href="/ada/followers">42 followers</a></main></body></html>
    HTML

    extract_from_url('https://x.com/ada', html) do |payload|
      expect_social(payload, kind: 'profile', platform: 'X', handle: '@ada')
      expect(payload['markdown']).to include('Public notes on computing history.')
    end
  end

  it 'classifies a public X post with retained replies as a thread and keeps its explicit count' do
    html = <<~HTML
      <html><head><title>Ada on X</title></head><body><main><article data-testid="tweet"><div data-testid="User-Name">Ada Lovelace @ada</div><div data-testid="tweetText">A public focal post with enough content to retain.</div><button data-testid="reply" aria-label="3 replies"></button></article><article data-testid="tweet"><div data-testid="User-Name">Grace Hopper @grace</div><div data-testid="tweetText">A retained public reply.</div></article></main></body></html>
    HTML

    extract_from_url('https://x.com/ada/status/123', html) do |payload|
      expect_social(payload, kind: 'thread', platform: 'X', handle: '@ada', reply_count: 3)
      expect(payload['markdown']).to include('## Replies')
    end
  end

  it 'classifies Bluesky profile and thread DOM shapes' do
    profile_html = <<~HTML
      <html><head><title>Ada - Bluesky</title></head><body><main data-testid="profileScreen"><div data-testid="profileHeaderDisplayName">Ada Lovelace</div><div data-testid="profileHeaderDescription">Public computing notes.</div><button data-testid="profileHeaderFollowersButton" aria-label="12 followers">12 followers</button></main></body></html>
    HTML
    thread_html = <<~HTML
      <html><head><title>Ada - Bluesky</title></head><body><main><div data-testid="feedItem-by-ada.bsky.social"><div data-testid="postText">A public focal Bluesky post with enough text.</div><button data-testid="replyBtn" aria-label="Replies (2 replies)"></button></div><div data-testid="feedItem-by-grace.bsky.social"><div data-testid="postText">A retained Bluesky reply.</div></div></main></body></html>
    HTML

    extract_from_url('https://bsky.app/profile/ada.bsky.social', profile_html) do |payload|
      expect_social(payload, kind: 'profile', platform: 'Bluesky', handle: '@ada.bsky.social')
    end
    extract_from_url('https://bsky.app/profile/ada.bsky.social/post/abc', thread_html) do |payload|
      expect_social(payload, kind: 'thread', platform: 'Bluesky', handle: '@ada.bsky.social', reply_count: 2)
      expect(payload['markdown']).to include('## Replies')
    end
  end

  it 'classifies the current Bluesky post DOM only with its matching structured post evidence' do
    current_post_html = <<~HTML
      <html><head><title>Post by @ada.bsky.social - Bluesky</title><meta property="og:type" content="article"></head><body><main data-testid="postThreadScreen"><div data-testid="postThreadItem-by-ada.bsky.social"><a href="/profile/ada.bsky.social">Ada Lovelace @ada.bsky.social</a><p>A current public Bluesky focal post.</p><button data-testid="replyBtn" aria-label="Reply (2 replies)">2</button></div></main><script type="application/ld+json">{"@context":"https://schema.org","@type":"WebPage","mainEntity":{"@type":"DiscussionForumPosting","url":"https://bsky.app/profile/ada.bsky.social/post/current","author":{"@type":"Person","name":"Ada Lovelace","alternateName":"@ada.bsky.social"},"text":"A current public Bluesky focal post.","commentCount":2,"comment":[{"@type":"Comment","text":"A retained public reply."}]}}</script></body></html>
    HTML
    og_only_shell = <<~HTML
      <html><head><title>Post by @ada.bsky.social - Bluesky</title><meta property="og:type" content="article"><meta property="og:description" content="A public-looking post."></head><body><main data-testid="postThreadScreen"><h1>Sign in to see this post</h1></main></body></html>
    HTML
    lookalike = <<~HTML
      <html><body><main data-testid="postThreadScreen"><div data-testid="postThreadItem-by-ada.bsky.social">A public-looking post.</div></main><script type="application/ld+json">{"@type":"DiscussionForumPosting","url":"https://bsky.app/profile/other.bsky.social/post/current","text":"A public-looking post."}</script></body></html>
    HTML

    extract_from_url('https://bsky.app/profile/ada.bsky.social/post/current', current_post_html) do |payload|
      expect_social(payload, kind: 'thread', platform: 'Bluesky', handle: '@ada.bsky.social', reply_count: 2)
      expect(payload['markdown']).to include('A retained public reply.')
    end
    extract_from_url('https://bsky.app/profile/ada.bsky.social/post/current', og_only_shell) { |payload| expect_no_social(payload) }
    extract_from_url('https://bsky.app/profile/ada.bsky.social/post/current', lookalike) { |payload| expect_no_social(payload) }
  end

  it 'classifies a LinkedIn company profile when public profile fields are returned' do
    html = <<~HTML
      <html><head><title>Acme Systems | LinkedIn</title></head><body><main><h1>Acme Systems</h1><p>Industry</p><p>Software Development</p><p>100 followers</p><p>About</p><p>Acme builds public infrastructure software for local communities.</p><p>Website</p><p>https://acme.example</p></main></body></html>
    HTML

    extract_from_url('https://www.linkedin.com/company/acme-systems/', html) do |payload|
      expect_social(payload, kind: 'profile', platform: 'LinkedIn')
      expect(payload['markdown']).to include('Acme builds public infrastructure software')
    end
  end

  it 'leaves native login and empty profile shells unclassified' do
    x_wall = '<html><head><title>Log in to X</title></head><body><main><h1>Log in</h1><form><input type="text"><input type="password"></form></main></body></html>'
    bluesky_shell = '<html><head><title>Bluesky</title></head><body><main data-testid="profileScreen"><h1>Sign in</h1></main></body></html>'
    linkedin_wall = <<~HTML.strip
      <html><head><title>Sign In | LinkedIn</title></head><body><main><h1>Sign in</h1><form><input type="email"><input type="password"></form></main></body></html>
    HTML
    weibo_shell = '<html><head><title>微博</title></head><body><main><p>请登录后查看动态</p></main></body></html>'

    extract_from_url('https://x.com/ada', x_wall) { |payload| expect_no_social(payload) }
    extract_from_url('https://bsky.app/profile/ada.bsky.social', bluesky_shell) { |payload| expect_no_social(payload) }
    extract_from_url('https://www.linkedin.com/in/ada/', linkedin_wall) { |payload| expect_no_social(payload) }
    extract_from_url('https://m.weibo.cn/status/123', weibo_shell) { |payload| expect_no_social(payload) }
  end
end
