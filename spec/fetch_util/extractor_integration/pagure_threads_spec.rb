# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'FetchUtil extractor integration - Pagure threads' do
  include_context 'extractor integration helpers'

  def pagure_fixture
    fixture_contents(File.expand_path('../fixtures/pagure_issue_thread.html', __dir__))
  end

  it 'preserves a host-agnostic Pagure issue conversation and traversal inventory' do
    extract_from_url('https://forge.example.test/team/project/issue/42', pagure_fixture, reader_mode: false) do |payload|
      markdown = payload.fetch('markdown')
      expect(payload).to include('contentType' => 'social', 'socialKind' => 'thread', 'platform' => 'Pagure',
                                 'handle' => 'alice', 'replyCount' => nil, 'community' => 'team/project',
                                 'publishedTime' => '2026-09-01T10:00:00Z')
      expect(markdown).to include('# Preserve issue history', 'Opening Pagure issue body.', 'Restored opening detail.',
                                  '[Comment by bob](https://forge.example.test/team/project/issue/42#comment-101)',
                                  'Metadata Update from @alice', 'Restored Pagure comment.', '## Metadata', 'Assignee',
                                  'fidelity', '## Archive status', 'read-only snapshot',
                                  '[Issues](https://forge.example.test/team/project/issues)',
                                  '[Pull requests](https://forge.example.test/team/project/pull-requests)',
                                  'https://forge.example.test/api/0/team/project/issue/42?comments=true',
                                  'Static archives and some installations may not expose this route.')
      expect(markdown.scan('Repeated idless event.').length).to eq(2)
      expect(markdown.scan('First Pagure comment.').length).to eq(1)
      expect(markdown).to include('Direct-root Pagure event.', 'Card-root permalink comment.')
      expect(markdown.scan('Card-root permalink comment.').length).to eq(1)
      expect(payload.fetch('excerpt')).to include('Opening Pagure issue body.', 'Restored opening detail.')
      expect(payload.fetch('excerpt')).not_to include('Hidden opening text')
      expect(markdown).not_to include('Hidden opening text', 'Hidden comment text', 'Hidden card must not render',
                                      'Hidden metadata must not render', 'Duplicate permalink must not render',
                                      'Duplicate card-root permalink must not render', 'React')
      expect(payload.fetch('html')).not_to include('<button', 'Hidden card must not render')
      expect(markdown.index('First Pagure comment.')).to be < markdown.index('Metadata Update from @alice')
      expect(markdown.index('Metadata Update from @alice')).to be < markdown.index('Restored Pagure comment.')
    end
  end

  it 'preserves an uncapped Pagure timeline in DOM order' do
    records = (1..25).map do |index|
      <<~HTML
        <div class="card mb-4 clearfix"><div class="card-header" id="comment-#{200 + index}">
          <span class="font-weight-bold">user#{index}</span><a href="#comment-#{200 + index}"><time datetime="2026-09-02T10:#{index.to_s.rjust(2, "0")}:00Z">today</time></a>
        </div><section class="issue_comment"><div class="comment_text comment_body"><p>Uncapped Pagure comment #{index}.</p></div></section></div>
      HTML
    end.join
    html = pagure_fixture.sub('<!-- bulk-comments -->', records)

    extract_from_url('https://forge.example.test/team/project/issue/42', html, reader_mode: false) do |payload|
      markdown = payload.fetch('markdown')
      records = markdown.scan(/Uncapped Pagure comment (\d+)\./).flatten.map(&:to_i)
      expect(records).to eq((1..25).to_a)
    end
  end

  it 'supports nested project paths without hostname ownership' do
    html = pagure_fixture.gsub('/team/project', '/fork/alice/team/project')
    extract_from_url('https://code.example.test/fork/alice/team/project/issue/42', html, reader_mode: false) do |payload|
      expect(payload).to include('platform' => 'Pagure', 'community' => 'fork/alice/team/project')
      expect(payload.fetch('markdown')).to include('https://code.example.test/fork/alice/team/project/issues')
    end
  end

  it 'does not fabricate an opening time when the issue omits one' do
    html = pagure_fixture.gsub(%r{<time datetime="[^"]+">[^<]+</time>}, 'today')

    extract_from_url('https://forge.example.test/team/project/issue/42', html, reader_mode: false) do |payload|
      expect(payload).to include('platform' => 'Pagure', 'publishedTime' => nil)
    end
  end

  it 'accepts standard upstream assets when pull requests are disabled' do
    html = pagure_fixture
           .sub('/static/pagure-common.js', '/static/comments.js')
           .sub('/static/pagure-relative-dates.js', '/static/reactions.js')
           .sub('<a href="/team/project/pull-requests">Pull Requests</a>', '')

    extract_from_url('https://forge.example.test/team/project/issue/42', html, reader_mode: false) do |payload|
      expect(payload).to include('platform' => 'Pagure')
      expect(payload.fetch('markdown')).not_to include('[Pull requests]')
    end
  end

  it 'requires independent Pagure product evidence and a matching issue heading' do
    without_assets = pagure_fixture.gsub(%r{\s*<script src="/static/pagure-[^"]+"></script>}, '')
    off_origin_assets = pagure_fixture.gsub('src="/static/', 'src="https://lookalike.invalid/static/')
    off_origin_navigation = pagure_fixture.gsub('href="/team/project', 'href="https://lookalike.invalid/team/project')
    wrong_heading = pagure_fixture.sub('#42 Preserve issue history', '#43 Preserve issue history')
    {
      without_assets: without_assets,
      off_origin_assets: off_origin_assets,
      off_origin_navigation: off_origin_navigation,
      wrong_heading: wrong_heading
    }.each do |name, html|
      aggregate_failures(name) do
        extract_from_url('https://forge.example.test/team/project/issue/42', html, reader_mode: false) do |payload|
          expect(payload['platform']).not_to eq('Pagure')
        end
      end
    end
  end

  it 'keeps repository, pull-request, and malformed routes outside Pagure issue extraction' do
    ['https://forge.example.test/team/project',
     'https://forge.example.test/team/project/pull-request/7',
     'https://forge.example.test/team/project/issue/not-a-number'].each do |url|
      extract_from_url(url, pagure_fixture, reader_mode: false) do |payload|
        expect(payload['platform']).not_to eq('Pagure')
      end
    end
  end
end
