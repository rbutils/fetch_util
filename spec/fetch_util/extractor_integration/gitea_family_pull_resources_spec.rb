# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'FetchUtil extractor integration - Gitea and Forgejo pull resources' do
  include_context 'extractor integration helpers'

  def gitea_pull_fixture(name)
    fixture_contents(File.expand_path("../fixtures/#{name}", __dir__))
  end

  it 'preserves every loaded commit, collapsed body, and traversal resource' do
    bulk = (1..24).map do |index|
      <<~HTML
        <div class="commit"><span class="author">Author #{index}</span><span class="sha">bulk#{index}</span><span class="message">Uncapped commit #{index}</span></div>
      HTML
    end.join
    html = gitea_pull_fixture('forgejo_pull_commits.html').sub('<!-- records-end -->', bulk)

    extract_from_url('https://code.example/forgejo/repo/pulls/42/commits', html, reader_mode: false) do |payload|
      markdown = payload.fetch('markdown')
      expect(payload).to include('contentType' => 'list', 'siteName' => 'Forgejo')
      expect(markdown).to include('Preserve the full visible commit row',
                                  'Collapsed substantive commit body remains available.',
                                  'Restored visible commit', 'Uncapped commit 1', 'Uncapped commit 24',
                                  '[Conversation](https://code.example/forgejo/repo/pulls/42)',
                                  '[Files changed](https://code.example/forgejo/repo/pulls/42/files)',
                                  '[Raw diff](https://code.example/forgejo/repo/pulls/42.diff)',
                                  '[Pull request commits API](https://code.example/api/v1/repos/forgejo/repo/pulls/42/commits)')
      expect(markdown).not_to include('Hidden stale commit', 'Copy')
      expect(markdown.scan('Repeated visible commit').length).to eq(2)
      expect(markdown.index('Uncapped commit 1')).to be < markdown.index('Uncapped commit 24')
      expect(payload.fetch('excerpt')).to include('Uncapped commit 24')
    end
  end

  it 'supports a custom-branded native Gitea instance under a relative root' do
    html = gitea_pull_fixture('gitea_pull_commits.html')
           .gsub('Gitea', 'Custom Code Service')
           .gsub('gitea-1.25.0', 'opaque-version')
           .gsub('https://about.gitea.com/', 'https://custom.example/about')

    extract_from_url('https://code.example/forge/team/repo/pulls/42/commits', html, reader_mode: false) do |payload|
      expect(payload).to include('contentType' => 'list', 'siteName' => 'Gitea/Forgejo')
      expect(payload.fetch('markdown')).to include('Native Custom Code Service commit row',
                                                   'Native collapsed commit body.')
      expect(payload.fetch('markdown')).to include(
        'https://code.example/forge/api/v1/repos/team/repo/pulls/42/commits'
      )
    end
  end

  it 'preserves native Gitea file trees, selected bodies, and restored visibility' do
    html = gitea_pull_fixture('gitea_pull_files.html')

    extract_from_url('https://code.example/forge/team/repo/pulls/42/files', html, reader_mode: false) do |payload|
      markdown = payload.fetch('markdown')
      expect(payload).to include('contentType' => 'list', 'siteName' => 'Gitea')
      expect(markdown).to include('- Changed files indexed: 3', 'lib/native.rb',
                                  'lib/deferred.rb', 'lib/restored.rb')
      expect(markdown).not_to include('native complete body', 'Hidden stale file',
                                      'hidden stale body', 'Viewed file')
    end

    extract_from_url('https://code.example/forge/team/repo/pulls/42/files#diff-native',
                     html, reader_mode: false) do |payload|
      expect(payload.fetch('markdown')).to include('## lib/native.rb', 'native complete body',
                                                   'Native inline review remains.')
      expect(payload.fetch('markdown')).not_to include('Copy path', 'Viewed file')
    end

    extract_from_url('https://code.example/forge/team/repo/pulls/42/files#diff-restored',
                     html, reader_mode: false) do |payload|
      expect(payload.fetch('markdown')).to include('restored visible native body')
      expect(payload.fetch('markdown')).not_to include('Hidden responsive header')
    end
  end

  it 'executes the Browser resource state against both product fixtures' do
    browser = FetchUtil::Browser.new

    with_url_page('https://code.example/forge/team/repo/pulls/42/files#diff-restored',
                  gitea_pull_fixture('gitea_pull_files.html')) do |page|
      script = browser.send(:gitea_family_pull_resource_product_state_script) +
               browser.send(:gitea_family_pull_resource_state_script)
      state = page.evaluate(script)
      expect(state).to include('product' => true, 'ready' => true, 'loading' => false)
      expect(state.fetch('signature')).to include('diff-restored')
    end

    with_url_page('https://code.example/forgejo/repo/pulls/42/files/aaa1#diff-alpha',
                  gitea_pull_fixture('forgejo_pull_files.html')) do |page|
      script = browser.send(:gitea_family_pull_resource_product_state_script) +
               browser.send(:gitea_family_pull_resource_state_script)
      state = page.evaluate(script)
      expect(state).to include('product' => true, 'ready' => true, 'loading' => false)
      expect(state.fetch('signature')).to include('diff-alpha')
    end
  end

  it 'supports commit-list and commit-detail routes with their actual page shapes' do
    extract_from_url('https://code.example/forgejo/repo/pulls/42/commits/list',
                     gitea_pull_fixture('forgejo_pull_commits.html'), reader_mode: false) do |payload|
      expect(payload.fetch('markdown')).to include('Preserve the full visible commit row', '- Commits shown: 4')
    end

    extract_from_url('https://code.example/forgejo/repo/pulls/42/commits/aaa1#diff-alpha',
                     gitea_pull_fixture('forgejo_pull_files.html'), reader_mode: false) do |payload|
      markdown = payload.fetch('markdown')
      expect(markdown).to include('## lib/alpha.rb', 'alpha complete body', 'Inline review remains',
                                  '/pulls/42/commits/aaa1#diff-beta')
      expect(markdown).not_to include('- Commits shown:', '/pulls/42/files#diff-beta')
    end

    extract_from_url('https://code.example/forgejo/repo/pulls/42/files/aaa1#diff-alpha',
                     gitea_pull_fixture('forgejo_pull_files.html'), reader_mode: false) do |payload|
      expect(payload.fetch('markdown')).to include('## lib/alpha.rb', 'alpha complete body',
                                                   '/pulls/42/files/aaa1#diff-beta')
    end
  end

  it 'does not claim a matching pull route without product evidence' do
    html = gitea_pull_fixture('forgejo_pull_commits.html')
           .gsub(/<meta name="author"[^>]*>/, '')
           .gsub(%r{<footer>.*?</footer>}m, '')
           .gsub(%r{<script src="[^"]+"></script>}, '')
           .gsub('forgejo-16.0.0', 'opaque-version')
           .gsub('Forgejo', 'Unrelated Service')

    extract_from_url('https://code.example/forgejo/repo/pulls/42/commits', html, reader_mode: false) do |payload|
      expect(payload).not_to include('siteName' => 'Gitea/Forgejo')
      expect(payload.fetch('markdown')).not_to include('Browse this Gitea/Forgejo pull request')
    end
  end

  it 'inventories every indexed file and every observed deferred route' do
    extract_from_url('https://code.example/forgejo/repo/pulls/42/files',
                     gitea_pull_fixture('forgejo_pull_files.html'), reader_mode: false) do |payload|
      markdown = payload.fetch('markdown')
      expect(payload).to include('contentType' => 'list', 'siteName' => 'Forgejo')
      expect(markdown).to include(
        '- Changed files indexed: 4',
        'lib/alpha.rb', 'lib/beta.rb', 'lib/gamma.rb',
        '[lib/gamma.rb](https://code.example/forgejo/repo/pulls/42/files?diff-page=2#diff-gamma)',
        '[lib/unloaded.rb](https://code.example/forgejo/repo/pulls/42/files?diff-page=3#diff-unloaded)',
        'Load deferred diff for lib/beta.rb',
        'https://code.example/forgejo/repo/pulls/42/files?file-only=true&files=beta',
        'Load more changed files',
        'https://code.example/forgejo/repo/pulls/42/files?skip-to=gamma',
        'https://code.example/forgejo/repo/pulls/42/files?diff-page=2',
        '[Pull request files API](https://code.example/api/v1/repos/forgejo/repo/pulls/42/files)'
      )
      expect(markdown).not_to include('alpha complete body', 'Hidden stale diff body',
                                      'Visibility-hidden stale file', 'visibility-hidden stale body')
    end
  end

  it 'renders only the exact selected loaded file with inline review context' do
    extract_from_url('https://code.example/forgejo/repo/pulls/42/files#diff-alpha',
                     gitea_pull_fixture('forgejo_pull_files.html'), reader_mode: false) do |payload|
      markdown = payload.fetch('markdown')
      expect(markdown).to include('## lib/alpha.rb', 'alpha complete body',
                                  'Inline review remains with the selected file.')
      expect(markdown).not_to include('Hidden stale diff body', 'Copy path', 'Viewed file')
      expect(payload.fetch('html')).to include('diff-alpha', 'Inline review remains with the selected file.')
      expect(payload.fetch('html')).not_to include('diff-beta', 'diff-file-header-actions', 'Viewed file')
    end
  end

  it 'reports selected deferred, unloaded, and unknown files truthfully' do
    html = gitea_pull_fixture('forgejo_pull_files.html')

    extract_from_url('https://code.example/forgejo/repo/pulls/42/files#diff-beta', html, reader_mode: false) do |payload|
      expect(payload.fetch('markdown')).to include('Selected file body is deferred',
                                                   'file-only=true&files=beta')
      expect(payload.fetch('markdown')).not_to include('The diff was suppressed because it is too large.')
    end
    extract_from_url('https://code.example/forgejo/repo/pulls/42/files#diff-unloaded', html, reader_mode: false) do |payload|
      expect(payload.fetch('markdown')).to include('Selected file is indexed but is not loaded')
    end
    extract_from_url('https://code.example/forgejo/repo/pulls/42/files#diff-unknown', html, reader_mode: false) do |payload|
      expect(payload.fetch('markdown')).to include('Selected file is not present in the loaded file inventory')
    end

    header_only = html.sub('class="diff-file-box file-content hidden-file"', 'class="diff-file-box file-content"')
                      .sub('<pre>Hidden stale diff body</pre>', '')
    extract_from_url('https://code.example/forgejo/repo/pulls/42/files#diff-gamma',
                     header_only, reader_mode: false) do |payload|
      expect(payload.fetch('markdown')).to include('Selected file body is not loaded on this page.')
      expect(payload.fetch('markdown')).not_to include('Selected file body is deferred on this page.')
    end
  end

  it 'keeps an uncapped file inventory in source order' do
    entries = (1..25).map do |index|
      %({ FullName: "lib/extra_#{index}.rb", NameHash: "extra-#{index}", EntryMode: "blob", Children: null })
    end.join(',')
    replacement = %(<script>window.config.pageData.diffFileInfo.files = [];
      window.config.pageData.DiffFileTree = { TreeRoot: {
        FullName: "", EntryMode: "tree", Children: [#{entries}] } };</script></body>)
    html = gitea_pull_fixture('forgejo_pull_files.html')
           .sub(%r{<div class="diff-file-tree">.*?</div>}m, '')
           .sub('</body>', replacement)

    extract_from_url('https://code.example/forgejo/repo/pulls/42/files', html, reader_mode: false) do |payload|
      markdown = payload.fetch('markdown')
      expect(markdown).to include('- Changed files indexed: 27', 'lib/extra_1.rb', 'lib/extra_25.rb')
      expect(markdown.index('lib/extra_1.rb')).to be < markdown.index('lib/extra_25.rb')
    end
  end

  it 'does not claim issue, malformed, or unknown pull routes' do
    html = gitea_pull_fixture('forgejo_pull_commits.html')
    urls = [
      'https://code.example/forgejo/repo/issues/42/commits',
      'https://code.example/forgejo/repo/pulls/not-a-number/commits',
      'https://code.example/forgejo/repo/pulls/42/commits/not-a-sha',
      'https://code.example/forgejo/repo/pulls/42/files/not-a-sha',
      'https://code.example/forgejo/repo/pulls/42/unknown'
    ]

    urls.each do |url|
      extract_from_url(url, html, reader_mode: false) do |payload|
        expect(payload.fetch('markdown')).not_to include('Browse this Forgejo pull request')
      end
    end
  end
end
