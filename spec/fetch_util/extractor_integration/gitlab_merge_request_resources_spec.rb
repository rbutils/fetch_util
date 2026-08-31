# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'FetchUtil extractor integration - GitLab merge request resources' do
  include_context 'extractor integration helpers'

  def gitlab_resource_fixture(name)
    fixture_contents(File.expand_path("../fixtures/#{name}", __dir__))
  end

  it 'preserves every loaded commit and relative-root resource link' do
    bulk = (1..24).map do |index|
      <<~HTML
        <article data-testid="commit-content">
          <a data-commit-link href="/gitlab/group/project/-/commit/#{index}">Uncapped commit #{index}</a>
          <span>Author #{index}</span><span>Status #{index}</span>
        </article>
      HTML
    end.join
    html = gitlab_resource_fixture('gitlab_mr_commits.html').sub('<!-- records-end -->', bulk)

    extract_from_url('https://forge.example/gitlab/group/project/-/merge_requests/42/commits',
                     html, reader_mode: false) do |payload|
      markdown = payload.fetch('markdown')
      expect(payload).to include('contentType' => 'list', 'siteName' => 'GitLab')
      expect(markdown).to include('First resource commit', 'Restored commit', 'Verified',
                                  'Uncapped commit 1', 'Uncapped commit 24')
      expect(markdown).not_to include('Hidden commit', 'Global commit chrome must not leak')
      expect(markdown.index('Uncapped commit 1')).to be < markdown.index('Uncapped commit 24')
      expect(payload.fetch('excerpt')).to include('Uncapped commit 24')
      expect(markdown).to include(
        'https://forge.example/gitlab/group/project/-/merge_requests/42/diffs',
        'https://forge.example/gitlab/api/v4/projects/88/merge_requests/42/commits?per_page=100&page=1'
      )
    end
  end

  it 'preserves an uncapped pipeline table in DOM order' do
    bulk = (1..24).map do |index|
      <<~HTML
        <tr data-testid="pipeline-table-row">
          <td><a href="/group/project/-/pipelines/#{600 + index}">Pipeline #{600 + index}</a></td>
          <td>State #{index}</td><td>#{index} jobs</td>
        </tr>
      HTML
    end.join
    duplicates = <<~HTML
      <tr data-testid="pipeline-table-row"><td>Repeated pending pipeline</td></tr>
      <tr data-testid="pipeline-table-row"><td>Repeated pending pipeline</td></tr>
    HTML
    html = gitlab_resource_fixture('gitlab_mr_pipelines.html').sub('<!-- records-end -->', bulk + duplicates)

    extract_from_url('https://forge.example/group/project/-/merge_requests/42/pipelines',
                     html, reader_mode: false) do |payload|
      markdown = payload.fetch('markdown')
      expect(markdown).to include('Pipeline 501', 'Pipeline 601', 'Pipeline 624', '8 jobs', '24 jobs')
      expect(markdown.index('Pipeline 601')).to be < markdown.index('Pipeline 624')
      expect(markdown.scan(/^### Pipeline /).length).to eq(27)
      expect(markdown.scan('Repeated pending pipeline').length).to eq(2)
    end
  end

  it 'preserves every loaded report section' do
    extract_from_url('https://forge.example/group/project/-/merge_requests/42/reports/codequality/',
                     gitlab_resource_fixture('gitlab_mr_reports.html'), reader_mode: false) do |payload|
      expect(payload.fetch('markdown')).to include(
        'Accessibility report', 'Two improvements found', 'Code quality report', 'No regressions found',
        '[Pipelines](https://forge.example/group/project/-/merge_requests/42/pipelines)'
      )
    end
  end

  it 'uses the project path for API traversal when numeric project metadata is absent' do
    html = gitlab_resource_fixture('gitlab_mr_reports.html')
           .sub(', current_project_id: 88', '')
           .sub(' data-project-id="88"', '')

    extract_from_url('https://forge.example/group/subgroup/project/-/merge_requests/42/reports',
                     html, reader_mode: false) do |payload|
      expect(payload.fetch('markdown')).to include(
        'https://forge.example/api/v4/projects/group%2Fsubgroup%2Fproject/merge_requests/42'
      )
    end
  end

  it 'preserves a restored-visible root-level empty state' do
    html = <<~HTML
      <!doctype html>
      <html class="gl-system"><head>
        <meta property="og:site_name" content="GitLab">
        <script>window.gon = { api_version: "v4", gitlab_url: "https://forge.example" };</script>
      </head><body>
        <main class="empty-state" style="visibility:hidden">
          <p style="visibility:visible">No reports are available.</p>
        </main>
      </body></html>
    HTML

    extract_from_url('https://forge.example/group/project/-/merge_requests/42/reports',
                     html, reader_mode: false) do |payload|
      expect(payload.fetch('markdown')).to include('No reports are available.', '[Conversation]')
    end
  end

  it 'inventories every changed file and deferred diff without rendering one giant page' do
    bulk = (1..22).map do |index|
      <<~HTML
        <diff-file data-testid="rd-diff-file" id="diff-extra-#{index}" data-path="lib/extra_#{index}.rb">
          <header data-path="lib/extra_#{index}.rb">lib/extra_#{index}.rb</header>
          <pre>+extra complete #{index}</pre>
        </diff-file>
      HTML
    end.join
    html = gitlab_resource_fixture('gitlab_mr_diffs.html').sub('<!-- files-end -->', bulk)

    extract_from_url('https://forge.example/group/project/-/merge_requests/42/diffs', html, reader_mode: false) do |payload|
      markdown = payload.fetch('markdown')
      expect(markdown).to include(
        '- Changed files shown: 30',
        '[lib/alpha.rb](https://forge.example/group/project/-/merge_requests/42/diffs#diff-a)',
        '[lib/extra_1.rb](https://forge.example/group/project/-/merge_requests/42/diffs#diff-extra-1)',
        '[lib/extra_22.rb](https://forge.example/group/project/-/merge_requests/42/diffs#diff-extra-22)',
        '[docs/gamma.md](https://forge.example/group/project/-/merge_requests/42/diffs#diff-c)',
        '[docs/space name.md](https://forge.example/group/project/-/merge_requests/42/diffs#%20docs%2Fspace%20%20name.md%20)',
        '[docs/no-id.md](https://forge.example/group/project/-/merge_requests/42/diffs#fetch-util-diff-5-)',
        '[docs/real-prefix.md](https://forge.example/group/project/-/merge_requests/42/diffs#fetch-util-diff-5)',
        '[docs/nested.md](https://forge.example/group/project/-/merge_requests/42/diffs#diff-outer)',
        '[docs/restored.md](https://forge.example/group/project/-/merge_requests/42/diffs#diff-restored)',
        '[Load deferred diff for lib/alpha.rb](https://forge.example/group/project/-/merge_requests/42/diffs_batch.json?file=diff-a)',
        'https://forge.example/api/v4/projects/88/merge_requests/42/diffs?per_page=100&page=1'
      )
      expect(markdown).not_to include('alpha complete line', 'Hidden diff must not leak')
      expect(markdown.index('lib/extra_1.rb')).to be < markdown.index('lib/extra_22.rb')
    end
  end

  it 'renders one selected complete diff while retaining recursive file inventory' do
    extract_from_url('https://forge.example/group/project/-/merge_requests/42/diffs#diff-a',
                     gitlab_resource_fixture('gitlab_mr_diffs.html'), reader_mode: false) do |payload|
      markdown = payload.fetch('markdown')
      expect(markdown).to include('## lib/alpha.rb', 'alpha complete line', '[spec/beta_spec.rb]')
      expect(markdown).to include('[View raw file](https://forge.example/group/project/-/raw/main/lib/alpha.rb)')
      expect(markdown).not_to include('Selected diff body is not loaded', 'Copy path')
      expect(markdown).not_to include('beta complete line', 'Hidden diff must not leak')
      expect(payload.fetch('html')).to include('alpha complete line')
      expect(payload.fetch('html')).not_to include('beta complete line')
    end
  end

  it 'reports a selected deferred diff instead of claiming its body is complete' do
    deferred = <<~HTML
      <diff-file data-testid="rd-diff-file" id="diff-deferred" data-path="docs/deferred.md">
        <header data-testid="rd-diff-file-header" data-path="docs/deferred.md">docs/deferred.md +1 -0</header>
        <include-fragment src="/group/project/-/merge_requests/42/diffs_batch.json?file=diff-deferred"></include-fragment>
      </diff-file>
    HTML
    html = gitlab_resource_fixture('gitlab_mr_diffs.html').sub('<!-- files-end -->', deferred)

    extract_from_url('https://forge.example/group/project/-/merge_requests/42/diffs#diff-deferred',
                     html, reader_mode: false) do |payload|
      expect(payload.fetch('markdown')).to include(
        '## docs/deferred.md',
        'Selected diff body is not loaded on this page',
        'diffs_batch.json?file=diff-deferred'
      )
    end
  end

  it 'resolves fallback file fragments and tolerates malformed fragments' do
    fixture = gitlab_resource_fixture('gitlab_mr_diffs.html')

    extract_from_url('https://forge.example/group/project/-/merge_requests/42/diffs#diff-c',
                     fixture, reader_mode: false) do |payload|
      expect(payload.fetch('markdown')).to include('## docs/gamma.md', 'gamma complete line', '[lib/alpha.rb]')
    end

    extract_from_url('https://forge.example/group/project/-/merge_requests/42/diffs#%20docs%2Fspace%20%20name.md%20',
                     fixture, reader_mode: false) do |payload|
      expect(payload.fetch('markdown')).to include('## docs/space name.md', 'space complete line', '[lib/alpha.rb]')
    end

    extract_from_url('https://forge.example/group/project/-/merge_requests/42/diffs#fetch-util-diff-5-',
                     fixture, reader_mode: false) do |payload|
      expect(payload.fetch('markdown')).to include('## docs/no-id.md', 'identifierless complete line', '[lib/alpha.rb]')
    end

    extract_from_url('https://forge.example/group/project/-/merge_requests/42/diffs#fetch-util-diff-5',
                     fixture, reader_mode: false) do |payload|
      expect(payload.fetch('markdown')).to include('## docs/real-prefix.md', 'real prefix complete line')
      expect(payload.fetch('markdown')).not_to include('identifierless complete line')
    end

    extract_from_url('https://forge.example/group/project/-/merge_requests/42/diffs#diff-outer',
                     fixture, reader_mode: false) do |payload|
      expect(payload.fetch('markdown')).to include('## docs/nested.md', 'nested complete line')
      expect(payload.fetch('markdown')).not_to include('#diff-inner')
    end

    extract_from_url('https://forge.example/group/project/-/merge_requests/42/diffs#%E0%A4%A',
                     fixture, reader_mode: false) do |payload|
      expect(payload.fetch('markdown')).to include('Browse changed files', '[docs/gamma.md]', '[docs/no-id.md]')
    end
  end

  it 'requires GitLab product evidence and exact merge-request resource routes' do
    fixture = gitlab_resource_fixture('gitlab_mr_commits.html')
    lookalike = fixture
                .sub('class="gl-system"', '')
                .sub('<meta property="og:site_name" content="GitLab">', '')
                .sub(%r{<script>window\.gon.*?</script>}, '')
    weak_runtime = fixture
                   .sub('class="gl-system"', '')
                   .sub('<meta property="og:site_name" content="GitLab">', '<meta name="gitlab-meta" content="weak">')
                   .sub(%r{<script>window\.gon.*?</script>}, '<script>window.gon = { api_version: "v4" };</script>')
    {
      'https://forge.example/gitlab/group/project/-/merge_requests/42/commits' => lookalike,
      'https://forge.example/gitlab/group/project/-/merge_requests/42/pipelines' => weak_runtime,
      'https://forge.example/gitlab/group/project/-/issues/42/commits' => fixture,
      'https://forge.example/gitlab/group/project/-/merge_requests/42' => fixture,
      'https://forge.example/gitlab/group/project/-/merge_requests/42/commits/not-real' => fixture,
      'https://forge.example/gitlab/group/project/-/merge_requests/42/diffs/not-real' => fixture,
      'https://forge.example/gitlab/group/project/-/merge_requests/42/reports/codequality/detail' => fixture
    }.each do |url, html|
      extract_from_url(url, html, reader_mode: false) do |payload|
        expect(payload['siteName']).not_to eq('GitLab')
      end
    end
  end
end
