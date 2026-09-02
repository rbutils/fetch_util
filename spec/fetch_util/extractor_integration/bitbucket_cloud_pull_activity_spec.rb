# frozen_string_literal: true

require 'json'
require 'spec_helper'

RSpec.describe 'FetchUtil extractor integration - Bitbucket Cloud pull activity' do
  include_context 'extractor integration helpers'

  def bitbucket_activity_fixture
    fixture_contents(File.expand_path('../fixtures/bitbucket_cloud_pull_activity.json', __dir__))
  end

  def extract_bitbucket_activity(json = bitbucket_activity_fixture,
                                 url: 'https://api.code.example.test/2.0/repositories/workspace/project/pullrequests/42/activity')
    with_url_page(url, json, content_type: 'application/json; charset=UTF-8') do |page|
      yield extract_payload(page, reader_mode: false)
    end
  end

  it 'preserves every activity record in API order and exposes opaque traversal' do
    extract_bitbucket_activity do |payload|
      markdown = payload.fetch('markdown')
      expect(payload).to include('contentType' => 'list', 'siteName' => 'Bitbucket', 'language' => nil)
      expect(markdown).to include(
        'Activity records shown on this API page: 3', 'Activity 1: Approval', 'Actor: Approving User',
        'Activity 2: Update', 'Protocol: preserve this update prose', 'Activity 3: Comment',
        'Complete review comment',
        '[Next activity API page](https://api.code.example.test/2.0/repositories/workspace/project/pullrequests/42/activity?ctx=opaque%2Bcursor)',
        '[Activity record 3](https://api.code.example.test/2.0/repositories/workspace/project/pullrequests/42/comments/99)'
      )
      expect(markdown.index('Activity 1: Approval')).to be < markdown.index('Activity 2: Update')
      expect(markdown.index('Activity 2: Update')).to be < markdown.index('Activity 3: Comment')
      expect(markdown).to include('https://public.example.test/activity/42')
      expect(markdown).not_to include(
        'javascript:unsafeAvatar()', 'ftp://unsafe.example.test', 'file:///private',
        'user:password@unsafe.example.test'
      )
      expect(payload.fetch('warnings')).not_to include('bitbucket_cloud_activity_incomplete')
    end
  end

  it 'preserves additional and unknown event variants without event-type caps' do
    payload = JSON.parse(bitbucket_activity_fixture)
    template = payload.fetch('values').first
    pull_request = template.fetch('pull_request')
    payload['values'] = [
      {
        'pull_request' => pull_request,
        'changes_requested' => {
          'date' => '2026-08-02T10:00:00+00:00',
          'user' => { 'display_name' => 'Requesting User' },
          'pullrequest' => pull_request
        }
      },
      {
        'pull_request' => pull_request,
        'attachment' => {
          'date' => '2026-08-02T10:01:00+00:00',
          'actor' => { 'display_name' => 'Attaching User' },
          'name' => 'review.log'
        }
      },
      {
        'pull_request' => pull_request,
        'task' => {
          'created_on' => '2026-08-02T10:02:00+00:00',
          'creator' => { 'display_name' => 'Task Creator' },
          'content' => { 'raw' => 'Resolve this task' }
        }
      },
      {
        'pull_request' => pull_request,
        'future_event' => {
          'updated_on' => '2026-08-02T10:03:00+00:00',
          'actor' => { 'display_name' => 'Future Actor' },
          'detail' => 'Preserve future event data'
        }
      }
    ]
    payload.delete('next')

    extract_bitbucket_activity(JSON.generate(payload)) do |result|
      markdown = result.fetch('markdown')
      expect(markdown).to include(
        'Activity 1: Changes Requested', 'Requesting User',
        'Activity 2: Attachment', 'Attaching User', 'review.log',
        'Activity 3: Task', 'Task Creator', 'Resolve this task',
        'Activity 4: Future Event', 'Future Actor', 'Preserve future event data'
      )
      expect(markdown.index('Changes Requested')).to be < markdown.index('Attachment')
      expect(markdown.index('Attachment')).to be < markdown.index('Task')
      expect(markdown.index('Task')).to be < markdown.index('Future Event')
    end
  end

  it 'preserves an uncapped page including duplicate idless events' do
    payload = JSON.parse(bitbucket_activity_fixture)
    template = payload.fetch('values')[1]
    payload['values'] = (1..25).map do |index|
      Marshal.load(Marshal.dump(template)).tap do |record|
        record.fetch('update')['title'] = "Uncapped update #{index}"
      end
    end
    payload.delete('next')

    extract_bitbucket_activity(JSON.generate(payload)) do |result|
      markdown = result.fetch('markdown')
      expect((1..25).all? { |index| markdown.include?("Uncapped update #{index}") }).to be(true)
      expect(markdown.index('Uncapped update 1')).to be < markdown.index('Uncapped update 25')
    end
  end

  it 'keeps current records while warning about unsafe or missing traversal' do
    unsafe = JSON.parse(bitbucket_activity_fixture)
    unsafe['next'] = 'https://other.example.test/2.0/repositories/workspace/project/pullrequests/42/activity?ctx=unsafe'
    extract_bitbucket_activity(JSON.generate(unsafe)) do |result|
      expect(result.fetch('markdown')).to include('Approving User', 'pagination continuation was present')
      expect(result.fetch('markdown')).not_to include('other.example.test')
      expect(result.fetch('warnings')).to include('bitbucket_cloud_activity_incomplete')
    end

    incomplete = JSON.parse(bitbucket_activity_fixture).merge('page' => 1, 'size' => 40)
    incomplete.delete('next')
    extract_bitbucket_activity(JSON.generate(incomplete)) do |result|
      expect(result.fetch('warnings')).to include('bitbucket_cloud_activity_incomplete')
      expect(result.fetch('markdown')).to include('API counters indicate omitted activity records')
    end
  end

  it 'accepts safe previous links and exact terminal counters' do
    payload = JSON.parse(bitbucket_activity_fixture).merge('page' => 2, 'size' => 6, 'pagelen' => 3)
    payload['previous'] =
      'https://api.code.example.test/2.0/repositories/workspace/project/pullrequests/42/activity?ctx=previous'
    payload.delete('next')

    extract_bitbucket_activity(JSON.generate(payload)) do |result|
      expect(result.fetch('markdown')).to include(
        '[Previous activity API page](https://api.code.example.test/2.0/repositories/workspace/project/pullrequests/42/activity?ctx=previous)'
      )
      expect(result.fetch('warnings')).not_to include('bitbucket_cloud_activity_incomplete')
    end
  end

  it 'accepts direct and same-origin proxy routes without requiring counters' do
    extract_bitbucket_activity(
      bitbucket_activity_fixture,
      url: 'https://code.example.test/!api/2.0/repositories/workspace/project/pullrequests/42/activity'
    ) do |result|
      expect(result).to include('siteName' => 'Bitbucket', 'language' => nil)
      expect(result.fetch('markdown')).to include(
        'https://code.example.test/!api/2.0/repositories/workspace/project/pullrequests/42/activity?ctx=opaque%2Bcursor'
      )
    end
  end

  it 'rejects ordinary HTML and malformed records or identity' do
    url = 'https://api.code.example.test/2.0/repositories/workspace/project/pullrequests/42/activity'
    with_url_page(url, bitbucket_activity_fixture) do |page|
      expect(extract_payload(page, reader_mode: false)).not_to include('siteName' => 'Bitbucket')
    end

    payloads = []
    payloads << JSON.parse(bitbucket_activity_fixture).tap { |payload| payload['values'][0]['pull_request']['id'] = 43 }
    payloads << JSON.parse(bitbucket_activity_fixture).tap do |payload|
      payload['values'][0]['pull_request']['links']['self']['href'] =
        'https://api.code.example.test/2.0/repositories/other/project/pullrequests/42'
    end
    payloads << JSON.parse(bitbucket_activity_fixture).tap { |payload| payload['values'][0]['approval'] = [] }
    payloads << JSON.parse(bitbucket_activity_fixture).tap { |payload| payload['values'][2]['comment']['id'] = '99' }
    payloads << JSON.parse(bitbucket_activity_fixture).tap { |payload| payload['values'][1]['extra_event'] = {} }
    payloads << JSON.parse(bitbucket_activity_fixture).merge('values' => [])
    payloads << JSON.parse(bitbucket_activity_fixture).merge('pagelen' => 2)
    payloads << JSON.parse(bitbucket_activity_fixture).merge('page' => 2, 'size' => 3)
    payloads.each do |payload|
      extract_bitbucket_activity(JSON.generate(payload)) do |result|
        expect(result).not_to include('siteName' => 'Bitbucket')
      end
    end
  end

  it 'removes credential-bearing and unsafe selected activity fields' do
    payload = JSON.parse(bitbucket_activity_fixture)
    update = payload.fetch('values')[1].fetch('update')
    update['title'] = 'https://user:password@unsafe.example.test/title'
    update['state'] = 'javascript:unsafeState()'
    update['author']['display_name'] = '//user:password@unsafe.example.test/actor'
    update['description'] = '[Credential](https://user:password@unsafe.example.test/details)'

    extract_bitbucket_activity(JSON.generate(payload)) do |result|
      expect(result.fetch('markdown')).not_to include(
        'user:password@unsafe.example.test', 'javascript:unsafeState()', '[Credential]'
      )
    end
  end

  it 'preserves colon-delimited prose while rejecting embedded unsafe URI tokens' do
    payload = JSON.parse(bitbucket_activity_fixture)
    payload.fetch('values')[0].fetch('approval')['state'] = 'CI:nightly'
    payload.fetch('values')[1].fetch('update')['title'] = 'Review //user:secret@evil.example/path'
    payload.fetch('values')[2].fetch('comment')['content'] = { 'raw' => 'Actor ftp://evil.example/path' }

    extract_bitbucket_activity(JSON.generate(payload)) do |result|
      markdown = result.fetch('markdown')
      expect(markdown).to include('CI:nightly')
      expect(markdown).not_to include('user:secret', 'ftp://evil.example')
    end
  end

  it 'normalizes terminal slashes across accepted activity API links' do
    payload = JSON.parse(bitbucket_activity_fixture)
    payload.fetch('values').each do |record|
      record.fetch('pull_request').fetch('links').fetch('self')['href'] += '/'
    end
    payload['next'] =
      'https://api.code.example.test/2.0/repositories/workspace/project/pullrequests/42/activity/?ctx=opaque'

    url = 'https://api.code.example.test/2.0/repositories/workspace/project/pullrequests/42/activity/'
    extract_bitbucket_activity(JSON.generate(payload), url: url) do |result|
      expect(result.fetch('markdown')).to include('activity/?ctx=opaque')
      expect(result.fetch('warnings')).to be_empty
    end
  end

  it 'rejects malformed and identity-changing routes or prefix changes' do
    urls = [
      'https://api.code.example.test/2.0/repositories/workspace/project/pullrequests/not-a-number/activity',
      'https://api.code.example.test/2.0/repositories/workspace%2Fother/project/pullrequests/42/activity',
      'https://api.code.example.test/2.0/repositories/workspace/project/pullrequests/42/activity/extra'
    ]
    urls.each do |url|
      extract_bitbucket_activity(bitbucket_activity_fixture, url: url) do |result|
        expect(result).not_to include('siteName' => 'Bitbucket')
      end
    end

    payload = JSON.parse(bitbucket_activity_fixture)
    payload['next'] =
      'https://api.code.example.test/!api/2.0/repositories/workspace/project/pullrequests/42/activity?ctx=other-prefix'
    extract_bitbucket_activity(JSON.generate(payload)) do |result|
      expect(result.fetch('warnings')).to include('bitbucket_cloud_activity_incomplete')
      expect(result.fetch('markdown')).not_to include('other-prefix')
    end
  end

  it 'escapes repository labels decoded from API route segments' do
    encoded = '%5Brepositories%5D(javascript%3Aunsafe)'
    json = bitbucket_activity_fixture.gsub('workspace/project', "#{encoded}/project")
    url = "https://api.code.example.test/2.0/repositories/#{encoded}/project/pullrequests/42/activity"

    extract_bitbucket_activity(json, url: url) do |result|
      markdown = result.fetch('markdown')
      expect(markdown).to include('Repository: \[repositories\]', 'unsafe URL removed')
      expect(markdown).not_to include('javascript:unsafe')
    end
  end
end
