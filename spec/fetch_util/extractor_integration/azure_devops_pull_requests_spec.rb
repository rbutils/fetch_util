# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'FetchUtil extractor integration - Azure DevOps pull requests' do
  include_context 'extractor integration helpers'

  def azure_devops_fixture
    fixture_contents(File.expand_path('../fixtures/azure_devops_pull_request.html', __dir__))
  end

  def wait_for_azure_devops_preparation(page)
    100.times do
      state = page.evaluate('window.__fetchUtilAzureDevopsPullRequest')
      return state if state['status'] != 'loading'

      sleep 0.01
    end
    page.evaluate('window.__fetchUtilAzureDevopsPullRequest')
  end

  it 'preserves a host-agnostic public pull request, every REST record, and complete traversal inventory' do
    url = 'https://code.example.test/organization/public/_git/project/pullrequest/5'
    extract_from_url(url, azure_devops_fixture, reader_mode: false) do |payload|
      markdown = payload.fetch('markdown')
      expect(payload).to include('contentType' => 'social', 'socialKind' => 'thread',
                                 'platform' => 'Azure DevOps', 'community' => 'public/project',
                                 'handle' => 'Alice Author', 'replyCount' => 4,
                                 'publishedTime' => '2026-09-01T09:00:00Z')
      expect(markdown).to include('# Inventory bootstrapping', 'Second description paragraph.',
                                  '## Reviewers', 'Bob Reviewer', 'Approved', 'Waiting for author',
                                  'Alice Author updated the pull request.', 'Deleted comment body unavailable.',
                                  'Preserve this inline review comment.', 'Preserve this inline reply.',
                                  '/src/widget.js', 'rightFileStart', 'Change tracking ID: 77',
                                  'Deleted thread: yes', 'lastContentUpdatedDate', 'usersLiked',
                                  'parents', 'statuses', 'workItems',
                                  '1111111111111111111111111111111111111111',
                                  '2222222222222222222222222222222222222222',
                                  '## Browse this Azure DevOps pull request', '?_a=files', '?_a=updates',
                                  '/threads?api-version=7.1', '/commits?api-version=7.1&%24top=1000',
                                  'Follow each opaque x-ms-continuationtoken', 'May require authentication')
      expect(markdown).to include('https://code.example.test/thread-context', 'https://code.example.test/property')
      expect(markdown).not_to include('javascript:unsafeComment', 'javascript:unsafeThread',
                                      'javascript:unsafeProperty', 'javascript:unsafeArray')
      expect(payload.fetch('html')).to include('data-fetch-util-azure-devops-pr="5"')
    end
  end

  it 'preserves uncapped REST threads, comments, and commits in source order' do
    threads = (1..25).map do |index|
      {
        id: 100 + index,
        status: 'active',
        comments: [{ id: 1, commentType: 'text', content: "Uncapped Azure comment #{index}.",
                     author: { displayName: "Reviewer #{index}" } }]
      }
    end
    commits = (1..25).map do |index|
      { commitId: index.to_s(16).rjust(40, '0'), comment: "Uncapped Azure commit #{index}." }
    end
    script = <<~HTML
      <script>
        window.__fetchUtilAzureDevopsPullRequest.threads.value.push(...#{JSON.generate(threads)});
        window.__fetchUtilAzureDevopsPullRequest.commits.push(...#{JSON.generate(commits)});
      </script>
    HTML
    html = azure_devops_fixture.sub('</body>', "#{script}</body>")

    extract_from_url('https://code.example.test/organization/public/_git/project/pullrequest/5', html,
                     reader_mode: false) do |payload|
      markdown = payload.fetch('markdown')
      expect(markdown.scan(/Uncapped Azure comment (\d+)\./).flatten.map(&:to_i)).to eq((1..25).to_a)
      expect(markdown.scan(/Uncapped Azure commit (\d+)\./).flatten.map(&:to_i)).to eq((1..25).to_a)
    end
  end

  it 'supports arbitrary deployment prefixes without hostname ownership' do
    html = azure_devops_fixture.gsub('/organization/public', '/tfs/Collection/public')
                               .gsub('code.example.test', 'devops.example.test')
    url = 'https://devops.example.test/tfs/Collection/public/_git/project/pullrequest/5'

    extract_from_url(url, html, reader_mode: false) do |payload|
      expect(payload).to include('platform' => 'Azure DevOps', 'community' => 'public/project')
      expect(payload.fetch('markdown')).to include('/tfs/Collection/public/_apis/git/repositories/')
    end
  end

  it 'requires independent runtime, route, tab, heading, and prepared public identity evidence' do
    cases = {
      no_runtime: azure_devops_fixture.sub('ms-vss-web-vsts-theme', 'lookalike-theme'),
      no_repos_module: azure_devops_fixture.gsub('Repos/', 'Lookalike/'),
      no_files_tab: azure_devops_fixture.sub('__bolt-tab-files', 'lookalike-files'),
      wrong_heading: azure_devops_fixture.sub('Pull Request 5 Completed', 'Pull Request 6 Completed'),
      private_project: azure_devops_fixture.sub('visibility: "public"', 'visibility: "private"'),
      wrong_repository: azure_devops_fixture.sub('repository: "project"', 'repository: "other"')
    }

    cases.each_value do |html|
      extract_from_url('https://code.example.test/organization/public/_git/project/pullrequest/5', html,
                       reader_mode: false) do |payload|
        expect(payload['platform']).not_to eq('Azure DevOps')
      end
    end
  end

  it 'prepares every opaque commit page with the real Browser state script' do
    browser = FetchUtil::Browser.new
    url = 'https://code.example.test/organization/public/_git/project/pullrequest/5'

    with_url_page(url, azure_devops_fixture) do |page|
      page.evaluate(<<~JS)
        (() => {
          const fixture = window.__fetchUtilAzureDevopsPullRequest;
          fixture.commits[0].comment = "Initial inventory implem";
          fixture.commits[0].commentTruncated = true;
          delete window.__fetchUtilAzureDevopsPullRequest;
          window.__azureRequests = [];
          window.__azureRequestOptions = [];
          window.fetch = (value, options) => {
            const url = new URL(value, location.href);
            window.__azureRequests.push(url.pathname + url.search);
            window.__azureRequestOptions.push(options);
            let payload;
            let token = "";
            if (url.pathname.endsWith('/pullRequests/5')) payload = fixture.metadata;
            else if (url.pathname.endsWith('/threads')) payload = fixture.threads;
            else if (url.pathname.endsWith('/commits/' + fixture.commits[0].commitId)) {
              payload = Object.assign({}, fixture.commits[0], {
                comment: "Initial inventory implementation with complete details",
                commentTruncated: false
              });
              payload.detailOnlyField = "first-detail";
            } else if (url.pathname.endsWith('/commits/' + fixture.commits[1].commitId)) {
              payload = Object.assign({}, fixture.commits[1], {
                comment: "Complete second commit",
                commentTruncated: false,
                detailOnlyField: "second-detail",
                detailUrl: "https://code.example.test/commit-detail",
                unsafeDetailUrl: "javascript:unsafeDetail()"
              });
            }
            else if (url.searchParams.get('continuationToken') === 'opaque-next') {
              payload = { count: 1, value: [fixture.commits[1]] };
            } else {
              payload = { count: 1, value: [fixture.commits[0]] };
              token = 'opaque-next';
            }
            return Promise.resolve({
              ok: true,
              status: 200,
              url: url.href,
              headers: { get: (name) => name.toLowerCase() === 'x-ms-continuationtoken' ? token : null },
              json: () => Promise.resolve(payload)
            });
          };
        })()
      JS

      expect(page.evaluate(browser.send(:azure_devops_pr_state_script))).to include('status' => 'loading')
      state = wait_for_azure_devops_preparation(page)

      expect(state).to include('status' => 'ready', 'threadCount' => 3, 'commentCount' => 4, 'commitCount' => 2)
      expect(state.fetch('commits').first).to include(
        'comment' => 'Initial inventory implementation with complete details', 'commentTruncated' => false,
        'detailOnlyField' => 'first-detail'
      )
      expect(state.fetch('commits').last).to include('detailOnlyField' => 'second-detail')
      detail_requests = page.evaluate('window.__azureRequests').grep(%r{/commits/[0-9a-f]{40}\?api-version=7\.1\z})
      expect(detail_requests).to eq(state.fetch('commits').map do |commit|
        "/organization/public/_apis/git/repositories/11111111-2222-3333-4444-555555555555/commits/" \
          "#{commit.fetch("commitId")}?api-version=7.1"
      end)
      expect(page.evaluate(<<~JS)).to be(true)
        window.__azureRequestOptions.every((options) =>
          options.redirect === "error" && options.signal instanceof AbortSignal
        )
      JS
      payload = extract_payload(page, reader_mode: false)
      expect(payload).to include('platform' => 'Azure DevOps', 'replyCount' => 4)
      expect(payload.fetch('markdown')).to include('Initial inventory implementation with complete details',
                                                   'first-detail', 'second-detail',
                                                   'https://code.example.test/commit-detail')
      expect(payload.fetch('markdown')).not_to include('javascript:unsafeDetail')
    end
  end

  it 'does not publish an incomplete REST preparation' do
    browser = FetchUtil::Browser.new
    url = 'https://code.example.test/organization/public/_git/project/pullrequest/5'

    with_url_page(url, azure_devops_fixture) do |page|
      page.evaluate(<<~JS)
        (() => {
          const fixture = window.__fetchUtilAzureDevopsPullRequest;
          delete window.__fetchUtilAzureDevopsPullRequest;
          window.fetch = (value) => {
            const url = new URL(value, location.href);
            let payload;
            if (url.pathname.endsWith('/pullRequests/5')) payload = fixture.metadata;
            else if (url.pathname.endsWith('/threads')) payload = fixture.threads;
            else payload = { count: 2, value: [fixture.commits[0]] };
            return Promise.resolve({
              ok: true,
              status: 200,
              url: url.href,
              headers: { get: () => null },
              json: () => Promise.resolve(payload)
            });
          };
        })()
      JS

      expect(page.evaluate(browser.send(:azure_devops_pr_state_script))).to include('status' => 'loading')
      state = wait_for_azure_devops_preparation(page)

      expect(state).to include('status' => 'failed', 'reason' => 'incomplete Azure DevOps commits payload')
      payload = extract_payload(page, reader_mode: false)
      expect(payload['platform']).not_to eq('Azure DevOps')
      expect(payload).to include('suspect' => true)
      expect(payload.fetch('warnings')).to include('azure_devops_rest_incomplete')
      expect(payload.fetch('markdown')).to include('Azure DevOps REST conversation preparation failed',
                                                   'incomplete Azure DevOps commits payload')
    end
  end

  it 'marks timed-out REST preparation as an incomplete specialized result' do
    url = 'https://code.example.test/organization/public/_git/project/pullrequest/5'

    with_url_page(url, azure_devops_fixture) do |page|
      page.evaluate(<<~JS)
        window.__fetchUtilAzureDevopsPullRequest.status = "loading";
        window.__fetchUtilAzureDevopsPullRequestAbortController = new AbortController();
      JS
      state = FetchUtil::Browser.new.send(:fail_azure_devops_pr_preparation, page)

      expect(state).to include('status' => 'failed', 'reason' => 'Azure DevOps REST preparation timed out')
      expect(page.evaluate('window.__fetchUtilAzureDevopsPullRequestAbortController')).to be_nil
      payload = extract_payload(page, reader_mode: false)
      expect(payload.fetch('warnings')).to include('azure_devops_rest_incomplete')
      expect(payload.fetch('markdown')).to include('Azure DevOps REST preparation timed out')
    end
  end

  it 'keeps a timeout terminal while pending commit details abort' do
    browser = FetchUtil::Browser.new
    url = 'https://code.example.test/organization/public/_git/project/pullrequest/5'

    with_url_page(url, azure_devops_fixture) do |page|
      page.evaluate(<<~JS)
        (() => {
          const fixture = window.__fetchUtilAzureDevopsPullRequest;
          delete window.__fetchUtilAzureDevopsPullRequest;
          window.__azureDetailAborted = false;
          window.fetch = (value, options) => {
            const url = new URL(value, location.href);
            let payload;
            if (url.pathname.endsWith('/pullRequests/5')) payload = fixture.metadata;
            else if (url.pathname.endsWith('/threads')) payload = fixture.threads;
            else if (url.pathname.endsWith('/commits')) payload = { count: 1, value: [fixture.commits[0]] };
            else {
              return new Promise((_resolve, reject) => {
                options.signal.addEventListener('abort', () => {
                  window.__azureDetailAborted = true;
                  reject(new DOMException('aborted', 'AbortError'));
                });
              });
            }
            return Promise.resolve({
              ok: true,
              status: 200,
              url: url.href,
              headers: { get: () => null },
              json: () => Promise.resolve(payload)
            });
          };
        })()
      JS

      expect(page.evaluate(browser.send(:azure_devops_pr_state_script))).to include('status' => 'loading')
      100.times do
        break if page.evaluate('window.__fetchUtilAzureDevopsPullRequestAbortController != null')

        sleep 0.01
      end
      browser.send(:fail_azure_devops_pr_preparation, page)
      sleep 0.02

      expect(page.evaluate('window.__azureDetailAborted')).to be(true)
      expect(page.evaluate('window.__fetchUtilAzureDevopsPullRequest')).to include(
        'status' => 'failed', 'reason' => 'Azure DevOps REST preparation timed out'
      )
    end
  end

  it 'fails closed on malformed commit detail records' do
    cases = {
      'array_id' => { commitId: ['1111111111111111111111111111111111111111'],
                      comment: 'Complete detail', commentTruncated: false },
      'missing_comment' => { commitId: '1111111111111111111111111111111111111111',
                             commentTruncated: false },
      'truncated' => { commitId: '1111111111111111111111111111111111111111',
                       comment: 'Incomplete detail', commentTruncated: true }
    }
    url = 'https://code.example.test/organization/public/_git/project/pullrequest/5'

    cases.each_value do |detail|
      with_url_page(url, azure_devops_fixture) do |page|
        page.evaluate(<<~JS)
          (() => {
            const fixture = window.__fetchUtilAzureDevopsPullRequest;
            const detail = #{JSON.generate(detail)};
            delete window.__fetchUtilAzureDevopsPullRequest;
            window.fetch = (value) => {
              const url = new URL(value, location.href);
              let payload;
              if (url.pathname.endsWith('/pullRequests/5')) payload = fixture.metadata;
              else if (url.pathname.endsWith('/threads')) payload = fixture.threads;
              else if (url.pathname.endsWith('/commits')) payload = { count: 1, value: [fixture.commits[0]] };
              else payload = detail;
              return Promise.resolve({
                ok: true,
                status: 200,
                url: url.href,
                headers: { get: () => null },
                json: () => Promise.resolve(payload)
              });
            };
          })()
        JS

        expect(page.evaluate(FetchUtil::Browser.new.send(:azure_devops_pr_state_script))).to include('status' => 'loading')
        expect(wait_for_azure_devops_preparation(page)).to include(
          'status' => 'failed', 'reason' => 'incomplete Azure DevOps commit detail'
        )
      end
    end
  end

  it 'aborts sibling commit detail requests after one fails' do
    browser = FetchUtil::Browser.new
    url = 'https://code.example.test/organization/public/_git/project/pullrequest/5'

    with_url_page(url, azure_devops_fixture) do |page|
      page.evaluate(<<~JS)
        (() => {
          const fixture = window.__fetchUtilAzureDevopsPullRequest;
          delete window.__fetchUtilAzureDevopsPullRequest;
          window.__azureSiblingDetailAborted = false;
          window.fetch = (value, options) => {
            const url = new URL(value, location.href);
            let payload;
            if (url.pathname.endsWith('/pullRequests/5')) payload = fixture.metadata;
            else if (url.pathname.endsWith('/threads')) payload = fixture.threads;
            else if (url.pathname.endsWith('/commits')) payload = { count: 2, value: fixture.commits };
            else if (url.pathname.endsWith('/commits/' + fixture.commits[0].commitId)) {
              payload = { commitId: fixture.commits[0].commitId, commentTruncated: false };
            } else {
              return new Promise((_resolve, reject) => {
                options.signal.addEventListener('abort', () => {
                  window.__azureSiblingDetailAborted = true;
                  reject(new DOMException('aborted', 'AbortError'));
                });
              });
            }
            return Promise.resolve({
              ok: true,
              status: 200,
              url: url.href,
              headers: { get: () => null },
              json: () => Promise.resolve(payload)
            });
          };
        })()
      JS

      expect(page.evaluate(browser.send(:azure_devops_pr_state_script))).to include('status' => 'loading')
      expect(wait_for_azure_devops_preparation(page)).to include(
        'status' => 'failed', 'reason' => 'incomplete Azure DevOps commit detail'
      )
      expect(page.evaluate('window.__azureSiblingDetailAborted')).to be(true)
    end
  end

  it 'fails closed on untrusted REST routing and pagination responses' do
    cases = {
      'cross_origin' => 'cross-origin Azure DevOps API response',
      'invalid_commit_id' => 'invalid Azure DevOps commit record',
      'invalid_repository_id' => 'Azure DevOps API pull request identity mismatch',
      'repository_origin' => 'Azure DevOps API repository origin mismatch',
      'thread_continuation' => 'unexpected Azure DevOps threads continuation',
      'repeated_token' => 'repeated Azure DevOps continuation token'
    }
    url = 'https://code.example.test/organization/public/_git/project/pullrequest/5'

    cases.each do |mode, reason|
      with_url_page(url, azure_devops_fixture) do |page|
        page.evaluate(<<~JS)
          (() => {
            const mode = #{JSON.generate(mode)};
            const fixture = window.__fetchUtilAzureDevopsPullRequest;
            if (mode === "repository_origin") fixture.metadata.repository.webUrl = "https://other.example.test/repository";
            if (mode === "invalid_repository_id") fixture.metadata.repository.id = "repo-id";
            delete window.__fetchUtilAzureDevopsPullRequest;
            window.fetch = (value) => {
              const url = new URL(value, location.href);
              let payload;
              if (mode === "invalid_commit_id") fixture.commits[0].commitId = "not-a-commit";
              if (url.pathname.endsWith('/pullRequests/5')) payload = fixture.metadata;
              else if (url.pathname.endsWith('/threads')) payload = fixture.threads;
              else payload = { count: 1, value: [fixture.commits[0]] };
              const commits = url.pathname.endsWith('/commits');
              const threads = url.pathname.endsWith('/threads');
              const token = (mode === "repeated_token" && commits) ||
                (mode === "thread_continuation" && threads) ? "opaque-repeat" : null;
              const responseUrl = mode === "cross_origin" ? "https://other.example.test/api" : url.href;
              return Promise.resolve({
                ok: true,
                status: 200,
                url: responseUrl,
                headers: { get: (name) => name.toLowerCase() === 'x-ms-continuationtoken' ? token : null },
                json: () => Promise.resolve(payload)
              });
            };
          })()
        JS

        expect(page.evaluate(FetchUtil::Browser.new.send(:azure_devops_pr_state_script))).to include('status' => 'loading')
        state = wait_for_azure_devops_preparation(page)

        expect(state).to include('status' => 'failed', 'reason' => reason)
        payload = extract_payload(page, reader_mode: false)
        expect(payload.fetch('warnings')).to include('azure_devops_rest_incomplete')
      end
    end
  end
end
