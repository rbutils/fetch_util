# frozen_string_literal: true

RSpec.describe 'FetchUtil extractor integration - GitHub threads' do
  include_context 'extractor integration helpers'

  def github_fixture(name)
    fixture_contents(File.expand_path("../fixtures/#{name}", __dir__))
  end

  def expect_no_social_fields(payload)
    expect(payload.values_at('socialKind', 'platform', 'handle', 'replyCount', 'community', 'score')).to all(be_nil)
  end

  it 'extracts a public issue timeline as a social thread' do
    extract_from_url('https://github.com/octo/example/issues/12', github_fixture('github_issue_thread.html'), reader_mode: false) do |payload|
      expect(payload).to include('contentType' => 'social', 'socialKind' => 'thread', 'platform' => 'GitHub',
                                 'handle' => 'octocat', 'replyCount' => 2, 'community' => 'octo/example', 'score' => 7)
      expect(payload['markdown']).to include('# Bug: markdown links lose fragments',
                                             '[reference link](https://example.test/docs#anchors)', 'puts :anchor', '### Comment by hubot')
      expect(payload['markdown']).not_to include('labeled this bug', 'Notifications and sidebar noise')
    end
  end

  it 'extracts pull-request reviews without timeline events' do
    extract_from_url('https://github.com/octo/example/pull/42', github_fixture('github_pull_thread.html'), reader_mode: false) do |payload|
      expect(payload).to include('contentType' => 'social', 'handle' => 'maintainer', 'replyCount' => 1, 'community' => 'octo/example', 'score' => nil)
      expect(payload['markdown']).to include('- Pull Request: octo/example', '### Accepted answer by reviewer')
    end
  end

  it 'extracts a no-comment discussion with an explicit zero reply count' do
    extract_from_url('https://github.com/octo/example/discussions/9', github_fixture('github_discussion_no_comments.html'), reader_mode: false) do |payload|
      expect(payload).to include('contentType' => 'social', 'handle' => 'discussion-author', 'replyCount' => 0, 'community' => 'octo/example')
      expect(payload['markdown']).to include('Can this preserve links')
      expect(payload['markdown']).not_to include('## Comments')
    end
  end

  it 'keeps public GitHub login and not-found pages out of social extraction' do
    [['issues/12', 'github_login_wall.html'], ['issues/404', 'github_not_found.html']].each do |route, fixture|
      extract_from_url("https://github.com/octo/example/#{route}", github_fixture(fixture), reader_mode: false) do |payload|
        expect(payload['contentType']).to eq('interstitial')
        expect_no_social_fields(payload)
      end
    end
  end

  it 'keeps repository-root README extraction separate from social threads' do
    extract_from_url('https://github.com/octo/example', github_fixture('github_repository_root.html'), reader_mode: false) do |payload|
      expect(payload['contentType']).to eq('article')
      expect(payload['markdown']).to include('Repository README content remains separate')
      expect_no_social_fields(payload)
    end
  end
end
