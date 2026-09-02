# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'FetchUtil extractor integration - SourceHut git commits' do
  include_context 'extractor integration helpers'

  let(:commit_id) { 'a' * 40 }
  let(:parent_id) { 'b' * 40 }

  def sourcehut_git_fixture
    fixture_contents(File.expand_path('../fixtures/sourcehut_git_commit.html', __dir__))
  end

  it 'preserves complete SourceHut commit metadata, diffs, and traversal' do
    extract_from_url("https://git.example.test/~alice/project/commit/#{commit_id}", sourcehut_git_fixture,
                     reader_mode: false) do |payload|
      expect(payload).to include('contentType' => 'article', 'siteName' => 'SourceHut git',
                                 'title' => 'Preserve complete commits', 'byline' => 'Alice Example',
                                 'publishedTime' => '2026-08-28 09:04:49 UTC')
      markdown = payload.fetch('markdown')
      expect(markdown).to include(commit_id, parent_id, 'main', 'v1.0',
                                  'Keep every rendered SourceHut commit detail.',
                                  '2 files changed, 3 insertions(+), 1 deletion(-)',
                                  'new.txt', 'removed line', 'added line', 'context line',
                                  'second.txt', 'second file line', 'Raw patch', '.tar.gz', '.zip')
      expect(markdown).not_to include('hidden.txt')
      expect(markdown.index('new.txt')).to be < markdown.index('second.txt')
      expect(payload.fetch('html')).not_to include('hidden.txt')
      expect(Array(payload['warningReasons'])).to be_empty
    end
  end

  it 'accepts symbolic, abbreviated, and slash-bearing revisions' do
    ['main', 'aaaaaaaa', 'refs/heads/feature', 'refs%2Fheads%2Ffeature'].each do |revision|
      extract_from_url("https://git.example.test/~alice/project/commit/#{revision}", sourcehut_git_fixture,
                       reader_mode: false) do |payload|
        expect(payload).to include('contentType' => 'article', 'siteName' => 'SourceHut git')
        expect(payload.fetch('markdown')).to include(commit_id)
      end
    end
  end

  it 'preserves an uncapped SourceHut file and hunk sequence' do
    records = (1..25).map do |index|
      <<~HTML
        <pre class="mb-0 bg-transparent p-0">M =&gt; <a href="/~alice/project/tree/#{commit_id}/item/file-#{index}.txt">file-#{index}.txt</a></pre>
        <div class="event diff"><pre><strong class="text-info">@@ 1,1 1,1 @@</strong>
        <span class="text-success"><a class="lineno" aria-hidden="true" href="#file-#{index}">+</a>uncapped line #{index}</span></pre></div>
      HTML
    end.join
    html = sourcehut_git_fixture.sub('<!-- bulk-files -->', records)

    extract_from_url('https://git.example.test/~alice/project/commit/main', html, reader_mode: false) do |payload|
      found = payload.fetch('markdown').scan(/uncapped line (\d+)/).flatten.map(&:to_i)
      expect(found).to eq((1..25).to_a)
    end
  end

  it 'reports the upstream large first-parent diff boundary truthfully' do
    second_parent = <<~HTML
      <a href="/~alice/project/commit/cccccccccccccccccccccccccccccccccccccccc">cccccccc</a>
    HTML
    html = sourcehut_git_fixture
           .sub('2 files changed, 3 insertions(+), 1 deletion(-)',
                '25 files changed, 6,001 insertions(+), 4,000 deletions(-)')
           .sub('<!-- extra-parents -->', second_parent)
           .sub(/<!-- diff-files-start -->.*?<!-- diff-files-end -->/m, <<~HTML)
             <div class="alert alert-warning">This diff is too large to display. Try <a href="/~alice/project/commit/#{commit_id}.patch">viewing the raw diff</a> instead.</div>
           HTML

    extract_from_url('https://git.example.test/~alice/project/commit/main', html, reader_mode: false) do |payload|
      expect(payload.fetch('warnings')).to include('sourcehut_git_commit_diff_incomplete')
      expect(payload.fetch('markdown')).to include('10,000 changed-line display boundary',
                                                   'first-parent diff',
                                                   'Raw patch (may not represent this merge commit)')
    end
  end

  it 'accepts root commits and plain-text authors without inventing parents' do
    html = sourcehut_git_fixture
           .sub('<a class="commit-author" href="/~alice">Alice Example</a>', 'Plain Author')
           .sub(/<!-- parent-start -->.*?<!-- parent-end -->/m, '')

    extract_from_url('https://git.example.test/~alice/project/commit/main', html, reader_mode: false) do |payload|
      expect(payload).to include('byline' => 'Plain Author')
      expect(payload.fetch('markdown')).to include('Diff basis: Empty tree (root commit)')
      expect(payload.fetch('markdown')).not_to include('Parent 1:')
    end
  end

  it 'requires independent SourceHut git evidence and matching commit identity' do
    controls = {
      without_asset: sourcehut_git_fixture.gsub(%r{\s*<link rel="stylesheet" href="/static/git\.sr\.ht/[^"]+">}, ''),
      off_origin_asset: sourcehut_git_fixture.sub('href="/static/', 'href="https://lookalike.invalid/static/'),
      wrong_vcs: sourcehut_git_fixture.sub('content="git"', 'content="hg"'),
      wrong_summary: sourcehut_git_fixture.sub('content="https://git.example.test/~alice/project"',
                                               'content="https://git.example.test/~alice/other"'),
      wrong_navigation: sourcehut_git_fixture.sub('href="/~alice/project/refs"', 'href="/~alice/other/refs"'),
      missing_patch: sourcehut_git_fixture.sub("/commit/#{commit_id}.patch", "/commit/#{commit_id}.download"),
      missing_tree: sourcehut_git_fixture.sub("/tree/#{commit_id}\">browse", "/source/#{commit_id}\">browse"),
      malformed_identity: sourcehut_git_fixture.sub(commit_id, 'not-a-commit-id'),
      duplicate_summary_meta: sourcehut_git_fixture.sub('</head>',
                                                         '<meta name="forge:summary" content="https://git.example.test/~alice/project"></head>')
    }

    controls.each_value do |html|
      extract_from_url('https://git.example.test/~alice/project/commit/main', html, reader_mode: false) do |payload|
        expect(payload['siteName']).not_to eq('SourceHut git')
      end
    end
  end

  it 'does not treat warning prose as a large-diff boundary below the upstream line threshold' do
    html = sourcehut_git_fixture.sub('<!-- diff-files-end -->', <<~HTML)
      <!-- diff-files-end -->
      <div class="alert alert-warning">This diff is too large to display.</div>
    HTML

    extract_from_url('https://git.example.test/~alice/project/commit/main', html, reader_mode: false) do |payload|
      expect(Array(payload['warnings'])).not_to include('sourcehut_git_commit_diff_incomplete')
      expect(payload.fetch('markdown')).to include('new.txt', 'second.txt')
    end
  end

  it 'keeps malformed, patch, mismatched hash, and non-commit routes outside the profile' do
    urls = [
      "https://git.example.test/~alice/project/commit/#{commit_id}.patch",
      "https://git.example.test/~alice/project/commit/#{commit_id}/",
      'https://git.example.test/~alice/project/commit',
      'https://git.example.test/~alice/project/tree/main',
      'https://git.example.test/alice/project/commit/main',
      'https://git.example.test/~alice/project/commit/cccccccc',
      'https://git.example.test/~alice/project/commit/refs//main'
    ]

    urls.each do |url|
      extract_from_url(url, sourcehut_git_fixture, reader_mode: false) do |payload|
        expect(payload['siteName']).not_to eq('SourceHut git')
      end
    end
  end
end
