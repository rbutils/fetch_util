# frozen_string_literal: true

RSpec.describe 'FetchUtil social visible-entry fidelity' do
  include_context 'extractor integration helpers'

  def repeated_nodes(wrapper, count)
    (1..count).map { |index| format(wrapper, index: index) }.join
  end

  it 'preserves late Mastodon replies and native profile posts' do
    replies = repeated_nodes(<<~HTML, 10)
      <article class="status"><div class="status__display-name">user%<index>d</div>
        <div class="status__content__text">Mastodon reply %<index>d has enough visible content.</div>
      </article>
    HTML
    mastodon = <<~HTML
      <main><div class="detailed-status__wrapper detailed-status__wrapper-public">
        <div class="detailed-status"><div class="detailed-status__display-name">Ada</div>
          <div class="display-name__account">@ada@example.social</div>
          <div class="status__content__text">Mastodon focal post with enough visible content.</div>
          <div class="detailed-status__action-bar"></div>
        </div>
      </div>#{replies}</main>
    HTML
    extract_from_url('https://example.social/@ada/123', mastodon) do |payload|
      expect(payload).to include('contentType' => 'social', 'socialKind' => 'thread', 'platform' => 'Mastodon')
      expect(payload['markdown']).to include('Mastodon reply 1', 'Mastodon reply 10')
    end

    posts = repeated_nodes('<div data-testid="postText">Bluesky profile post %<index>d has enough text.</div>', 7)
    bluesky = <<~HTML
      <main data-testid="profileScreen">
        <div data-testid="profileHeaderDisplayName">Ada Lovelace</div>
        <div data-testid="profileHeaderDescription">Public computing notes.</div>
        #{posts}
      </main>
    HTML
    extract_from_url('https://bsky.app/profile/ada.bsky.social', bluesky) do |payload|
      expect(payload).to include('contentType' => 'social', 'socialKind' => 'profile', 'platform' => 'Bluesky')
      expect(payload['markdown']).to include('Bluesky profile post 1', 'Bluesky profile post 7')
    end
  end

  it 'preserves late X and Behance visible entries' do
    tweets = repeated_nodes(<<~HTML, 7)
      <article data-testid="tweet"><div data-testid="User-Name">Ada Lovelace @ada</div>
        <div data-testid="tweetText">X profile post %<index>d has enough visible text.</div>
      </article>
    HTML
    x_html = <<~HTML
      <main><div data-testid="UserName">Ada Lovelace @ada</div>
        <div data-testid="UserDescription">Public notes.</div>#{tweets}
      </main>
    HTML
    extract_from_url('https://x.com/ada', x_html) do |payload|
      expect(payload['markdown']).to include('X profile post 1', 'X profile post 7')
    end

    projects = repeated_nodes('<a href="/project/%<index>d">Behance project %<index>d</a>', 14)
    extract_from_url('https://www.behance.net/search/projects', "<main>#{projects}</main>") do |payload|
      expect(payload['markdown']).to include('Behance project 1', 'Behance project 14')
    end
  end
end
