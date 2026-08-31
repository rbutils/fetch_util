# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'FetchUtil extractor integration - Gitea and Forgejo threads' do
  include_context 'extractor integration helpers'

  def gitea_family_fixture(name)
    fixture_contents(File.expand_path("../fixtures/#{name}", __dir__))
  end

  it 'extracts every loaded Forgejo issue record with attachments, metadata, and traversal inventory' do
    extract_from_url('https://code.example/forgejo/repo/issues/42',
                     gitea_family_fixture('forgejo_issue_thread.html'), reader_mode: false) do |payload|
      markdown = payload.fetch('markdown')
      expect(payload).to include('contentType' => 'social', 'socialKind' => 'thread', 'platform' => 'Forgejo',
                                 'handle' => 'alice', 'replyCount' => nil, 'community' => 'forgejo/repo')
      expect(markdown).to include(
        '# Preserve complete Forgejo thread fidelity',
        '[Opening](https://code.example/forgejo/repo/issues/42#issue-42)',
        '[design.txt](https://code.example/attachments/design.txt)', '4 KiB',
        '[Comment by bob](https://code.example/forgejo/repo/issues/42#issuecomment-101)',
        '[Event by alice](https://code.example/forgejo/repo/issues/42#event-102)',
        '[Comment by carol](https://code.example/forgejo/repo/issues/42#issuecomment-103)',
        'Restored visible Forgejo comment.', '## Metadata', 'fidelity', 'Complete fidelity',
        '[Issue API](https://code.example/api/v1/repos/forgejo/repo/issues/42)',
        '[Comments API](https://code.example/api/v1/repos/forgejo/repo/issues/42/comments)',
        '[Timeline API](https://code.example/api/v1/repos/forgejo/repo/issues/42/timeline)',
        '[Labels API](https://code.example/api/v1/repos/forgejo/repo/issues/42/labels): Follow Link, X-HasMore, and total-count headers when present.',
        'Follow Link, X-HasMore, and total-count headers when present.'
      )
      expect(markdown).not_to include('Hidden raw opening source', 'Hidden editor', 'Hidden Forgejo comment',
                                      'Hidden stale metadata')
      expect(payload.fetch('html')).not_to include('Hidden raw opening source', 'Hidden Forgejo comment')
      expect(markdown.index('First loaded Forgejo comment.')).to be < markdown.index('changed the milestone')
      expect(markdown.index('changed the milestone')).to be < markdown.index('Restored visible Forgejo comment.')
    end
  end

  it 'accepts an attachment-only opening as material conversation content' do
    html = gitea_family_fixture('forgejo_issue_thread.html').sub(
      %r{<div class="render-content markup">\s*<p>Opening Forgejo body.*?</div>}m,
      ''
    )

    extract_from_url('https://code.example/forgejo/repo/issues/42', html, reader_mode: false) do |payload|
      expect(payload).to include('contentType' => 'social', 'platform' => 'Forgejo')
      expect(payload.fetch('markdown')).to include(
        '[design.txt](https://code.example/attachments/design.txt)', '4 KiB'
      )
    end
  end

  it 'exposes every pull-request UI, raw, and API resource on the conversation page' do
    review = <<~HTML
      <div class="timeline-item-group">
        <div id="event-review-500" class="timeline-item event"><span>approved these changes</span></div>
        <div class="timeline-item comment">
          <header class="comment-header"><div class="comment-header-left"><span class="tw-font-semibold">migrated-reviewer</span></div></header>
          <div class="comment-body">
            <div class="render-content markup"><p>Grouped review body remains atomic.</p></div>
            <div class="dropzone-attachments"><a href="/attachments/review.txt">review.txt</a></div>
          </div>
        </div>
        <div class="timeline-item event code-comments-list"><p>Inline review note stays with its review.</p></div>
      </div>
      <div class="timeline-item-group">
        <div id="event-review-501" class="timeline-item event"><span>approved these changes</span></div>
        <div class="timeline-item comment">
          <header class="comment-header"><div class="comment-header-left"><span class="tw-font-semibold">migrated-reviewer</span></div></header>
          <div class="comment-body">
            <div class="render-content markup"><p>Grouped review body remains atomic.</p></div>
            <div class="dropzone-attachments"><a href="/attachments/review.txt">review.txt</a></div>
          </div>
        </div>
        <div class="timeline-item event code-comments-list"><p>Inline review note stays with its review.</p></div>
      </div>
      <div class="timeline-item comment pull-merge-box"><button>Merge now</button><p>Actionable merge controls must not leak.</p></div>
      <div class="timeline-item comment merge box"><button>Merge changes</button><p>Forgejo merge controls must not leak.</p></div>
      <!-- timeline-end -->
    HTML
    html = gitea_family_fixture('forgejo_issue_thread.html').sub('<!-- timeline-end -->', review)

    extract_from_url('https://code.example/forgejo/repo/pulls/42',
                     html, reader_mode: false) do |payload|
      markdown = payload.fetch('markdown')
      expect(payload).to include('platform' => 'Forgejo', 'contentType' => 'social', 'replyCount' => nil)
      expect(markdown).to include(
        '- Pull Request: forgejo/repo',
        '[Commits](https://code.example/forgejo/repo/pulls/42/commits)',
        '[Files changed](https://code.example/forgejo/repo/pulls/42/files)',
        '[Raw diff](https://code.example/forgejo/repo/pulls/42.diff)',
        '[Raw patch](https://code.example/forgejo/repo/pulls/42.patch)',
        '[Pull request API](https://code.example/api/v1/repos/forgejo/repo/pulls/42)',
        '[Pull request commits API](https://code.example/api/v1/repos/forgejo/repo/pulls/42/commits)',
        '[Pull request files API](https://code.example/api/v1/repos/forgejo/repo/pulls/42/files)',
        '[Pull request reviews API](https://code.example/api/v1/repos/forgejo/repo/pulls/42/reviews)',
        '[Issue API](https://code.example/api/v1/repos/forgejo/repo/issues/42)',
        '[Review by migrated-reviewer](https://code.example/forgejo/repo/pulls/42#event-review-500)',
        '[Review by migrated-reviewer](https://code.example/forgejo/repo/pulls/42#event-review-501)',
        'Grouped review body remains atomic.', 'Inline review note stays with its review.',
        '[review.txt](https://code.example/attachments/review.txt)'
      )
      expect(markdown.scan('Grouped review body remains atomic.').length).to eq(2)
      expect(markdown).not_to include('Merge now', 'Actionable merge controls must not leak.',
                                      'Merge changes', 'Forgejo merge controls must not leak.')
      expect(payload.fetch('html')).not_to include('pull-merge-box', 'comment merge box')
    end
  end

  it 'supports native Gitea instances mounted under a relative root' do
    extract_from_url('https://git.example/forge/alice/project/issues/7',
                     gitea_family_fixture('gitea_issue_thread.html'), reader_mode: false) do |payload|
      markdown = payload.fetch('markdown')
      expect(payload).to include('contentType' => 'social', 'platform' => 'Gitea', 'handle' => 'migrated-alice',
                                 'community' => 'alice/project', 'replyCount' => nil)
      expect(markdown).to include(
        'Native Gitea opening body.', '[Comment by bob]', 'Native Gitea loaded comment.',
        '[Issue API](https://git.example/forge/api/v1/repos/alice/project/issues/7)',
        '[Comments API](https://git.example/forge/api/v1/repos/alice/project/issues/7/comments)'
      )
    end
  end

  it 'preserves distinct idless records with identical visible content' do
    repeated = <<~HTML
      <div class="timeline-item event"><p>Repeated idless event remains visible.</p></div>
      <div class="timeline-item event"><p>Repeated idless event remains visible.</p></div>
      <!-- timeline-end -->
    HTML
    html = gitea_family_fixture('forgejo_issue_thread.html').sub('<!-- timeline-end -->', repeated)

    extract_from_url('https://code.example/forgejo/repo/issues/42', html, reader_mode: false) do |payload|
      expect(payload.fetch('markdown').scan('Repeated idless event remains visible.').length).to eq(2)
    end
  end

  it 'preserves an uncapped Forgejo timeline in exact DOM order' do
    records = (1..25).map do |index|
      <<~HTML
        <div id="issuecomment-#{200 + index}" class="timeline-item comment">
          <header class="comment-header"><a class="author">user#{index}</a></header>
          <div class="comment-body"><div class="render-content markup"><p>Uncapped Forgejo record #{index}.</p></div></div>
        </div>
      HTML
    end.join
    html = gitea_family_fixture('forgejo_issue_thread.html').sub('<!-- timeline-end -->', records)

    extract_from_url('https://code.example/forgejo/repo/issues/42', html, reader_mode: false) do |payload|
      markdown = payload.fetch('markdown')
      expect((1..25).all? { |index| markdown.include?("Uncapped Forgejo record #{index}.") }).to be(true)
      expect(markdown.index('Uncapped Forgejo record 1.')).to be < markdown.index('Uncapped Forgejo record 25.')
    end
  end

  it 'does not borrow a commenter when the opening author is unavailable' do
    html = gitea_family_fixture('forgejo_issue_thread.html')
           .sub('<a class="author" href="/alice">alice</a>', '')

    extract_from_url('https://code.example/forgejo/repo/issues/42', html, reader_mode: false) do |payload|
      expect(payload).to include('platform' => 'Forgejo', 'handle' => nil)
      expect(payload.fetch('markdown')).not_to include('- Author: bob')
    end
  end

  it 'accepts a custom-branded instance through exact runtime asset and issue structure evidence' do
    html = gitea_family_fixture('forgejo_issue_thread.html')
           .sub('<meta name="author" content="forgejo">', '')
           .sub('assetVersionEncoded: "16.0.0-dev~gitea-1.22.0",', '')
           .sub('<footer><a href="https://forgejo.org/">Powered by Forgejo</a></footer>', '')

    extract_from_url('https://code.example/forgejo/repo/issues/42', html, reader_mode: false) do |payload|
      expect(payload).to include('contentType' => 'social', 'platform' => 'Gitea/Forgejo')
      expect(payload.fetch('markdown')).to include('Opening Forgejo body keeps')
    end
  end

  it 'requires independent product evidence and leaves resource and malformed routes to other profiles' do
    forgejo = gitea_family_fixture('forgejo_issue_thread.html')
    lookalike = forgejo
                .sub('<meta name="author" content="forgejo">', '')
                .sub('assetVersionEncoded: "16.0.0-dev~gitea-1.22.0",', '')
                .sub('assetUrlPrefix: "/assets"', 'assetUrlPrefix: ""')
                .sub('<script src="/assets/js/index.js"></script>', '')
                .sub('<footer><a href="https://forgejo.org/">Powered by Forgejo</a></footer>', '')

    extract_from_url('https://code.example/forgejo/repo/issues/42', lookalike, reader_mode: false) do |payload|
      expect(payload['platform']).not_to eq('Forgejo')
    end
    [
      'https://code.example/forgejo/repo/pulls/42/files',
      'https://code.example/forgejo/repo/pulls/42/commits',
      'https://code.example/forgejo/repo/issues/not-a-number'
    ].each do |url|
      extract_from_url(url, forgejo, reader_mode: false) do |payload|
        expect(payload['platform']).not_to eq('Forgejo')
      end
    end
  end
end
