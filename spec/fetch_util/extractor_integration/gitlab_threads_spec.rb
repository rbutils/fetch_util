# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'FetchUtil extractor integration - GitLab threads' do
  include_context 'extractor integration helpers'

  def gitlab_fixture(name)
    fixture_contents(File.expand_path("../fixtures/#{name}", __dir__))
  end

  it 'extracts a host-agnostic GitLab work-item issue with every loaded timeline record' do
    extract_from_url('https://forge.example/team/project/-/work_items/12',
                     gitlab_fixture('gitlab_work_item_thread.html'), reader_mode: false) do |payload|
      markdown = payload.fetch('markdown')
      expect(payload).to include('contentType' => 'social', 'socialKind' => 'thread', 'platform' => 'GitLab',
                                 'handle' => 'alice', 'replyCount' => nil, 'community' => 'team/project')
      expect(markdown).to include(
        '# Preserve complete issue fidelity', 'Opening issue body keeps', 'Restored opening detail survives',
        '[Comment by bob](https://forge.example/team/project/-/work_items/12#note_101)',
        '[Event by alice](https://forge.example/team/project/-/work_items/12#note_102)',
        '[Comment by carol](https://forge.example/team/project/-/work_items/12#note_103)',
        '[Comment by dave](https://forge.example/team/project/-/work_items/12#note_105)',
        'Discussion reply one', 'Discussion reply two', 'Restored timeline detail survives',
        '## Metadata', 'Complete traversal',
        '[Conversation page](https://forge.example/team/project/-/work_items/12)',
        "Additional timeline records remain behind this GitLab page's in-page loader.",
        'https://forge.example/api/v4/projects/77/issues/12',
        'May require authentication; follow Link or X-Next-Page response headers.'
      )
      expect(markdown).not_to include('Hidden opening text', 'Hidden comment must not leak', 'hidden-restored-author',
                                      'Hidden stale metadata must not leak')
      expect(markdown.scan('Inventory milestone').length).to eq(1)
      expect(payload.fetch('html')).not_to include('Hidden opening text', 'Hidden comment must not leak')
      expect(payload.fetch('warnings')).not_to include('multi_topic_page')
      expect(markdown.index('First loaded comment')).to be < markdown.index('changed the milestone')
      expect(markdown.index('changed the milestone')).to be < markdown.index('Discussion reply one')
    end
  end

  it 'does not borrow a timeline commenter when the opening author is unavailable' do
    html = gitlab_fixture('gitlab_work_item_thread.html')
           .sub('<a data-testid="work-item-author" href="/alice">alice</a>', '')

    extract_from_url('https://forge.example/team/project/-/work_items/12', html, reader_mode: false) do |payload|
      expect(payload).to include('platform' => 'GitLab', 'handle' => nil)
      expect(payload.fetch('markdown')).not_to include('- Author: bob')
    end
  end

  it 'does not claim exhausted timeline controls have additional records' do
    html = gitlab_fixture('gitlab_work_item_thread.html')
           .sub('<button>Load more notes</button>', '<button aria-disabled="true">No more notes</button>')

    extract_from_url('https://forge.example/team/project/-/work_items/12', html, reader_mode: false) do |payload|
      expect(payload.fetch('markdown')).not_to include('Additional timeline records remain')
    end
  end

  it 'preserves an uncapped GitLab timeline in DOM order' do
    bulk = (1..25).map do |index|
      <<~HTML
        <div class="js-timeline-entry timeline-entry note-wrapper note-comment" id="note_#{300 + index}">
          <a class="js-user-link">user#{index}</a>
          <a href="#note_#{300 + index}"><time datetime="2026-08-03T10:#{index.to_s.rjust(2, "0")}:00Z">Aug 3</time></a>
          <div class="note-body"><p>Uncapped GitLab comment #{index}.</p></div>
        </div>
      HTML
    end.join
    html = gitlab_fixture('gitlab_work_item_thread.html').sub('<!-- timeline-end -->', bulk)

    extract_from_url('https://forge.example/team/project/-/issues/12', html, reader_mode: false) do |payload|
      markdown = payload.fetch('markdown')
      expect((1..25).all? { |index| markdown.include?("Uncapped GitLab comment #{index}.") }).to be(true)
      expect(markdown.index('Uncapped GitLab comment 1.')).to be < markdown.index('Uncapped GitLab comment 25.')
    end
  end

  it 'extracts a GitLab merge request and inventories every public resource family' do
    extract_from_url('https://code.example.test/group/subgroup/project/-/merge_requests/42',
                     gitlab_fixture('gitlab_merge_request_thread.html'), reader_mode: false) do |payload|
      markdown = payload.fetch('markdown')
      expect(payload).to include('contentType' => 'social', 'platform' => 'GitLab', 'handle' => 'maintainer',
                                 'community' => 'group/subgroup/project', 'replyCount' => nil)
      expect(markdown).to include(
        '- Merge Request: group/subgroup/project',
        '[Review by reviewer](https://code.example.test/group/subgroup/project/-/merge_requests/42#discussion_201)',
        '[Event by maintainer](https://code.example.test/group/subgroup/project/-/merge_requests/42#note_202)',
        '[Commits](https://code.example.test/group/subgroup/project/-/merge_requests/42/commits)',
        '[Pipelines](https://code.example.test/group/subgroup/project/-/merge_requests/42/pipelines)',
        '[Reports](https://code.example.test/group/subgroup/project/-/merge_requests/42/reports)',
        '[Changes](https://code.example.test/group/subgroup/project/-/merge_requests/42/diffs)',
        '[Raw diff](https://code.example.test/group/subgroup/project/-/merge_requests/42.diff)',
        '[Raw patch](https://code.example.test/group/subgroup/project/-/merge_requests/42.patch)',
        'https://code.example.test/api/v4/projects/88/merge_requests/42/diffs?per_page=100&page=1'
      )
      expect(markdown.index('Review discussion')).to be < markdown.index('approved this merge request')
    end
  end

  it 'requires independent GitLab product evidence while accepting GitLab work-item kinds' do
    issue = gitlab_fixture('gitlab_work_item_thread.html')
    lookalike = issue.sub('class="gl-system"', '').sub('<meta property="og:site_name" content="GitLab">', '')
                     .sub('<meta name="gitlab-meta" content="fixture">', '')
                     .sub(%r{<script src="https://forge\.example/assets/webpack/runtime\.js"></script>}, '')
                     .sub(%r{<script>window\.gon.*?</script>}, '')
    epic = issue.sub('aria-label="Issue">Issue', 'aria-label="Epic">Epic')

    extract_from_url('https://forge.example/team/project/-/work_items/12', lookalike, reader_mode: false) do |payload|
      expect(payload['platform']).not_to eq('GitLab')
    end
    extract_from_url('https://forge.example/team/project/-/work_items/12', epic, reader_mode: false) do |payload|
      expect(payload).to include('platform' => 'GitLab', 'contentType' => 'social')
    end
  end

  it 'keeps GitLab repository roots and resource subroutes outside conversation extraction' do
    html = gitlab_fixture('gitlab_merge_request_thread.html')
    [
      'https://code.example.test/group/project',
      'https://code.example.test/group/project/-/merge_requests/42/commits',
      'https://code.example.test/group/project/-/issues/not-a-number'
    ].each do |url|
      extract_from_url(url, html, reader_mode: false) do |payload|
        expect(payload['platform']).not_to eq('GitLab')
      end
    end
  end
end
