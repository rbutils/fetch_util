# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'FetchUtil extractor integration - Pagure pull requests' do
  include_context 'extractor integration helpers'

  def pagure_pull_fixture
    fixture_contents(File.expand_path('../fixtures/pagure_pull_request_thread.html', __dir__))
  end

  it 'preserves a host-agnostic Pagure pull request and truthful traversal inventory' do
    extract_from_url('https://forge.example.test/team/project/pull-request/7/', pagure_pull_fixture, reader_mode: false) do |payload|
      markdown = payload.fetch('markdown')
      expect(payload).to include('contentType' => 'social', 'socialKind' => 'thread', 'platform' => 'Pagure',
                                 'handle' => 'alice+bot', 'replyCount' => nil, 'community' => 'team/project',
                                 'publishedTime' => '2026-09-01T10:00:00Z')
      expect(markdown).to include('# Preserve pull request history', 'Opening Pagure pull request body.',
                                  'Restored opening detail.',
                                  '[Comment by bob](https://forge.example.test/team/project/pull-request/7#comment-701)',
                                  'Context: on line 12 of lib/example.rb',
                                  '### Event by alice', 'Pull-Request rebased by merger from @alice',
                                  '### Comment by eve', 'Idless Pagure pull request comment.',
                                  'Restored Pagure pull request comment.',
                                  '## Metadata', 'Merged', 'fidelity', '## Archive status', 'read-only snapshot',
                                  '[Patch](https://forge.example.test/team/project/pull-request/7/7.patch)',
                                  'https://forge.example.test/api/0/team/project/pull-request/7',
                                  'Static archives and some installations may not expose this route.')
      expect(markdown.scan('Repeated idless pull event.').length).to eq(2)
      expect(markdown.scan('First Pagure pull request comment.').length).to eq(1)
      expect(markdown).not_to include('Context: on line 12 of lib/example.rb today')
      expect(payload.fetch('excerpt')).not_to include('Hidden opening text')
      expect(markdown).not_to include('Hidden opening text', 'Hidden comment text', 'Hidden pull card must not render',
                                      'Hidden pull metadata', 'Duplicate pull permalink must not render', '.diff')
      expect(payload.fetch('html')).not_to include('<button', 'Hidden pull card must not render')
      expect(markdown.index('First Pagure pull request comment.')).to be < markdown.index('Pull-Request rebased')
      expect(markdown.index('Pull-Request rebased')).to be < markdown.index('Restored Pagure pull request comment.')
    end
  end

  it 'preserves an uncapped pull request timeline in DOM order' do
    records = (1..25).map do |index|
      <<~HTML
        <div class="card mb-4 clearfix"><div class="card-header" id="comment-#{800 + index}">
          <span class="font-weight-bold">user#{index}</span><a href="#comment-#{800 + index}"><time datetime="2026-09-02T10:#{index.to_s.rjust(2, "0")}:00Z">today</time></a>
        </div><div class="card-body"><section class="issue_comment"><div class="comment_text comment_body"><p>Uncapped Pagure pull comment #{index}.</p></div></section></div></div>
      HTML
    end.join
    html = pagure_pull_fixture.sub('<!-- bulk-comments -->', records)

    extract_from_url('https://forge.example.test/team/project/pull-request/7/', html, reader_mode: false) do |payload|
      found = payload.fetch('markdown').scan(/Uncapped Pagure pull comment (\d+)\./).flatten.map(&:to_i)
      expect(found).to eq((1..25).to_a)
    end
  end

  it 'supports nested project paths without hostname ownership' do
    html = pagure_pull_fixture.gsub('/team/project', '/fork/alice/team/project')
    extract_from_url('https://code.example.test/fork/alice/team/project/pull-request/7/', html, reader_mode: false) do |payload|
      expect(payload).to include('platform' => 'Pagure', 'community' => 'fork/alice/team/project')
      expect(payload.fetch('markdown')).to include('https://code.example.test/fork/alice/team/project/pull-requests')
    end
  end

  it 'supports prefixed installations and keeps the prefix out of project identity' do
    html = pagure_pull_fixture
           .gsub('src="/static/', 'src="/pagure/static/')
           .gsub('href="/team/project', 'href="/pagure/team/project')

    extract_from_url('https://code.example.test/pagure/team/project/pull-request/7/', html, reader_mode: false) do |payload|
      expect(payload).to include('platform' => 'Pagure', 'community' => 'team/project')
      expect(payload.fetch('markdown')).to include('https://code.example.test/pagure/api/0/team/project/pull-request/7',
                                                   'https://code.example.test/pagure/team/project/pull-requests')
    end
  end

  it 'keeps valid pull requests when the optional opening body is empty' do
    html = pagure_pull_fixture
           .sub(' id="comment-0"', '')
           .sub(%r{<section class="issue_comment"><div class="comment_body">.*?</div></section>}, '')

    extract_from_url('https://forge.example.test/team/project/pull-request/7/', html, reader_mode: false) do |payload|
      expect(payload).to include('platform' => 'Pagure', 'handle' => 'alice+bot')
      expect(payload.fetch('markdown')).to include('First Pagure pull request comment.')
      expect(payload.fetch('markdown')).to include('[Opening](https://forge.example.test/team/project/pull-request/7)')
      expect(payload.fetch('markdown')).not_to include('#comment-0')
    end
  end

  it 'scopes opening attribution to the status details instead of title prose' do
    html = pagure_pull_fixture.sub('Preserve pull request history', 'Opened regression by bot')

    extract_from_url('https://forge.example.test/team/project/pull-request/7/', html, reader_mode: false) do |payload|
      expect(payload).to include('platform' => 'Pagure', 'handle' => 'alice+bot')
      expect(payload.fetch('markdown')).to include('- Author: alice+bot')
      expect(payload.fetch('markdown')).not_to include('- Author: bot')
    end
  end

  it 'requires independent Pagure product evidence and a matching pull request heading' do
    without_assets = pagure_pull_fixture.gsub(%r{\s*<script src="/static/pagure-[^"]+"></script>}, '')
    off_origin_navigation = pagure_pull_fixture.gsub('href="/team/project', 'href="https://lookalike.invalid/team/project')
    wrong_heading = pagure_pull_fixture.sub('#7</span>', '#8</span>')
    without_comments = pagure_pull_fixture.sub('class="request_comment"', 'class="request-comment-lookalike"')
    { without_assets: without_assets, off_origin_navigation: off_origin_navigation,
      wrong_heading: wrong_heading, without_comments: without_comments }.each do |name, html|
      aggregate_failures(name) do
        extract_from_url('https://forge.example.test/team/project/pull-request/7/', html, reader_mode: false) do |payload|
          expect(payload['platform']).not_to eq('Pagure')
        end
      end
    end
  end

  it 'keeps issue, repository, and malformed routes outside pull request extraction' do
    ['https://forge.example.test/team/project',
     'https://forge.example.test/team/project/issue/7',
     'https://forge.example.test/team/project/pull-request/not-a-number',
     'https://forge.example.test/team//project/pull-request/7',
     'https://forge.example.test//team/project/pull-request/7'].each do |url|
      extract_from_url(url, pagure_pull_fixture, reader_mode: false) do |payload|
        expect(payload['platform']).not_to eq('Pagure')
      end
    end
  end
end
