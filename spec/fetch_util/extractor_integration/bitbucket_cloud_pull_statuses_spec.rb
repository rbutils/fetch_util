# frozen_string_literal: true

require 'json'
require 'spec_helper'

RSpec.describe 'FetchUtil extractor integration - Bitbucket Cloud pull statuses' do
  include_context 'extractor integration helpers'

  def bitbucket_statuses_fixture
    fixture_contents(File.expand_path('../fixtures/bitbucket_cloud_pull_statuses.json', __dir__))
  end

  def extract_bitbucket_statuses(json = bitbucket_statuses_fixture,
                                 url: 'https://api.code.example.test/2.0/repositories/workspace/project/pullrequests/42/statuses')
    with_url_page(url, json, content_type: 'application/json; charset=UTF-8') do |page|
      yield extract_payload(page, reader_mode: false)
    end
  end

  it 'preserves complete statuses in API order and exposes opaque traversal' do
    extract_bitbucket_statuses do |payload|
      markdown = payload.fetch('markdown')
      expect(payload).to include('contentType' => 'list', 'siteName' => 'Bitbucket', 'language' => nil)
      expect(markdown).to include(
        'Statuses shown on this API page: 2', 'Primary pipeline', 'State: FAILED',
        'Secondary pipeline', 'State: SUCCESSFUL', 'Result: failed after the complete test run',
        'Protocol: preserve this prose', 'https://details.example.test/build/42',
        '[Next statuses API page](https://api.code.example.test/2.0/repositories/workspace/project/pullrequests/42/statuses?after=opaque%2Bcursor)',
        '[Build result for Primary pipeline](https://ci.example.test/results/42)'
      )
      expect(markdown).not_to include('javascript:unsafeStatus()', 'ftp://unsafe.example.test', 'file:///private')
      expect(markdown.index('Primary pipeline')).to be < markdown.index('Secondary pipeline')
      expect(markdown.scan('Key: build-42').length).to eq(2)
      expect(payload.fetch('html')).not_to include('javascript:unsafeStatus()')
      expect(payload.fetch('warnings')).not_to include('bitbucket_cloud_statuses_incomplete')
    end
  end

  it 'preserves an uncapped page including duplicate records' do
    payload = JSON.parse(bitbucket_statuses_fixture)
    template = payload.fetch('values').first
    payload['values'] = (1..25).map do |index|
      template.merge(
        'name' => "Uncapped status #{index}",
        'description' => "Uncapped status context #{index}",
        'links' => template.fetch('links').merge(
          'self' => { 'href' => "https://api.code.example.test/2.0/repositories/workspace/project/commit/#{template.dig("commit", "hash")}/statuses/build/uncapped-#{index}" }
        )
      )
    end
    payload['size'] = 25
    payload.delete('next')

    extract_bitbucket_statuses(JSON.generate(payload)) do |result|
      markdown = result.fetch('markdown')
      expect((1..25).all? { |index| markdown.include?("Uncapped status context #{index}") }).to be(true)
      expect(markdown.index('Uncapped status context 1')).to be < markdown.index('Uncapped status context 25')
    end
  end

  it 'rejects an empty API page without record-level product evidence' do
    payload = JSON.parse(bitbucket_statuses_fixture).merge('values' => [], 'size' => 0)
    payload.delete('next')

    extract_bitbucket_statuses(JSON.generate(payload)) do |result|
      expect(result).not_to include('siteName' => 'Bitbucket')
    end
  end

  it 'keeps current statuses while warning about an unsafe continuation' do
    payload = JSON.parse(bitbucket_statuses_fixture)
    payload['next'] = 'https://other.example.test/2.0/repositories/workspace/project/pullrequests/42/statuses?after=unsafe'

    extract_bitbucket_statuses(JSON.generate(payload)) do |result|
      expect(result.fetch('markdown')).to include('Primary pipeline', 'pagination continuation was present')
      expect(result.fetch('markdown')).not_to include('other.example.test')
      expect(result.fetch('warnings')).to include('bitbucket_cloud_statuses_incomplete')
    end
  end

  it 'rejects ordinary HTML and payloads with mismatched identity or invalid records' do
    url = 'https://api.code.example.test/2.0/repositories/workspace/project/pullrequests/42/statuses'
    with_url_page(url, bitbucket_statuses_fixture) do |page|
      expect(extract_payload(page, reader_mode: false)).not_to include('siteName' => 'Bitbucket')
    end

    base = JSON.parse(bitbucket_statuses_fixture)
    payloads = []
    payloads << JSON.parse(bitbucket_statuses_fixture.sub('"full_name": "workspace/project"', '"full_name": "other/project"'))
    payloads << JSON.parse(bitbucket_statuses_fixture.sub('"hash": "1111111111111111111111111111111111111111"', '"hash": "short"'))
    payloads << base.merge('size' => 1)
    payloads << base.merge('size' => 25).tap { |payload| payload.delete('next') }
    payloads << JSON.parse(bitbucket_statuses_fixture).tap { |payload| payload['values'][0]['commit']['hash'] = ['1' * 40] }
    payloads << JSON.parse(bitbucket_statuses_fixture).tap { |payload| payload['values'][0]['key'] = { 'value' => 'build-42' } }
    payloads << JSON.parse(bitbucket_statuses_fixture).tap do |payload|
      payload['values'][0]['links']['self']['href'] =
        'https://api.code.example.test/2.0/repositories/workspace/project/commit/' \
        "#{'1' * 40}/statuses/build/other-status"
    end

    payloads.each do |payload|
      extract_bitbucket_statuses(JSON.generate(payload)) do |result|
        expect(result).not_to include('siteName' => 'Bitbucket')
      end
    end
  end

  it 'keeps status prose from becoming a credential-bearing Markdown link' do
    payload = JSON.parse(bitbucket_statuses_fixture)
    payload['values'][0]['name'] = '[Credential leak](https://user:password@unsafe.example.test/)'

    extract_bitbucket_statuses(JSON.generate(payload)) do |result|
      markdown = result.fetch('markdown')
      expect(markdown).not_to include('[Credential leak](https://user:password@unsafe.example.test/)')
      expect(markdown).to include('Credential leak')
    end
  end

  it 'rejects malformed and identity-changing API routes' do
    urls = [
      'https://api.code.example.test/2.0/repositories/workspace/project/pullrequests/not-a-number/statuses',
      'https://api.code.example.test/2.0/repositories/workspace%2Fother/project/pullrequests/42/statuses',
      'https://api.code.example.test/2.0/repositories/workspace/project/pullrequests/42/statuses/extra'
    ]
    urls.each do |url|
      extract_bitbucket_statuses(bitbucket_statuses_fixture, url: url) do |result|
        expect(result).not_to include('siteName' => 'Bitbucket')
      end
    end

    proxy_payload = JSON.parse(bitbucket_statuses_fixture)
    proxy_payload['next'] =
      'https://api.code.example.test/!api/2.0/repositories/workspace/project/pullrequests/42/statuses?after=other-surface'
    extract_bitbucket_statuses(JSON.generate(proxy_payload)) do |result|
      expect(result.fetch('warnings')).to include('bitbucket_cloud_statuses_incomplete')
      expect(result.fetch('markdown')).not_to include('other-surface')
    end
  end
end
