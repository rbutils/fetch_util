# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'FetchUtil extractor integration - Hacker News' do
  include_context 'extractor integration helpers'

  def hacker_news_fixture(name)
    fixture_contents(File.expand_path("../../fixtures/#{name}", __dir__))
  end

  it 'extracts item threads with story text, source links, and nested comments' do
    extract_from_url('https://news.ycombinator.com/item?id=100', hacker_news_fixture('hacker_news_item_thread.html')) do |payload|
      expect(payload).to include('contentType' => 'social', 'socialKind' => 'thread', 'platform' => 'Hacker News',
                                 'handle' => 'alice', 'score' => 42, 'replyCount' => 2, 'community' => nil)
      expect(payload['markdown']).to include('[Sample parser note](https://example.test/parser)')
      expect(payload['markdown']).to include('Fixture text keeps `code` intact.')
      expect(payload['markdown']).to include('### bob (2 hours ago)')
      expect(payload['markdown']).to include('#### carol (1 hour ago)')
    end
  end

  it 'keeps comment-only and deleted item pages as social posts' do
    extract_from_url('https://news.ycombinator.com/item?id=101', hacker_news_fixture('hacker_news_comment_deleted.html')) do |payload|
      expect(payload).to include('contentType' => 'social', 'socialKind' => 'post', 'platform' => 'Hacker News',
                                 'handle' => 'dave', 'replyCount' => nil, 'score' => nil)
      expect(payload['markdown']).to include('Comment content is retained.')
      expect(payload['markdown']).to include('### Deleted comment')
      expect(payload['markdown']).to include('[deleted]')
    end
  end

  it 'extracts signed-out section feeds only when multiple HN story rows exist' do
    extract_from_url('https://news.ycombinator.com/ask', hacker_news_fixture('hacker_news_feed.html')) do |payload|
      expect(payload).to include('contentType' => 'social', 'socialKind' => 'feed', 'platform' => 'Hacker News',
                                 'community' => 'Ask HN')
      expect(payload['markdown']).to include('[Ask HN: How do you document small systems?](https://example.test/docs)')
      expect(payload['markdown']).to include('18 points - by erin')
    end
  end

  it 'extracts the native homepage table as a social feed' do
    extract_from_url('https://news.ycombinator.com/', hacker_news_fixture('hacker_news_homepage.html')) do |payload|
      expect(payload).to include('contentType' => 'social', 'socialKind' => 'feed', 'platform' => 'Hacker News')
      expect(payload['markdown']).to include('[A homepage story](https://example.test/homepage)')
    end
  end

  it 'does not classify a hostname-only lookalike as social' do
    extract_from_url('https://news.ycombinator.com/item?id=102', hacker_news_fixture('hacker_news_lookalike.html')) do |payload|
      expect(payload['contentType']).not_to eq('social')
      expect(payload['platform']).to be_nil
    end
  end

  it 'does not classify a generic item table on another host as social' do
    extract_from_url('https://example.test/', hacker_news_fixture('hacker_news_generic_table.html')) do |payload|
      expect(payload['contentType']).not_to eq('social')
      expect(payload['platform']).to be_nil
    end
  end
end
