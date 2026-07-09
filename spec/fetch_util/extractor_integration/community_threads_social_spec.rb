# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'FetchUtil extractor integration - community social threads' do
  include_context 'extractor integration helpers'

  def community_fixture(name)
    fixture_contents(File.expand_path("../../fixtures/#{name}", __dir__))
  end

  def expect_no_social_fields(payload)
    expect(payload.values_at('socialKind', 'platform', 'handle', 'replyCount', 'community', 'score')).to all(be_nil)
  end

  it 'classifies a Reddit focal post with retained comments as a social thread' do
    extract_from_url('https://www.reddit.com/r/ruby/comments/123/ruby-thread', community_fixture('community_reddit_thread.html')) do |payload|
      expect(payload).to include('contentType' => 'social', 'socialKind' => 'thread', 'platform' => 'Reddit',
                                 'handle' => 'alice', 'replyCount' => 2, 'community' => 'r/ruby', 'score' => 17)
      expect(payload['markdown']).to include('## Top Comments', 'First top-level comment.', 'Second top-level comment.')
    end
  end

  it 'classifies verified Discourse topic and category list DOM as a thread and feed' do
    extract_from_url('https://forum.example/t/trust-levels-explained/123', community_fixture('community_discourse_topic.html')) do |payload|
      expect(payload).to include('contentType' => 'social', 'socialKind' => 'thread', 'platform' => 'Discourse', 'community' => 'Community')
      expect(payload['markdown']).to include('## post by alice', '## post by bob')
    end

    extract_from_url('https://forum.example/c/community', community_fixture('community_discourse_list.html')) do |payload|
      expect(payload).to include('contentType' => 'social', 'socialKind' => 'feed', 'platform' => 'Discourse', 'community' => 'Community')
      expect(payload['markdown']).to include('Welcome', 'Release notes')
    end
  end

  it 'classifies Stack Overflow and Stack Exchange question DOM without changing answer headings' do
    extract_from_url('https://stackoverflow.com/questions/123/ruby-blocks', community_fixture('community_stackoverflow_question.html')) do |payload|
      expect(payload).to include('contentType' => 'social', 'socialKind' => 'thread', 'platform' => 'Stack Overflow',
                                 'handle' => 'Ada', 'replyCount' => 1, 'community' => 'Stack Overflow', 'score' => 5)
      expect(payload['markdown']).to include('## Answers', '### Accepted answer (9 votes)')
    end

    extract_from_url('https://history.stackexchange.com/questions/68200/roman-languages', community_fixture('community_stackexchange_question.html')) do |payload|
      expect(payload).to include('contentType' => 'social', 'socialKind' => 'thread', 'platform' => 'Stack Exchange',
                                 'handle' => 'Timothy', 'replyCount' => 2, 'community' => 'History Stack Exchange', 'score' => 8)
      expect(payload['markdown']).to include('## Top Answers', '### Example User (accepted) - score 33')
    end
  end

  it 'keeps generic article, list, and login-wall pages untyped' do
    extract_from_url('https://example.com/garden-report', community_fixture('community_generic_article.html')) do |payload|
      expect(payload['contentType']).to eq('article')
      expect_no_social_fields(payload)
    end

    extract_from_url('https://example.com/resources', community_fixture('community_generic_list.html')) do |payload|
      expect(payload['contentType']).to eq('list')
      expect_no_social_fields(payload)
    end

    extract_from_url('https://www.reddit.com/r/ruby/comments/123/ruby-thread', community_fixture('community_login_wall.html')) do |payload|
      expect(payload['contentType']).to eq('interstitial')
      expect_no_social_fields(payload)
    end
  end
end
