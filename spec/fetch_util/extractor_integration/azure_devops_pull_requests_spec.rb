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
        'comment' => 'Initial inventory implementation with complete details', 'commentTruncated' => false
      )
      expect(page.evaluate('window.__azureRequests').grep(/commits/).length).to eq(3)
      expect(page.evaluate('window.__azureRequestOptions.every((options) => options.redirect === "error")')).to be(true)
      payload = extract_payload(page, reader_mode: false)
      expect(payload).to include('platform' => 'Azure DevOps', 'replyCount' => 4)
      expect(payload.fetch('markdown')).to include('Initial inventory implementation with complete details')
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
      page.evaluate('window.__fetchUtilAzureDevopsPullRequest.status = "loading"')
      state = FetchUtil::Browser.new.send(:fail_azure_devops_pr_preparation, page)

      expect(state).to include('status' => 'failed', 'reason' => 'Azure DevOps REST preparation timed out')
      payload = extract_payload(page, reader_mode: false)
      expect(payload.fetch('warnings')).to include('azure_devops_rest_incomplete')
      expect(payload.fetch('markdown')).to include('Azure DevOps REST preparation timed out')
    end
  end

  it 'fails closed on untrusted REST routing and pagination responses' do
    cases = {
      'cross_origin' => 'cross-origin Azure DevOps API response',
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
            delete window.__fetchUtilAzureDevopsPullRequest;
            window.fetch = (value) => {
              const url = new URL(value, location.href);
              let payload;
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
