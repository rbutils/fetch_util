# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'FetchUtil extractor integration - Gerrit changes' do
  include_context 'extractor integration helpers'

  def gerrit_fixture
    fixture_contents(File.expand_path('../fixtures/gerrit_change.html', __dir__))
  end

  it 'preserves a host-agnostic Gerrit change conversation and complete traversal inventory' do
    extract_from_url('https://review.example.test/c/platform/core/+/42', gerrit_fixture, reader_mode: false) do |payload|
      markdown = payload.fetch('markdown')
      expect(payload).to include('contentType' => 'social', 'socialKind' => 'thread', 'platform' => 'Gerrit',
                                 'community' => 'platform/core', 'handle' => 'Alice Reviewer', 'replyCount' => 7,
                                 'publishedTime' => '2026-09-01 09:00:00.000000000')
      expect(markdown).to include('# Preserve complete review history', 'Keep comments, files, and traversal links.',
                                  '## Labels', 'Bob Reviewer: +2', 'Carol Reviewer: -1', 'Uploaded patch set 1.',
                                  'Please preserve every review record.', 'This line needs a regression test.',
                                  'Added the requested regression test.', 'The overall approach now looks correct.',
                                  'Automated analysis passed.', 'Status: Unresolved', 'In reply to: comment-one',
                                  'Robot: lint-bot', 'Robot run: run-77',
                                  '9 | const previous = true;', '10 | const current = false;', '## Changed files',
                                  'src/widget.js', 'docs/review guide.md', '## Browse this Gerrit change',
                                  '/comments?enable-context=true&context-padding=3',
                                  '/revisions/current/files/', '/revisions/current/related', '/revisions/current/patch?download&raw',
                                  '/revisions/2/files/', '/revisions/3/patch?download&raw',
                                  'docs%2Freview%20guide.md/content', 'docs%2Freview%20guide.md/diff')
      expect(markdown.scan('Repeated idless Gerrit message.').length).to eq(2)
      expect(markdown).not_to include('/robotcomments')
      expect(markdown.scan('This line needs a regression test.').length).to eq(1)
      expect(markdown.index('Uploaded patch set 1.')).to be < markdown.index('Please preserve every review record.')
      expect(markdown.index('Please preserve every review record.')).to be < markdown.index('This line needs a regression test.')
      expect(markdown.index('This line needs a regression test.')).to be < markdown.index('Automated analysis passed.')
      expect(payload.fetch('html')).to include('data-fetch-util-gerrit-change="42"')
    end
  end

  it 'preserves an uncapped Gerrit message timeline in chronological order' do
    messages = (1..25).map do |index|
      {
        author: { name: "Reviewer #{index}" },
        date: "2026-09-02 10:#{index.to_s.rjust(2, "0")}:00.000000000",
        message: "Uncapped Gerrit message #{index}.",
        _revision_number: 3
      }
    end
    script = "<script>window.__fetchUtilGerritChange.detail.messages.push(...#{JSON.generate(messages)});</script>"
    html = gerrit_fixture.sub('</body>', "#{script}</body>")

    extract_from_url('https://review.example.test/c/platform/core/+/42', html, reader_mode: false) do |payload|
      records = payload.fetch('markdown').scan(/Uncapped Gerrit message (\d+)\./).flatten.map(&:to_i)
      expect(records).to eq((1..25).to_a)
    end
  end

  it 'accepts an explicit patch-set route without hostname ownership' do
    extract_from_url('https://custom-review.example/c/platform/core/+/42/3', gerrit_fixture, reader_mode: false) do |payload|
      expect(payload).to include('platform' => 'Gerrit', 'community' => 'platform/core')
    end
  end

  it 'requires independent Gerrit product evidence and prepared identity' do
    cases = {
      without_description: gerrit_fixture.sub('<meta name="description" content="Gerrit Code Review">', ''),
      without_app: gerrit_fixture.sub('<gr-app></gr-app>', ''),
      wrong_number: gerrit_fixture.sub('_number: 42', '_number: 43'),
      loading_state: gerrit_fixture.sub('status: "ready"', 'status: "loading"')
    }
    cases.each do |name, html|
      aggregate_failures(name) do
        extract_from_url('https://review.example.test/c/platform/core/+/42', html, reader_mode: false) do |payload|
          expect(payload['platform']).not_to eq('Gerrit')
        end
      end
    end
  end

  it 'keeps repository, malformed, and file routes outside Gerrit change extraction' do
    [
      'https://review.example.test/c/platform/core',
      'https://review.example.test/c/platform/core/+/not-a-number',
      'https://review.example.test/c/platform/core/+/42/3/src/widget.js'
    ].each do |url|
      extract_from_url(url, gerrit_fixture, reader_mode: false) do |payload|
        expect(payload['platform']).not_to eq('Gerrit')
      end
    end
  end
end
