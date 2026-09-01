# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'FetchUtil extractor integration - Gerrit change resources' do
  include_context 'extractor integration helpers'

  def gerrit_resource_base_fixture
    fixture_contents(File.expand_path('../fixtures/gerrit_change.html', __dir__))
      .sub('<head>', '<head><base href="/r/">')
  end

  def gerrit_resource_state(selector: '2..3', file_path: 'src/widget.js')
    siblings = (1..12).to_h do |index|
      ["lib/sibling-#{index}.rb", { status: 'M', lines_inserted: index, lines_deleted: index - 1 }]
    end
    file = { status: 'R', old_path: 'src/old-widget.js', lines_inserted: 2, lines_deleted: 1, size: 84 }
    {
      status: 'ready', product: true, routeKey: "https://review.example.test:/r/c/platform/core/+/42:#{selector}:#{file_path}",
      route: {
        project: 'platform/core', number: '42', patchset: '3', selector: selector, target: '3', base: '2',
        comparison: 'patchset', comparisonValue: '2', filePath: file_path,
        changePath: '/r/c/platform/core/+/42', apiPath: '/r/changes/platform%2Fcore%7E42'
      },
      detail: {
        _number: 42, project: 'platform/core', subject: 'Preserve complete review history', status: 'NEW',
        created: '2026-09-01 09:00:00.000000000', updated: '2026-09-01 13:00:00.000000000',
        owner: { name: 'Alice Reviewer' }, revisions: {
          base: { _number: 2, commit: { message: 'Base revision', parents: [{ commit: 'parent-base' }] } },
          target: { _number: 3, commit: { message: 'Target revision', parents: [{ commit: 'parent-target' }] } }
        }
      },
      comments: {
        'src/widget.js' => [
          { id: 'file-comment-historical', patch_set: 1, updated: '2026-09-01 09:45:00.000000000',
            author: { name: 'Historical Reviewer' }, message: 'Historical file observation.', line: 3,
            side: 'PARENT', parent: 2 },
          { id: 'file-comment-1', patch_set: 2, updated: '2026-09-01 10:00:00.000000000',
            author: { name: 'Base Reviewer' }, message: 'Base-side observation.', line: 4,
            context_lines: [{ line_number: 4, context_line: 'const before = true;' }] },
          { id: 'file-comment-2', patch_set: 3, updated: '2026-09-01 11:00:00.000000000',
            author: { name: 'Target Reviewer' }, message: 'Target-side observation.', unresolved: true,
            range: { start_line: 8, start_character: 2, end_line: 8, end_character: 12 },
            context_lines: [{ line_number: 8, context_line: 'const after = false;' }] }
        ],
        'other/file.rb' => [{ id: 'other-comment', patch_set: 3, message: 'Other file only.' }]
      },
      files: siblings.merge('src/widget.js' => file, '/COMMIT_MSG' => { status: 'M' }),
      filePath: 'src/widget.js', requestedFilePath: file_path, file: file,
      diff: {
        change_type: 'RENAMED', diff_header: ['diff --git a/src/old-widget.js b/src/widget.js'],
        meta_a: { name: 'src/old-widget.js', content_type: 'text/plain', lines: 10, language: 'TypeScript' },
        meta_b: { name: 'src/widget.js', content_type: 'text/plain', lines: 11, language: 'TypeScript' },
        intraline_status: 'OK', web_links: [{ name: 'Browse', url: 'https://review.example.test/source' }],
        content: [
          { ab: ['const shared = true;'] },
          { a: ['const before = true;'], b: ['const after = false;'], common: false,
            due_to_rebase: true, edit_a: [[0, 5]], edit_b: [[0, 4]],
            move_details: { source: 'src/old-widget.js', destination: 'src/widget.js' } },
          { skip: { left: 4, right: 5 } },
          { b: ['const finalLine = true;'] }
        ]
      },
      fileCount: 14, commentCount: 4, diffBlockCount: 4
    }
  end

  def gerrit_resource_fixture(state = gerrit_resource_state)
    script = "<script>window.__fetchUtilGerritFileResource = #{JSON.generate(state)};</script>"
    gerrit_resource_base_fixture.sub('</body>', "#{script}</body>")
  end

  it 'preserves the complete selected Gerrit file diff, comments, and uncapped inventory' do
    url = 'https://review.example.test/r/c/platform/core/+/42/2..3/src/widget.js'
    extract_from_url(url, gerrit_resource_fixture, reader_mode: false) do |payload|
      markdown = payload.fetch('markdown')
      expected_fragments = [
        '# Preserve complete review history - src/widget.js',
        '- Comparison: Patch set 2 to 3', '- Status: R',
        '- Previous path: src/old-widget.js', '- Change type: RENAMED',
        'diff --git a/src/old-widget.js b/src/widget.js',
        'Common block: no', 'Due to rebase: yes',
        'Base intraline edits: [[0,5]]', 'Target intraline edits: [[0,4]]',
        'Move details: {"source":"src/old-widget.js","destination":"src/widget.js"}',
        ' const shared = true;', '-const before = true;', '+const after = false;',
        '@@ base 4, target 5 unchanged lines omitted @@', '+const finalLine = true;',
        '- Base Lines: 10', '- Base Language: TypeScript', '- Target Lines: 11',
        '- Diff Intraline Status: OK', '- Diff Web Links: [{"name":"Browse"',
        'Historical file observation.', 'Side: PARENT', 'Parent: 2',
        'Base-side observation.', 'Target-side observation.', 'Status: Unresolved',
        '4 | const before = true;', '8 | const after = false;',
        '/revisions/3/files/src%2Fwidget.js/diff?base=2&context=ALL',
        '/revisions/2/files/src%2Fold-widget.js/content',
        '/2..3//COMMIT_MSG', '/2..3/src/old-widget.js'
      ]
      expect(payload).to include('contentType' => 'list', 'siteName' => 'Gerrit')
      expect(markdown).to include(*expected_fragments)
      expect(markdown).not_to include('Other file only.')
      expect(markdown.scan(%r{File: lib/sibling-\d+\.rb}).length).to eq(12)
      expect(markdown.index('Historical file observation.')).to be < markdown.index('Base-side observation.')
      expect(markdown.index('Base-side observation.')).to be < markdown.index('Target-side observation.')
      expect(payload.fetch('html')).to include('data-fetch-util-gerrit-file="src/widget.js"',
                                               'Base-side observation.', 'Browse this Gerrit file comparison')
    end
  end

  it 'maps auto-merge, parent, and target-only comparisons without invalid REST parameters' do
    cases = {
      '0..3' => ['Auto-merge base to patch set 3', nil],
      '-2..3' => ['Parent 2 to patch set 3', 'parent=2'],
      '3..3' => ['Patch set 3 to 3', 'base=3'],
      '3' => ['Gerrit default base to patch set 3', nil]
    }
    cases.each do |selector, (label, query)|
      state = gerrit_resource_state(selector: selector)
      state[:route][:selector] = selector
      state[:route][:base] = selector.include?('..') ? selector.split('..').first : nil
      base = selector.include?('..') ? selector.split('..').first : nil
      comparison = if base&.start_with?('-')
                     'parent'
                   elsif base == '0'
                     'auto_merge'
                   elsif base
                     'patchset'
                   else
                     'implicit'
                   end
      state[:route][:comparison] = comparison
      state[:route][:comparisonValue] = if comparison == 'parent'
                                          base.sub(/^-/, '')
                                        elsif comparison == 'patchset'
                                          base
                                        end
      if selector.start_with?('-')
        state[:detail][:revisions][:target][:commit][:parents] << { commit: 'second-parent' }
      end
      url = "https://review.example.test/r/c/platform/core/+/42/#{selector}/src/widget.js"

      extract_from_url(url, gerrit_resource_fixture(state), reader_mode: false) do |payload|
        markdown = payload.fetch('markdown')
        expect(markdown).to include(label)
        if query
          expect(markdown).to include("diff?#{query}&context=ALL")
        elsif selector == '3'
          expect(markdown).to include('/content?parent=1')
          expect(markdown).not_to include('diff?parent=1')
        else
          expect(markdown).not_to include('base=0', 'base=-2', 'parent=1')
        end
      end
    end
  end

  it 'preserves both default and first-parent comparisons for a target-only merge route' do
    state = gerrit_resource_state(selector: '3')
    state[:route].merge!(selector: '3', base: nil, comparison: 'implicit', comparisonValue: nil)
    state[:detail][:revisions][:target][:commit][:parents] << { commit: 'second-parent' }
    state[:firstParentDiff] = {
      change_type: 'RENAMED', meta_b: { name: 'src/widget.js' },
      content: [{ b: ['const firstParentOnly = true;'] }]
    }

    extract_from_url('https://review.example.test/r/c/platform/core/+/42/3/src/widget.js',
                     gerrit_resource_fixture(state), reader_mode: false) do |payload|
      markdown = payload.fetch('markdown')
      expect(markdown).to include('## Complete diff', '## Alternative first-parent comparison',
                                  '+const firstParentOnly = true;', '/-1..3/src/widget.js',
                                  'diff?parent=1&context=ALL')
    end
  end

  it 'preserves magic paths and reports binary or deleted files without inventing text' do
    state = gerrit_resource_state(selector: '3', file_path: '/COMMIT_MSG')
    state[:route].merge!(selector: '3', base: nil, comparison: 'implicit', comparisonValue: nil,
                         filePath: '/COMMIT_MSG')
    state[:filePath] = '/COMMIT_MSG'
    state[:requestedFilePath] = '/COMMIT_MSG'
    state[:file] = { status: 'D', binary: true }
    state[:files]['/COMMIT_MSG'] = state[:file]
    state[:diff] = { change_type: 'DELETED', binary: true, content: [] }

    extract_from_url('https://review.example.test/r/c/platform/core/+/42/3//COMMIT_MSG',
                     gerrit_resource_fixture(state), reader_mode: false) do |payload|
      markdown = payload.fetch('markdown')
      expect(markdown).to include('- File: /COMMIT_MSG', '- Binary: yes',
                                  'Binary file; Gerrit returned no textual diff.', '/3//COMMIT_MSG',
                                  'files/%2FCOMMIT_MSG/diff?context=ALL', 'content?parent=1')
      expect(markdown).not_to include('Selected file target content', 'File content: /COMMIT_MSG]')
    end
  end

  it 'omits nonexistent base content inventory for an added file' do
    state = gerrit_resource_state
    state[:file] = { status: 'A', lines_inserted: 3 }
    state[:files]['src/widget.js'] = state[:file]
    state[:diff] = {
      change_type: 'ADDED', meta_b: { name: 'src/widget.js', content_type: 'text/plain' },
      content: [{ b: ['const added = true;'] }]
    }

    extract_from_url('https://review.example.test/r/c/platform/core/+/42/2..3/src/widget.js',
                     gerrit_resource_fixture(state), reader_mode: false) do |payload|
      markdown = payload.fetch('markdown')
      expect(markdown).to include('/revisions/3/files/src%2Fwidget.js/content')
      expect(markdown).not_to include('/revisions/2/files/src%2Fwidget.js/content')
    end
  end

  it 'executes the real Browser state script with comparison-specific REST routes' do
    browser = FetchUtil::Browser.new
    state = gerrit_resource_state
    url = 'https://review.example.test/r/c/platform/core/+/42/2..3/src/widget.js'

    with_url_page(url, gerrit_resource_base_fixture) do |page|
      page.evaluate(<<~JS)
        (() => {
          const fixture = window.__gerritFileFixture = #{JSON.generate(state)};
          window.__gerritFileRequests = [];
          window.fetch = (value) => {
            const url = new URL(value, location.href);
            window.__gerritFileRequests.push(url.pathname + url.search);
            let payload;
            if (url.pathname.endsWith('/detail')) payload = fixture.detail;
            else if (url.pathname.endsWith('/comments')) payload = window.__gerritFileCommentsOverride || fixture.comments;
            else if (url.pathname.endsWith('/diff')) {
              payload = url.searchParams.get('parent') === '1'
                ? (fixture.firstParentDiff || fixture.diff)
                : (window.__gerritFileDiffOverride || fixture.diff);
            }
            else payload = fixture.files;
            return Promise.resolve({
              ok: true,
              text: () => Promise.resolve(")]}'\\n" + JSON.stringify(payload))
            });
          };
        })()
      JS

      expect(browser.send(:stabilize_page, page, url)).to be(true)
      prepared = page.evaluate('window.__fetchUtilGerritFileResource')

      expect(prepared).to include('status' => 'ready', 'filePath' => 'src/widget.js', 'diffBlockCount' => 4)
      expect(extract_payload(page, reader_mode: false)).to include('siteName' => 'Gerrit', 'contentType' => 'list')
      expect(page.evaluate('window.__gerritFileRequests')).to include(
        a_string_including('/revisions/3/files/?base=2'),
        a_string_including('/revisions/3/files/src%2Fwidget.js/diff?base=2&context=ALL')
      )

      equal_url = 'https://review.example.test/c/c/platform/core/+/42/3..3/src/widget.js'
      page.evaluate(<<~JS)
        (() => {
          document.querySelector('base').setAttribute('href', '/c/');
          history.replaceState({}, '', #{JSON.generate(equal_url)});
          window.__gerritFileRequests = [];
          window.__fetchUtilGerritFileResource = null;
        })()
      JS
      expect(browser.send(:stabilize_page, page, equal_url)).to be(true)
      prepared = page.evaluate('window.__fetchUtilGerritFileResource')
      expect(prepared.fetch('route')).to include(
        'project' => 'platform/core', 'comparison' => 'patchset', 'comparisonValue' => '3'
      )
      expect(page.evaluate('window.__gerritFileRequests')).to include(
        a_string_including('/c/changes/platform%2Fcore~42/revisions/3/files/?base=3'),
        a_string_including('/c/changes/platform%2Fcore~42/revisions/3/files/src%2Fwidget.js/diff?base=3&context=ALL')
      )

      merge_url = 'https://review.example.test/r/c/platform/core/+/42/3/src/widget.js'
      page.evaluate(<<~JS)
        (() => {
          document.querySelector('base').setAttribute('href', '/r/');
          history.replaceState({}, '', #{JSON.generate(merge_url)});
          const fixture = window.__gerritFileFixture;
          fixture.detail.revisions.target.commit.parents.push({ commit: 'second-parent' });
          fixture.firstParentDiff = {
            change_type: 'RENAMED',
            meta_b: { name: 'src/widget.js' },
            content: [{ b: ['const firstParentOnly = true;'] }]
          };
          window.__gerritFileRequests = [];
          window.__fetchUtilGerritFileResource = null;
        })()
      JS
      expect(browser.send(:stabilize_page, page, merge_url)).to be(true)
      prepared = page.evaluate('window.__fetchUtilGerritFileResource')
      expect(prepared).to include('status' => 'ready', 'firstParentDiffBlockCount' => 1)
      expect(page.evaluate('window.__gerritFileRequests')).to include(
        a_string_including('/revisions/3/files/src%2Fwidget.js/diff?context=ALL'),
        a_string_including('/revisions/3/files/src%2Fwidget.js/diff?parent=1&context=ALL')
      )
      expect(extract_payload(page, reader_mode: false).fetch('markdown')).to include(
        '## Alternative first-parent comparison', '+const firstParentOnly = true;'
      )

      page.evaluate(<<~JS)
        (() => {
          window.__fetchUtilGerritFileResource = null;
          window.__gerritFileDiffOverride = { meta_b: { name: "other/file.js" }, content: [] };
        })()
      JS
      expect(page.evaluate(browser.send(:gerrit_file_resource_state_script))).to include('status' => 'loading')
      50.times do
        prepared = page.evaluate('window.__fetchUtilGerritFileResource')
        break if prepared['status'] != 'loading'

        sleep 0.01
      end
      expect(prepared).to include('status' => 'failed', 'reason' => 'Gerrit API diff target identity mismatch')

      page.evaluate(<<~JS)
        (() => {
          window.__fetchUtilGerritFileResource = null;
          window.__gerritFileDiffOverride = null;
          window.__gerritFileCommentsOverride = { "src/widget.js": {} };
        })()
      JS
      expect(page.evaluate(browser.send(:gerrit_file_resource_state_script))).to include('status' => 'loading')
      50.times do
        prepared = page.evaluate('window.__fetchUtilGerritFileResource')
        break if prepared['status'] != 'loading'

        sleep 0.01
      end
      expect(prepared).to include('status' => 'failed', 'reason' => 'invalid Gerrit comments payload')
      expect(extract_payload(page, reader_mode: false)['siteName']).not_to eq('Gerrit')

      invalid_diffs = [
        { meta_b: { name: 'src/widget.js' }, content: [nil] },
        { meta_b: { name: 'src/widget.js' }, content: [{ a: [{}] }] },
        { meta_b: { name: 'src/widget.js' }, content: [{ edit_a: [[0]] }] }
      ]
      invalid_diffs.each do |invalid_diff|
        page.evaluate(<<~JS)
          (() => {
            window.__fetchUtilGerritFileResource = null;
            window.__gerritFileCommentsOverride = null;
            window.__gerritFileDiffOverride = #{JSON.generate(invalid_diff)};
          })()
        JS
        expect(page.evaluate(browser.send(:gerrit_file_resource_state_script))).to include('status' => 'loading')
        50.times do
          prepared = page.evaluate('window.__fetchUtilGerritFileResource')
          break if prepared['status'] != 'loading'

          sleep 0.01
        end
        expect(prepared).to include('status' => 'failed', 'reason' => 'invalid Gerrit diff content payload')
        expect(extract_payload(page, reader_mode: false)['siteName']).not_to eq('Gerrit')
      end
    end
  end

  it 'rejects malformed routes, product lookalikes, and mismatched prepared identities' do
    no_product_fixture = gerrit_resource_fixture.sub('<meta name="description" content="Gerrit Code Review">', '')
    no_product_fixture = no_product_fixture.sub('<gr-app></gr-app>', '')
    wrong_diff_state = gerrit_resource_state
    wrong_diff_state[:diff][:meta_b][:name] = 'other/file.js'
    cases = {
      malformed: ['https://review.example.test/r/c/platform/core/+/42/edit/src/widget.js', gerrit_resource_fixture],
      empty_segment: ['https://review.example.test/r/c/platform/core/+/42/3/src//secret', gerrit_resource_fixture],
      wrong_target: ['https://review.example.test/r/c/platform/core/+/42/2..4/src/widget.js', gerrit_resource_fixture],
      wrong_diff_file: ['https://review.example.test/r/c/platform/core/+/42/2..3/src/widget.js',
                        gerrit_resource_fixture(wrong_diff_state)],
      no_product: [
        'https://review.example.test/r/c/platform/core/+/42/2..3/src/widget.js',
        no_product_fixture
      ]
    }
    cases.each do |name, (url, html)|
      aggregate_failures(name) do
        extract_from_url(url, html, reader_mode: false) do |payload|
          expect(payload['siteName']).not_to eq('Gerrit')
        end
      end
    end
  end
end
