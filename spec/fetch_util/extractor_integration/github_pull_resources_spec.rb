# frozen_string_literal: true

RSpec.describe 'FetchUtil extractor integration - GitHub pull resources' do
  include_context 'extractor integration helpers'

  def github_resource_fixture(name)
    fixture_contents(File.expand_path("../fixtures/#{name}", __dir__))
  end

  it 'preserves every visible commit and recursively inventories pull-request surfaces' do
    bulk = (1..20).map do |index|
      <<~HTML
        <article data-testid="commit-row-item">
          <a data-commit-link href="/octo/example/pull/42/commits/bulk#{index}">Bulk commit #{index}</a>
          <span>bulk-author-#{index}</span>
          <p>Bulk commit detail #{index}.</p>
        </article>
      HTML
    end.join
    html = github_resource_fixture('github_pull_commits.html').sub('</section>', "#{bulk}</section>")

    extract_from_url('https://github.com/octo/example/pull/42/commits', html, reader_mode: false) do |payload|
      markdown = payload.fetch('markdown')
      expect(payload).to include('contentType' => 'list', 'siteName' => 'GitHub', 'byline' => 'octo')
      expect(markdown).to include('[Preserve conversations](https://github.com/octo/example/pull/42/commits/aaa111)',
                                  'First commit context remains visible.', 'Restored commit context remains visible.',
                                  '[Conversation](https://github.com/octo/example/pull/42)',
                                  '[Raw patch](https://github.com/octo/example/pull/42.patch)')
      expect(markdown).not_to include('Hidden commit', 'Visibility hidden commit')
      expect(markdown.scan('Preserve conversations').length).to eq(1)
      expect((1..20).all? { |index| markdown.include?("Bulk commit detail #{index}.") }).to be(true)
      expect(markdown.index('First commit context')).to be < markdown.index('Second commit context')
      expect(markdown.index('Second commit context')).to be < markdown.index('Bulk commit detail 1')
    end
  end

  it 'exposes every visible check as a traversable inventory' do
    bulk = (1..20).map do |index|
      %(<div class="checks-list-item"><a href="/octo/example/pull/42/checks?check_run_id=#{200 + index}">Bulk check #{index}</a></div>)
    end.join
    hidden = '        <details class="checks-list-item" style="display: none" open>'
    html = github_resource_fixture('github_pull_checks.html').sub(hidden, "#{bulk}#{hidden}")

    extract_from_url('https://github.com/octo/example/pull/42/checks', html, reader_mode: false) do |payload|
      markdown = payload.fetch('markdown')
      expect(payload).to include('contentType' => 'list', 'siteName' => 'GitHub', 'byline' => 'octo')
      expect(markdown).to include('[Build Linux](https://github.com/octo/example/pull/42/checks?check_run_id=101)',
                                  'Build suite — This check passed',
                                  '[Build Windows](https://github.com/octo/example/pull/42/checks?check_run_id=102)',
                                  '[Lint](https://github.com/octo/example/pull/42/checks?check_run_id=103)',
                                  '[Files changed](https://github.com/octo/example/pull/42/files)')
      expect((1..20).all? { |index| markdown.include?("Bulk check #{index}") }).to be(true)
      expect(markdown.index('Build Linux')).to be < markdown.index('Bulk check 1')
      expect(markdown.index('Bulk check 1')).to be < markdown.index('Bulk check 20')
      expect(markdown).not_to include('Hidden check', 'Visibility hidden check', 'All Linux checks passed.')
    end
  end

  it 'renders the selected check detail without losing the complete check inventory' do
    extract_from_url('https://github.com/octo/example/pull/42/checks?check_run_id=101',
                     github_resource_fixture('github_pull_checks.html'), reader_mode: false) do |payload|
      markdown = payload.fetch('markdown')
      expect(markdown).to include('## Selected check', 'All Linux checks passed.',
                                  '[View complete run](https://ci.example.test/runs/101)',
                                  'check_run_id=101', 'check_run_id=102', 'check_run_id=103')
      expect(markdown).not_to include('Hidden check log.', 'Hidden check')
    end
  end

  it 'keeps the files index bounded to an uncapped per-file inventory' do
    extract_from_url('https://github.com/octo/example/pull/42/files', github_resource_fixture('github_pull_files.html'), reader_mode: false) do |payload|
      markdown = payload.fetch('markdown')
      expect(payload).to include('contentType' => 'list', 'siteName' => 'GitHub', 'byline' => 'octo')
      expect(markdown).to include('[lib/first.rb](https://github.com/octo/example/pull/42/files#diff-first)',
                                  '[lib/second.rb](https://github.com/octo/example/pull/42/files#diff-second)',
                                  '[lib/restored.rb](https://github.com/octo/example/pull/42/files#diff-restored)',
                                  '[Raw diff](https://github.com/octo/example/pull/42.diff)',
                                  'GitHub rendered 3 of 305 changed files on this page; the public files API inventories 305.',
                                  '[Files API page 4](https://api.github.com/repos/octo/example/pulls/42/files?per_page=100&page=4)',
                                  '[lib/first.rb deferred diff](https://github.com/octo/example/pull/42/files?file=first)',
                                  '[lib/second.rb deferred diff](https://github.com/octo/example/pull/42/files?file=second)')
      expect(markdown).not_to include('lib/hidden.rb', 'first visible diff line', 'selected visible diff line',
                                      'lib/visibility-hidden.rb', 'Show comments', 'View file', 'Delete file')
    end
  end

  it 'uses the public API ceiling and complete Git ref for more than three thousand files' do
    html = github_resource_fixture('github_pull_files.html').sub('Files changed 305', 'Files changed 3001')

    extract_from_url('https://github.com/octo/example/pull/42/files', html, reader_mode: false) do |payload|
      markdown = payload.fetch('markdown')
      expect(markdown).to include('public files API inventories 3000',
                                  '[Files API page 30](https://api.github.com/repos/octo/example/pulls/42/files?per_page=100&page=30)',
                                  '[Complete pull-request Git ref](https://github.com/octo/example.git)',
                                  'Fetch refs/pull/42/head',
                                  '[Pull-request head tree archive](https://github.com/octo/example/archive/refs/pull/42/head.zip)')
      expect(markdown).not_to include('Files API page 31')
    end
  end

  it 'preserves an uncapped file inventory in exact DOM order' do
    bulk = (1..20).map do |index|
      <<~HTML
        <div class="file js-file">
          <div class="file-header" data-path="bulk/file#{index}.rb" data-anchor="diff-bulk-#{index}">bulk/file#{index}.rb +1 −0</div>
        </div>
      HTML
    end.join
    hidden = '      <div class="file js-file" style="display: none">'
    html = github_resource_fixture('github_pull_files.html').sub(hidden, "#{bulk}#{hidden}").sub('Files changed 305', 'Files changed 23')

    extract_from_url('https://github.com/octo/example/pull/42/files', html, reader_mode: false) do |payload|
      markdown = payload.fetch('markdown')
      expect((1..20).all? { |index| markdown.include?("bulk/file#{index}.rb") }).to be(true)
      expect(markdown.index('lib/restored.rb')).to be < markdown.index('bulk/file1.rb')
      expect(markdown.index('bulk/file1.rb')).to be < markdown.index('bulk/file20.rb')
      expect(markdown).not_to include('Additional file inventory pages')
    end
  end

  it 'renders one selected file with its complete visible diff and inline review' do
    extract_from_url('https://github.com/octo/example/pull/42/files#diff-second',
                     github_resource_fixture('github_pull_files.html'), reader_mode: false) do |payload|
      markdown = payload.fetch('markdown')
      expect(markdown).to include('## lib/second.rb', 'selected visible diff line',
                                  '[reviewer](https://github.com/octo/example/pull/42/files#discussion_r202)',
                                  'Inline review detail remains visible.', 'files#diff-first', 'files#diff-restored',
                                  '[lib/second.rb deferred diff](https://github.com/octo/example/pull/42/files?file=second)')
      expect(markdown).not_to include('hidden diff line', 'first visible diff line', 'restored visible diff line')
      expect(payload.fetch('html')).not_to include('hidden diff line')
    end
  end

  it 'does not render a different or hidden selected resource' do
    checks = github_resource_fixture('github_pull_checks.html')
    files = github_resource_fixture('github_pull_files.html')

    extract_from_url('https://github.com/octo/example/pull/42/checks?check_run_id=102', checks, reader_mode: false) do |payload|
      expect(payload.fetch('markdown')).not_to include('## Selected check', 'All Linux checks passed.')
    end
    extract_from_url('https://github.com/octo/example/pull/42/checks?check_run_id=998', checks, reader_mode: false) do |payload|
      expect(payload.fetch('markdown')).not_to include('Visibility hidden selected check detail.', '## Selected check')
    end
    extract_from_url('https://github.com/octo/example/pull/42/files#diff-visibility-hidden', files, reader_mode: false) do |payload|
      expect(payload.fetch('markdown')).not_to include('## lib/visibility-hidden.rb')
    end
  end

  it 'preserves explicit empty check and file states with sibling navigation' do
    checks = <<~HTML
      <html><head><title>Empty checks</title></head><body><main><h1>Empty checks</h1>
      <div class="actions-grid-container"><div class="blankslate">No checks have been run.</div></div>
      </main></body></html>
    HTML
    files = <<~HTML
      <html><head><title>Empty files</title></head><body><main><h1>Empty files</h1>
      <div class="blankslate">There are no files changed.</div>
      </main></body></html>
    HTML

    extract_from_url('https://github.com/octo/example/pull/42/checks', checks, reader_mode: false) do |payload|
      expect(payload.fetch('markdown')).to include('No checks have been run.', 'Browse this pull request')
    end
    extract_from_url('https://github.com/octo/example/pull/42/files', files, reader_mode: false) do |payload|
      expect(payload.fetch('markdown')).to include('There are no files changed.', 'Browse this pull request')
    end
  end

  it 'does not claim malformed or non-pull resource routes' do
    html = github_resource_fixture('github_pull_commits.html')
    [
      'https://github.com/octo/example/issues/42/commits',
      'https://github.com/octo/example/pull/42/commits/extra',
      'https://example.test/octo/example/pull/42/commits'
    ].each do |url|
      extract_from_url(url, html, reader_mode: false) do |payload|
        expect(payload['platform']).not_to eq('GitHub')
        expect(payload.fetch('title')).not_to include('— Commits')
        expect(payload.fetch('markdown')).not_to include('## Browse this pull request')
      end
    end
  end
end
