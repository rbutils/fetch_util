# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'FetchUtil extractor integration - Bitbucket Cloud pull resources' do
  include_context 'extractor integration helpers'

  def bitbucket_commits_fixture
    fixture_contents(File.expand_path('../fixtures/bitbucket_cloud_pull_commits.html', __dir__))
  end

  def bitbucket_diff_fixture
    fixture_contents(File.expand_path('../fixtures/bitbucket_cloud_pull_diff.html', __dir__))
  end

  def wait_for_bitbucket_diff_preparation(page)
    100.times do
      state = page.evaluate('window.__fetchUtilBitbucketPullDiff')
      return state if state['status'] != 'loading'

      sleep 0.01
    end
    page.evaluate('window.__fetchUtilBitbucketPullDiff')
  end

  it 'preserves every loaded commit and exposes uncapped traversal inventory' do
    extract_from_url('https://code.example.test/workspace/project/pull-requests/42/commits',
                     bitbucket_commits_fixture, reader_mode: false) do |payload|
      markdown = payload.fetch('markdown')
      expect(payload).to include('contentType' => 'list', 'siteName' => 'Bitbucket')
      expect(markdown).to include(
        '[1111111](https://code.example.test/workspace/project/commits/1111111111111111111111111111111111111111)',
        'Alice', 'Restored visible commit context.', 'Builds',
        '[2222222](https://code.example.test/workspace/project/commits/2222222222222222222222222222222222222222)',
        'Bob', 'Second complete commit context.', 'Passed',
        '[Conversation](https://code.example.test/workspace/project/pull-requests/42)',
        '[Reports](https://code.example.test/workspace/project/pull-requests/42/reports)',
        'https://api.bitbucket.org/2.0/repositories/workspace/project/pullrequests/42/commits',
        "Follow the response's opaque next link until it is absent"
      )
      expect(markdown.scan('Restored visible commit context.').length).to eq(1)
      expect(markdown).not_to include(
        'Responsive duplicate', 'Hidden commit', 'Malformed commit link', 'Malformed commit label',
        'Page chrome commit'
      )
      expect(markdown.index('Restored visible commit context.')).to be < markdown.index('Second complete commit context.')
      expect(payload.fetch('html')).not_to include(
        'Responsive duplicate', 'Hidden commit', 'Malformed commit link', 'Malformed commit label',
        'Page chrome commit'
      )
    end
  end

  it 'preserves an uncapped commit inventory in DOM order' do
    rows = (1..25).map do |index|
      hash = index.to_s(16).rjust(40, '0')
      <<~HTML
        <tr data-qa="commit-row">
          <td><a aria-label="Commit: #{hash}" href="/workspace/project/commits/#{hash}">bulk-#{index}</a></td>
          <td>Uncapped commit context #{index}.</td>
        </tr>
      HTML
    end.join
    html = bitbucket_commits_fixture.sub('<!-- records-end -->', rows)

    extract_from_url('https://code.example.test/workspace/project/pull-requests/42/commits', html,
                     reader_mode: false) do |payload|
      markdown = payload.fetch('markdown')
      expect((1..25).all? { |index| markdown.include?("Uncapped commit context #{index}.") }).to be(true)
      expect(markdown.index('Uncapped commit context 1.')).to be < markdown.index('Uncapped commit context 25.')
    end
  end

  it 'rejects resource routes without matching public Bitbucket runtime evidence' do
    mismatched = bitbucket_commits_fixture.sub('full_name: "workspace/project"', 'full_name: "other/project"')
    private_repository = bitbucket_commits_fixture.sub('is_private: false', 'is_private: true')

    [mismatched, private_repository].each do |html|
      extract_from_url('https://code.example.test/workspace/project/pull-requests/42/commits', html,
                       reader_mode: false) do |payload|
        expect(payload.fetch('markdown')).not_to include('Browse this Bitbucket pull request')
      end
    end

    extract_from_url('https://code.example.test/workspace/project/pull-requests/42/overview',
                     bitbucket_commits_fixture, reader_mode: false) do |payload|
      expect(payload.fetch('contentType')).not_to eq('list')
    end
  end

  it 'executes Browser readiness against loaded, loading, hidden, and product-negative states' do
    browser = FetchUtil::Browser.new
    url = 'https://code.example.test/workspace/project/pull-requests/42/commits'

    with_url_page(url, bitbucket_commits_fixture) do |page|
      expect(page.evaluate(browser.send(:bitbucket_cloud_pull_resource_state_script)))
        .to include('product' => true, 'ready' => true, 'loading' => false)
    end

    loading = bitbucket_commits_fixture.sub('class="spinner" style="display: none"', 'class="spinner"')
    with_url_page(url, loading) do |page|
      expect(page.evaluate(browser.send(:bitbucket_cloud_pull_resource_state_script)))
        .to include('product' => true, 'ready' => false, 'loading' => true)
    end

    hidden = bitbucket_commits_fixture.sub('<table>', '<table style="display: none">')
    with_url_page(url, hidden) do |page|
      expect(page.evaluate(browser.send(:bitbucket_cloud_pull_resource_state_script)))
        .to include('product' => true, 'ready' => false, 'loading' => false)
    end

    mismatch = bitbucket_commits_fixture.sub('full_name: "workspace/project"', 'full_name: "other/project"')
    with_url_page(url, mismatch) do |page|
      expect(page.evaluate(browser.send(:bitbucket_cloud_pull_resource_state_script)))
        .to include('product' => false, 'ready' => false)
    end
  end

  it 'preserves every prepared changed file and exposes loaded diff content plus traversal' do
    extract_from_url('https://code.example.test/workspace/project/pull-requests/42/diff',
                     bitbucket_diff_fixture, reader_mode: false) do |payload|
      markdown = payload.fetch('markdown')
      expect(payload).to include('contentType' => 'list', 'siteName' => 'Bitbucket')
      expect(markdown).to include(
        'Changed files shown: 2', 'lib/new_name.rb', 'Old path: lib/old_name.rb',
        'Lines added: 8', 'Lines removed: 3', 'docs/new.md', 'loaded visible hunk',
        'https://code.example.test/workspace/project/src/new/lib/new_name.rb',
        '"type":"commit_file"', '"escaped_path":"lib%2Fnew_name.rb"',
        'https://code.example.test/workspace/project/commits/new',
        '[Raw diff](https://code.example.test/workspace/project/pull-requests/42.diff)'
      )
      expect(markdown).not_to include(
        'javascript:unsafeDiff()', 'javascript:unsafePaddedDiff()', 'hidden hunk', 'Diff menu'
      )
      expect(markdown.index('lib/new_name.rb')).to be < markdown.index('docs/new.md')
    end
  end

  it 'renders an explicit warning when trusted diffstat preparation fails' do
    failed = bitbucket_diff_fixture.sub('status: "ready"', 'status: "failed"')
    failed = failed.sub('reason: ""', 'reason: "opaque pagination repeated"')
    extract_from_url('https://code.example.test/workspace/project/pull-requests/42/diff', failed,
                     reader_mode: false) do |payload|
      expect(payload.fetch('warnings')).to include('bitbucket_cloud_diffstat_incomplete')
      expect(payload.fetch('markdown')).to include('opaque pagination repeated', 'Retrieval warning')
    end
  end

  it 'routes diff resources only with matching public Bitbucket evidence' do
    mismatch = bitbucket_diff_fixture.sub('full_name: "workspace/project"', 'full_name: "other/project"')
    extract_from_url('https://code.example.test/workspace/project/pull-requests/42/diff', mismatch,
                     reader_mode: false) do |payload|
      expect(payload.fetch('markdown')).not_to include('Changed files shown: 2')
    end
  end

  it 'prepares every opaque diffstat page with the real Browser state script' do
    browser = FetchUtil::Browser.new
    url = 'https://code.example.test/workspace/project/pull-requests/42/diff'
    with_url_page(url, bitbucket_diff_fixture) do |page|
      page.evaluate(<<~JS)
        (() => {
          const records = window.__fetchUtilBitbucketPullDiff.values;
          delete window.__fetchUtilBitbucketPullDiff;
          window.__bitbucketDiffRequests = [];
          window.__bitbucketDiffOptions = [];
          window.fetch = (value, options) => {
            const url = new URL(value, location.href);
            window.__bitbucketDiffRequests.push(url.href);
            window.__bitbucketDiffOptions.push(options);
            let payload;
            if (url.pathname.endsWith('/pullrequests/42')) {
              payload = {
                id: 42,
                destination: { repository: { full_name: 'workspace/project' } },
                links: { diffstat: { href: 'https://api.bitbucket.org/2.0/repositories/workspace/project/diffstat/workspace/project:abcdef?from_pullrequest_id=42' } }
              };
            } else if (url.searchParams.get('after') === 'opaque-next') {
              payload = { values: [records[1]] };
            } else {
              payload = {
                values: [records[0]],
                next: 'https://api.bitbucket.org/2.0/repositories/workspace/project/diffstat/workspace/project:abcdef?from_pullrequest_id=42&after=opaque-next'
              };
            }
            return Promise.resolve({
              ok: true,
              status: 200,
              url: url.href,
              json: () => Promise.resolve(payload)
            });
          };
        })()
      JS

      expect(page.evaluate(browser.send(:bitbucket_cloud_pull_resource_state_script)))
        .to include('product' => true, 'loading' => true)
      prepared = wait_for_bitbucket_diff_preparation(page)
      expect(prepared).to include('status' => 'ready')
      expect(prepared.fetch('values').length).to eq(2)
      expect(page.evaluate('window.__bitbucketDiffRequests.every((value) => new URL(value).origin === location.origin)'))
        .to be(true)
      expect(page.evaluate('window.__bitbucketDiffOptions.every((options) => options.redirect === "error")')).to be(true)
      expect(extract_payload(page, reader_mode: false).fetch('markdown')).to include('Changed files shown: 2')
    end
  end
end
