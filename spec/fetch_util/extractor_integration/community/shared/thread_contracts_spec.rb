# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'FetchUtil extractor integration - community social threads' do
  include_context 'extractor integration helpers'

  def community_fixture(name)
    fixture_contents(File.expand_path("../../../fixtures/community/contracts/#{name}", __dir__))
  end

  def expect_no_social_fields(payload)
    expect(payload.values_at('socialKind', 'platform', 'handle', 'replyCount', 'community', 'score')).to all(be_nil)
  end

  it 'classifies a Reddit focal post with retained comments as a social thread' do
    extract_from_url('https://www.reddit.com/r/ruby/comments/123/ruby-thread', community_fixture('reddit_thread.html')) do |payload|
      expect(payload).to include('contentType' => 'social', 'socialKind' => 'thread', 'platform' => 'Reddit',
                                 'handle' => 'alice', 'replyCount' => 2, 'community' => 'r/ruby', 'score' => 17)
      expect(payload['markdown']).to include('First top-level comment.', 'Second top-level comment.')
      expect(payload['markdown'].scan('First top-level comment.').length).to eq(1)
      expect(payload['markdown'].index('First top-level comment.')).to be < payload['markdown'].index('Second top-level comment.')
    end
  end

  it 'classifies a coherent custom-element thread without a site profile' do
    html = <<~HTML
      <html><head><title>Garden planning</title><meta property="og:site_name" content="Gather"></head><body><main>
        <gather-post author="orchard" comment-count="2" score="9">
          <h1 slot="title">Garden planning</h1>
          <div slot="text-body">Neighbors are planning the autumn garden together.</div>
        </gather-post>
        <gather-comment author="seedling"><div slot="comment">I can bring tomato seeds and tools.</div></gather-comment>
        <gather-comment author="compost"><div slot="comment">I will organize the compost delivery.</div></gather-comment>
      </main></body></html>
    HTML

    extract_from_url('https://community.example/c/gardening/thread/42', html) do |payload|
      expect(payload).to include('contentType' => 'social', 'socialKind' => 'thread', 'platform' => 'Gather',
                                 'handle' => 'orchard', 'replyCount' => 2, 'community' => 'c/gardening', 'score' => 9)
      expect(payload['markdown']).to include('Neighbors are planning', 'I can bring tomato seeds',
                                             'I will organize the compost delivery')
      expect(payload['markdown'].scan('I can bring tomato seeds').length).to eq(1)
      expect(payload['markdown'].scan('I will organize the compost delivery').length).to eq(1)
    end
  end

  it 'classifies verified Discourse topic and category list DOM as a thread and feed' do
    extract_from_url('https://forum.example/t/trust-levels-explained/123', community_fixture('discourse_topic.html')) do |payload|
      expect(payload).to include('contentType' => 'social', 'socialKind' => 'thread', 'platform' => 'Discourse', 'community' => 'Community')
      expect(payload['markdown']).to include('## post by alice', '## post by bob')
    end

    extract_from_url('https://forum.example/c/community', community_fixture('discourse_list.html')) do |payload|
      expect(payload).to include('contentType' => 'social', 'socialKind' => 'feed', 'platform' => 'Discourse', 'community' => 'Community')
      expect(payload['markdown']).to include('Welcome', 'Release notes')
    end
  end

  it 'classifies a structurally evidenced generic social feed' do
    cards = (1..4).map do |number|
      <<~HTML
        <article class="post feed-item">
          <h2><a href="/posts/#{number}">Garden update #{number}</a></h2>
          <p>Neighbors shared garden update #{number} with the group.</p>
          <span class="author">gardener#{number}</span>
          <time datetime="2026-09-#{10 + number}">#{number} days ago</time>
          <span class="score">#{number * 3} points</span>
          <a class="comments" href="/posts/#{number}#comments">#{number + 1} replies</a>
        </article>
      HTML
    end.join
    html = <<~HTML
      <html><head><title>Garden updates</title><meta property="og:site_name" content="Common Ground"></head>
      <body><main><h1>Garden updates</h1>#{cards}</main></body></html>
    HTML

    extract_from_url('https://community.example/tag/gardening', html) do |payload|
      expect(payload).to include('contentType' => 'social', 'socialKind' => 'feed', 'platform' => 'Common Ground',
                                 'community' => 'gardening')
      expect(payload.fetch('warnings', [])).not_to include('url_content_mismatch')
      expect(payload['markdown']).to include('Garden update 1', 'gardener1', '2 replies', 'Garden update 4')
      expect(payload['markdown'].scan(/\[Garden update \d\]\(/).length).to eq(4)
    end
  end

  it 'classifies Stack Overflow and Stack Exchange question DOM with shared answer headings' do
    extract_from_url('https://stackoverflow.com/questions/123/ruby-blocks', community_fixture('stackoverflow_question.html')) do |payload|
      expect(payload).to include('contentType' => 'social', 'socialKind' => 'thread', 'platform' => 'Stack Overflow',
                                 'handle' => 'Ada', 'replyCount' => 1, 'community' => 'Stack Overflow', 'score' => 5)
      expect(payload['markdown']).to include('## Top Answers', '### Answer 1 (accepted) - score 9')
    end

    extract_from_url('https://history.stackexchange.com/questions/68200/roman-languages', community_fixture('stack_exchange_question.html')) do |payload|
      expect(payload).to include('contentType' => 'social', 'socialKind' => 'thread', 'platform' => 'Stack Exchange',
                                 'handle' => 'Timothy', 'replyCount' => 2, 'community' => 'History Stack Exchange', 'score' => 8)
      expect(payload['markdown']).to include('## Top Answers', '### Example User (accepted) - score 33')
    end
  end

  it 'keeps generic article, list, and login-wall pages untyped' do
    extract_from_url('https://example.com/garden-report', community_fixture('generic_article.html')) do |payload|
      expect(payload['contentType']).to eq('article')
      expect_no_social_fields(payload)
    end

    extract_from_url('https://example.com/resources', community_fixture('generic_list.html')) do |payload|
      expect(payload['contentType']).to eq('list')
      expect_no_social_fields(payload)
    end

    extract_from_url('https://www.reddit.com/r/ruby/comments/123/ruby-thread', community_fixture('login_wall.html')) do |payload|
      expect(payload['contentType']).to eq('interstitial')
      expect_no_social_fields(payload)
    end
  end
end
