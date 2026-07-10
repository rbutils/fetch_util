# frozen_string_literal: true

RSpec.describe 'FetchUtil social visible-entry fidelity' do
  include_context 'extractor integration helpers'

  def repeated_nodes(wrapper, count)
    (1..count).map { |index| format(wrapper, index: index) }.join
  end

  it 'preserves every Reddit comment, including comments after the former cap' do
    comments = repeated_nodes('<shreddit-comment depth="0" author="user%<index>d" score="%<index>d"><div slot="comment">Reddit comment %<index>d is visible.</div></shreddit-comment>', 10)
    html = '<shreddit-post author="alice" comment-count="10" score="17"><h1 slot="title">Ruby thread</h1><div slot="text-body">A public Reddit post.</div></shreddit-post>' + comments

    extract_from_url('https://www.reddit.com/r/ruby/comments/123/ruby-thread', html) do |payload|
      expect(payload).to include('contentType' => 'social', 'socialKind' => 'thread', 'platform' => 'Reddit')
      expect(payload['markdown']).to include('Reddit comment 1 is visible.', 'Reddit comment 10 is visible.')
      expect(payload['markdown'].index('Reddit comment 1')).to be < payload['markdown'].index('Reddit comment 10')
    end
  end

  it 'preserves all Stack Overflow answers and GitHub comments in order' do
    answers = repeated_nodes('<div class="answer" data-answerid="%<index>d"><div class="js-post-body">Stack Overflow answer %<index>d contains useful detail.</div></div>', 8)
    question = '<div id="question"><h1 id="question-header"><a>Ruby blocks</a></h1><div class="js-post-body">How do Ruby blocks work?</div></div><div id="answers" data-answercount="8">' + answers + '</div>'
    extract_from_url('https://stackoverflow.com/questions/123/ruby-blocks', question) do |payload|
      expect(payload).to include('contentType' => 'social', 'socialKind' => 'thread', 'platform' => 'Stack Overflow')
      expect(payload['markdown']).to include('Stack Overflow answer 1', 'Stack Overflow answer 8')
    end

    comments = repeated_nodes('<div class="timeline-comment"><a class="author">user%<index>d</a><div class="comment-body">GitHub comment %<index>d contains useful detail.</div></div>', 14)
    github = '<main><h1>Issue title</h1><div class="discussion-timeline"><div class="timeline-comment"><a class="author">opener</a><div class="comment-body">Opening issue body with enough detail.</div></div>' + comments + '</div></main>'
    extract_from_url('https://github.com/acme/project/issues/42', github) do |payload|
      expect(payload).to include('contentType' => 'social', 'socialKind' => 'thread', 'platform' => 'GitHub')
      expect(payload['markdown']).to include('GitHub comment 1', 'GitHub comment 14')
    end
  end

  it 'preserves late Mastodon replies and native profile posts' do
    replies = repeated_nodes('<article class="status"><div class="status__display-name">user%<index>d</div><div class="status__content__text">Mastodon reply %<index>d has enough visible content.</div></article>', 10)
    mastodon = '<main><div class="detailed-status__wrapper detailed-status__wrapper-public"><div class="detailed-status"><div class="detailed-status__display-name">Ada</div><div class="display-name__account">@ada@example.social</div><div class="status__content__text">Mastodon focal post with enough visible content.</div><div class="detailed-status__action-bar"></div></div></div>' + replies + '</main>'
    extract_from_url('https://example.social/@ada/123', mastodon) do |payload|
      expect(payload).to include('contentType' => 'social', 'socialKind' => 'thread', 'platform' => 'Mastodon')
      expect(payload['markdown']).to include('Mastodon reply 1', 'Mastodon reply 10')
    end

    posts = repeated_nodes('<div data-testid="postText">Bluesky profile post %<index>d has enough text.</div>', 7)
    bluesky = '<main data-testid="profileScreen"><div data-testid="profileHeaderDisplayName">Ada Lovelace</div><div data-testid="profileHeaderDescription">Public computing notes.</div>' + posts + '</main>'
    extract_from_url('https://bsky.app/profile/ada.bsky.social', bluesky) do |payload|
      expect(payload).to include('contentType' => 'social', 'socialKind' => 'profile', 'platform' => 'Bluesky')
      expect(payload['markdown']).to include('Bluesky profile post 1', 'Bluesky profile post 7')
    end
  end

  it 'preserves late X and Behance visible entries' do
    tweets = repeated_nodes('<article data-testid="tweet"><div data-testid="User-Name">Ada Lovelace @ada</div><div data-testid="tweetText">X profile post %<index>d has enough visible text.</div></article>', 7)
    x_html = '<main><div data-testid="UserName">Ada Lovelace @ada</div><div data-testid="UserDescription">Public notes.</div>' + tweets + '</main>'
    extract_from_url('https://x.com/ada', x_html) do |payload|
      expect(payload['markdown']).to include('X profile post 1', 'X profile post 7')
    end

    projects = repeated_nodes('<a href="/project/%<index>d">Behance project %<index>d</a>', 14)
    extract_from_url('https://www.behance.net/search/projects', '<main>' + projects + '</main>') do |payload|
      expect(payload['markdown']).to include('Behance project 1', 'Behance project 14')
    end

  end
end
