# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'FetchUtil extractor integration - SourceHut lists archive threads' do
  include_context 'extractor integration helpers'

  def sourcehut_thread_fixture
    fixture_contents(File.expand_path('../fixtures/sourcehut_lists_thread.html', __dir__))
  end

  it 'preserves the complete archive conversation and traversal inventory' do
    extract_from_url('https://lists.example.test/~alice/project-list/thread/root', sourcehut_thread_fixture,
                     reader_mode: false) do |payload|
      markdown = payload.fetch('markdown')
      expect(payload).to include('contentType' => 'social', 'socialKind' => 'thread', 'platform' => 'SourceHut',
                                 'handle' => 'Alice', 'replyCount' => 5, 'community' => '~alice/project-list',
                                 'publishedTime' => '2025-02-03 04:05 UTC')
      expect(markdown).to include(
        '# PATCH: Preserve archive fidelity', '## Opening message', 'Opening archive message.',
        'Restored opening detail.', 'Message ID', 'DKIM signature', 'Patch: +12 -3',
        '[Reply by Bob](https://lists.example.test/~alice/project-list/thread/root#reply-1)',
        'First archive reply.', 'Re: Different archive subject', 'Second archive reply.',
        'In-Reply-To: thread/root', 'Restored archive reply.',
        'Reply by mailbox-only@example.test',
        '[Full thread mbox](https://lists.example.test/~alice/project-list/thread/root/mbox)',
        '[Raw opening message](https://lists.example.test/~alice/project-list/thread/root/raw)',
        '[Raw reply 1](https://lists.example.test/~alice/project-list/reply-1/raw)',
        '[Review patch](https://lists.example.test/~alice/project-list/patches/42)',
        '[Source repository](https://git.example.test/~alice/project)'
      )
      expect(markdown.scan('Repeated idless archive reply.').length).to eq(2)
      expect(markdown.scan('First archive reply.').length).to eq(1)
      expect(markdown).not_to include('Hidden archive reply', 'Hidden opening text',
                                      'Duplicate stable reply must not render')
      expect(markdown.index('Opening archive message.')).to be < markdown.index('First archive reply.')
      expect(markdown.index('First archive reply.')).to be < markdown.index('Second archive reply.')
      expect(payload.fetch('html')).not_to include('Hidden archive reply', '<style')
    end
  end

  it 'keeps optional patch traversal optional' do
    html = sourcehut_thread_fixture.sub(%r{\s*<div class="alert alert-info">.*?</div>}, '')

    extract_from_url('https://lists.example.test/~alice/project-list/thread/root', html, reader_mode: false) do |payload|
      expect(payload).to include('platform' => 'SourceHut', 'replyCount' => 5)
      expect(payload.fetch('markdown')).not_to include('Review patch')
    end
  end

  it 'preserves encoded opaque message ids and literal plus signs' do
    html = sourcehut_thread_fixture
           .gsub('/thread/root/', '/topic%2Fwith+plus/')
           .sub('id="thread/root" href="#thread/root"',
                'id="topic/with+plus" href="#topic%2Fwith%2Bplus"')
           .sub('<code>thread/root</code>', '<code>topic/with+plus</code>')

    extract_from_url('https://lists.example.test/~alice/project-list/topic%2Fwith+plus', html,
                     reader_mode: false) do |payload|
      expect(payload).to include('platform' => 'SourceHut', 'handle' => 'Alice')
      expect(payload.fetch('markdown')).to include(
        'topic/with+plus',
        'https://lists.example.test/~alice/project-list/topic%2Fwith+plus/raw'
      )
    end
  end

  it 'retains header and raw metadata for an empty-body message' do
    message = <<~HTML
      <div><div class="message-header"><div class="from">Metadata Only</div><details><summary>Details</summary><a href="/~alice/project-list/metadata-only/raw">Download raw message</a></details><div class="date"><a id="metadata-only" href="#metadata-only">2025-03-30 UTC</a></div></div><pre class="message-body"></pre></div>
    HTML
    html = sourcehut_thread_fixture.sub('<!-- bulk-messages -->', message)

    extract_from_url('https://lists.example.test/~alice/project-list/thread/root', html, reader_mode: false) do |payload|
      expect(payload).to include('replyCount' => 6)
      expect(payload.fetch('markdown')).to include(
        '[Reply by Metadata Only](https://lists.example.test/~alice/project-list/thread/root#metadata-only)',
        '[Raw reply 6](https://lists.example.test/~alice/project-list/metadata-only/raw)'
      )
    end
  end

  it 'preserves an uncapped archive thread in source order' do
    messages = (1..25).map do |index|
      <<~HTML
        <div><div class="message-header"><div class="from">Bulk #{index}</div><details><summary>Details</summary><a href="/~alice/project-list/bulk-#{index}/raw">Download raw message</a></details><div class="date"><a id="bulk-#{index}" href="#bulk-#{index}">2025-03-#{format("%02d", index)} UTC</a></div></div><pre class="message-body">Uncapped archive reply #{index}.</pre></div>
      HTML
    end.join
    html = sourcehut_thread_fixture.sub('<!-- bulk-messages -->', messages)

    extract_from_url('https://lists.example.test/~alice/project-list/thread/root', html, reader_mode: false) do |payload|
      found = payload.fetch('markdown').scan(/Uncapped archive reply (\d+)\./).flatten.map(&:to_i)
      expect(found).to eq((1..25).to_a)
      expect(payload.fetch('replyCount')).to eq(30)
    end
  end

  it 'requires independent SourceHut lists archive evidence' do
    variants = {
      without_asset: sourcehut_thread_fixture.gsub(%r{\s*<link rel="stylesheet" href="/static/lists\.sr\.ht/[^"]+">}, ''),
      off_origin_asset: sourcehut_thread_fixture.sub('href="/static/', 'href="https://lookalike.invalid/static/'),
      off_origin_navigation: sourcehut_thread_fixture.gsub(
        'href="/~alice/project-list', 'href="https://lookalike.invalid/~alice/project-list'
      ),
      without_alternate_mbox: sourcehut_thread_fixture.sub('type="application/mbox"', 'type="text/plain"'),
      wrong_opening_identity: sourcehut_thread_fixture.sub('id="thread/root"', 'id="other/root"'),
      without_opening_raw: sourcehut_thread_fixture.sub('/thread/root/raw', '/thread/root/download')
    }

    variants.each do |name, html|
      aggregate_failures(name) do
        extract_from_url('https://lists.example.test/~alice/project-list/thread/root', html, reader_mode: false) do |payload|
          expect(payload['platform']).not_to eq('SourceHut')
        end
      end
    end
  end

  it 'keeps reserved and terminal resource routes outside archive extraction' do
    [
      'https://lists.example.test/~alice/project-list',
      'https://lists.example.test/~alice/project-list/patches/42',
      'https://lists.example.test/~alice/project-list/thread/root/raw',
      'https://lists.example.test/~alice/project-list/thread/root/mbox',
      'https://lists.example.test/alice/project-list/thread/root',
      'https://lists.example.test/~alice/.git/thread/root',
      'https://lists.example.test//~alice/project-list/thread/root'
    ].each do |url|
      extract_from_url(url, sourcehut_thread_fixture, reader_mode: false) do |payload|
        expect(payload['platform']).not_to eq('SourceHut')
      end
    end
  end
end
