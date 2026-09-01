# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'FetchUtil extractor integration - Bitbucket Cloud pull resources' do
  include_context 'extractor integration helpers'

  def bitbucket_commits_fixture
    fixture_contents(File.expand_path('../fixtures/bitbucket_cloud_pull_commits.html', __dir__))
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
end
