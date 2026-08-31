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
      expect(payload['markdown']).to include(
        '# Bug: markdown links lose fragments',
        '[reference link](https://example.test/docs#anchors)', 'puts :anchor', '### Comment by hubot',
        'labeled this bug'
      )
      expect(payload['markdown']).not_to include('Notifications and sidebar noise')
    end
  end

  it 'preserves every loaded modern issue record and exposes continuation metadata' do
    extract_from_url('https://github.com/octo/example/issues/12', github_fixture('github_modern_issue_thread.html'), reader_mode: false) do |payload|
      markdown = payload.fetch('markdown')
      expect(payload).to include('contentType' => 'social', 'handle' => 'octocat', 'replyCount' => nil,
                                 'community' => 'octo/example', 'score' => 5)
      expect(markdown).to include('## Metadata', '### Assignees', '[maintainer](https://github.com/maintainer)',
                                  '### Labels', '[fidelity](https://github.com/octo/example/labels/fidelity)',
                                  '### Milestone', 'Complete fidelity',
                                  '[Event by octocat](https://github.com/octo/example/issues/12#event-1201)',
                                  '[Comment by hubot](https://github.com/octo/example/issues/12#issuecomment-1202)',
                                  '[Comment by reviewer](https://github.com/octo/example/issues/12#issuecomment-1203)',
                                  '[7 remaining items](https://github.com/octo/example/issues/12?timeline_page=1)')
      expect(markdown).not_to include('Hidden modern comment')
      expect(markdown).to include('Grouped reply remains in the same timeline row.')
      expect(markdown.scan('Repeated grouped reply.').length).to eq(2)
      expect(markdown.scan('UNOWNEDTIMELINELINK').length).to eq(1)
      expect(markdown.scan('timeline_page=9').length).to eq(1)
      expect(payload.fetch('html')).not_to include('Hidden child must not leak into HTML.')
      expect(markdown.scan('Opening body for the modern issue.').length).to eq(1)
      expect(markdown.index('labeled this as')).to be < markdown.index('First modern comment')
      expect(markdown.index('First modern comment')).to be < markdown.index('Second modern comment')
    end
  end

  it 'leaves the reply count unknown when rendered metadata proves records are missing' do
    html = github_fixture('github_modern_issue_thread.html')
    html = html.sub('3 comments', '9 comments')
    html = html.sub(%r{\s*<div data-testid="issue-timeline-load-more-wrapper-load-top">.*?</div>}m, '')

    extract_from_url('https://github.com/octo/example/issues/12', html, reader_mode: false) do |payload|
      expect(payload['replyCount']).to be_nil
      expect(payload.fetch('markdown')).not_to include('timeline_page=1')
    end
  end

  it 'preserves a comment-only issue and its browse inventory' do
    html = github_fixture('github_modern_issue_thread.html').sub(
      '<p>Opening body for the modern issue. <a href="/octo/example/issues/12?timeline_page=9">UNOWNEDTIMELINELINK</a></p>',
      ''
    ).sub('<span data-testid="issue-comment-count">3 comments</span>', '')

    extract_from_url('https://github.com/octo/example/issues/12', html, reader_mode: false) do |payload|
      expect(payload['contentType']).to eq('social')
      expect(payload['replyCount']).to be_nil
      expect(payload.fetch('markdown')).to include('First modern comment keeps its', 'timeline_page=1')
    end
  end

  it 'preserves an uncapped modern timeline in exact DOM order' do
    rows = (1..25).map do |index|
      <<~HTML
        <div data-testid="timeline-row-border-BULK#{index}">
          <a data-testid="avatar-link">user#{index}</a>
          <a href="#issuecomment-#{2000 + index}"><relative-time datetime="2026-08-01T11:#{index.to_s.rjust(2, "0")}:00Z">Aug 1</relative-time></a>
          <div data-testid="markdown-body"><p>Uncapped timeline record #{index}.</p></div>
        </div>
      HTML
    end.join
    timeline_end = "</section>\n    <div data-testid=\"issue-timeline-load-more-wrapper-load-top\">"
    html = github_fixture('github_modern_issue_thread.html')
    html = html.sub('<span data-testid="issue-comment-count">3 comments</span>',
                    '<span data-testid="issue-comment-count">27 comments</span>')
    html = html.sub(timeline_end, "#{rows}#{timeline_end}")

    extract_from_url('https://github.com/octo/example/issues/12', html, reader_mode: false) do |payload|
      markdown = payload.fetch('markdown')
      expect((1..25).all? { |index| markdown.include?("Uncapped timeline record #{index}.") }).to be(true)
      expect(markdown.index('Uncapped timeline record 1.')).to be < markdown.index('Uncapped timeline record 25.')
    end
  end

  it 'preserves distinct idless records while deduplicating stable permalinks' do
    records = <<~HTML
      <div data-testid="timeline-row-border-IDLESS1">
        <a data-testid="avatar-link">idless-user</a>
        <div data-testid="markdown-body"><p>Repeated idless GitHub record.</p></div>
      </div>
      <div data-testid="timeline-row-border-IDLESS2">
        <a data-testid="avatar-link">idless-user</a>
        <div data-testid="markdown-body"><p>Repeated idless GitHub record.</p></div>
      </div>
      <div data-testid="timeline-row-border-DUPLICATE">
        <a data-testid="avatar-link">hubot</a>
        <a href="#issuecomment-1202">Duplicate responsive permalink</a>
        <div data-testid="markdown-body"><p>Duplicate permalink must not create another record.</p></div>
      </div>
    HTML
    timeline_end = "</section>\n    <div data-testid=\"issue-timeline-load-more-wrapper-load-top\">"
    html = github_fixture('github_modern_issue_thread.html').sub(timeline_end, "#{records}#{timeline_end}")

    extract_from_url('https://github.com/octo/example/issues/12', html, reader_mode: false) do |payload|
      markdown = payload.fetch('markdown')
      expect(markdown.scan('Repeated idless GitHub record.').length).to eq(2)
      expect(markdown).not_to include('Duplicate permalink must not create another record.')
    end
  end

  it 'extracts a modern discussion through the shared thread shape' do
    extract_from_url('https://github.com/octo/example/discussions/12', github_fixture('github_modern_issue_thread.html'), reader_mode: false) do |payload|
      expect(payload).to include('contentType' => 'social', 'platform' => 'GitHub', 'community' => 'octo/example')
      expect(payload.fetch('markdown')).to include('- Discussion: octo/example', 'First modern comment keeps its')
    end
  end

  it 'preserves pull-request reviews and exposes every public surface' do
    extract_from_url('https://github.com/octo/example/pull/42', github_fixture('github_modern_pull_thread.html'), reader_mode: false) do |payload|
      markdown = payload.fetch('markdown')
      expect(payload).to include('contentType' => 'social', 'handle' => 'maintainer', 'replyCount' => 3,
                                 'community' => 'octo/example')
      expect(markdown).to include('[Review by reviewer](https://github.com/octo/example/pull/42#pullrequestreview-4201)',
                                  '[Review by inline-reviewer](https://github.com/octo/example/pull/42#discussion_r4202)',
                                  '[Event by maintainer](https://github.com/octo/example/pull/42#event-4203)',
                                  '[Commits](https://github.com/octo/example/pull/42/commits)',
                                  '[Checks](https://github.com/octo/example/pull/42/checks)',
                                  '[Files changed](https://github.com/octo/example/pull/42/files)',
                                  '[Raw diff](https://github.com/octo/example/pull/42.diff)',
                                  '[Raw patch](https://github.com/octo/example/pull/42.patch)')
      expect(markdown.scan('Opening pull request body appears exactly once.').length).to eq(1)
      expect(markdown.scan('Responsive comment appears once.').length).to eq(1)
      expect(markdown).not_to include('timeline_page=1', 'timeline_page=7', 'Stale load more', 'Disabled continuation')
      expect(markdown.index('Review summary')).to be < markdown.index('Inline review thread')
      expect(markdown.index('Inline review thread')).to be < markdown.index('ready for review')
    end
  end

  it 'uses a later enabled timeline control after stale controls' do
    control = '<a data-testid="issue-timeline-load-more-load-bottom" href="?timeline_page=1">2 remaining items</a>'
    html = github_fixture('github_modern_pull_thread.html').sub('</main>', "#{control}</main>")

    extract_from_url('https://github.com/octo/example/pull/42', html, reader_mode: false) do |payload|
      expect(payload['replyCount']).to be_nil
      expect(payload.fetch('markdown')).to include('[2 remaining items](https://github.com/octo/example/pull/42?timeline_page=1)')
    end
  end

  it 'counts accepted answers as modern discussion replies' do
    html = github_fixture('github_modern_issue_thread.html')
    html = html.sub('3 comments', '2 comments')
    html = html.sub('data-testid="comment-viewer-outer-box-COMMENT1"',
                    'data-testid="comment-viewer-outer-box-COMMENT1" data-accepted="true"')
    html = html.sub('<div data-testid="markdown-body"><p>First modern comment',
                    '<span data-testid="accepted-answer">Accepted answer</span><div data-testid="markdown-body"><p>First modern comment')
    html = html.sub(%r{\s*<div data-testid="issue-timeline-load-more-wrapper-load-top">.*?</div>}m, '')

    extract_from_url('https://github.com/octo/example/discussions/12', html, reader_mode: false) do |payload|
      expect(payload['replyCount']).to eq(2)
      expect(payload.fetch('markdown')).to include(
        '[Accepted answer by hubot](https://github.com/octo/example/discussions/12#issuecomment-1202)'
      )
    end
  end

  it 'preserves modern discussion comment permalinks' do
    html = github_fixture('github_modern_issue_thread.html')
           .gsub('#issuecomment-1202', '#discussioncomment-1202')

    extract_from_url('https://github.com/octo/example/discussions/12', html, reader_mode: false) do |payload|
      expect(payload.fetch('markdown')).to include(
        '[Comment by hubot](https://github.com/octo/example/discussions/12#discussioncomment-1202)'
      )
    end
  end

  it 'does not let loaded reviews mask a missing reported comment' do
    html = github_fixture('github_modern_pull_thread.html').sub('1 comment', '2 comments')

    extract_from_url('https://github.com/octo/example/pull/42', html, reader_mode: false) do |payload|
      expect(payload['replyCount']).to be_nil
    end
  end

  it 'preserves every record on a timeline continuation page' do
    extract_from_url('https://github.com/octo/example/issues/12?timeline_page=1', github_fixture('github_timeline_page.html'), reader_mode: false) do |payload|
      markdown = payload.fetch('markdown')
      expect(payload).to include('contentType' => 'social', 'replyCount' => nil, 'community' => 'octo/example')
      expect(markdown).to include(
        '[Comment by user1](https://github.com/octo/example/issues/12?timeline_page=1#issuecomment-1301)',
        '[Comment by user5](https://github.com/octo/example/issues/12?timeline_page=1#issuecomment-1305)'
      )
      expect(markdown.index('Continuation comment 1.')).to be < markdown.index('Continuation comment 5.')
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

  it 'keeps subroutes, malformed routes, and other hosts out of GitHub thread extraction' do
    html = github_fixture('github_modern_issue_thread.html')

    [
      'https://github.com/octo/example/pull/42/checks',
      'https://github.com/octo/example/issues/not-a-number',
      'https://example.test/octo/example/issues/12'
    ].each do |url|
      extract_from_url(url, html, reader_mode: false) do |payload|
        expect(payload['platform']).not_to eq('GitHub')
      end
    end
  end
end
