# frozen_string_literal: true

require "open3"
require "fileutils"
require "rubygems/package"
require "tmpdir"
require_relative "../script/extract_asset_state"

RSpec.describe "extract asset bundle" do
  def project_root
    File.expand_path("..", __dir__)
  end

  def run_build_script(*args, root: project_root, env: {})
    script = File.join(root, "script", "build_extract_assets.rb")
    Open3.capture3(env, RbConfig.ruby, script, *args, chdir: root)
  end

  def with_asset_project(manifest:, files:)
    Dir.mktmpdir("fetch_util_assets") do |root|
      script_dir = File.join(root, "script")
      source_root = File.join(root, "websieve")
      FileUtils.mkdir_p([script_dir, source_root, File.join(root, "lib", "fetch_util", "assets")])
      FileUtils.cp(File.join(project_root, "script", "build_extract_assets.rb"), script_dir)
      FileUtils.cp(File.join(project_root, "script", "extract_asset_state.rb"), script_dir)
      FileUtils.cp(File.join(project_root, "package.json"), root)
      File.write(File.join(source_root, "manifest.txt"), manifest)

      files.each do |path, contents|
        file = File.join(source_root, path)
        FileUtils.mkdir_p(File.dirname(file))
        File.write(file, contents)
      end

      yield root
    end
  end

  def install_fake_terser(root, version: "5.51.2")
    binary = File.join(root, "node_modules", ".bin", "terser")
    package = File.join(root, "node_modules", "terser", "package.json")
    FileUtils.mkdir_p([File.dirname(binary), File.dirname(package)])
    File.write(binary, "")
    FileUtils.chmod(0o755, binary)
    File.write(package, JSON.generate("version" => version))
    binary
  end

  def copy_gemspec_support(root)
    script_dir = File.join(root, "script")
    FileUtils.mkdir_p(script_dir)
    FileUtils.cp(File.join(project_root, "fetch_util.gemspec"), root)
    FileUtils.cp(File.join(project_root, "script", "extract_asset_state.rb"), script_dir)
  end

  it "verifies the checked-in extract.js is current" do
    stdout, stderr, status = run_build_script("--check")

    expect(status.success?).to be(true), [stdout, stderr].reject(&:empty?).join("\n")
    expect(stdout).to include("Verified")
  end

  it "keeps one manifest owner for every top-level callable" do
    source_root = File.join(project_root, "websieve")
    entries = File.readlines(File.join(source_root, "manifest.txt"), chomp: true)
    contents = entries.map { |entry| File.read(File.join(source_root, entry)) }

    expect(FetchUtil::ExtractAssetState.duplicate_top_level_callables(entries, contents)).to be_empty
    expect(entries.filter do |entry|
      File.read(File.join(source_root, entry)).match?(/^\s*function commentOnlyRoot\b/)
    end).to eq(["extractors/article/roots.js"])
  end

  it "ignores same-named nested callable declarations" do
    entries = %w[first.js second.js]
    contents = [
      "function firstOwner() {\n  function push() {}\n}\n",
      "function secondOwner() {\n  function push() {}\n}\n"
    ]

    expect(FetchUtil::ExtractAssetState.duplicate_top_level_callables(entries, contents)).to be_empty
  end

  it "ignores nested callables without named outer declarations" do
    entries = %w[object.js conditional.js]
    contents = [
      <<~JS,
        // File-level comments do not establish source indentation.
          global.One = {
            run: function() {
              function push() {}
            }
          };
      JS
      "  if (global.enabled) {\n    function push() {}\n  }\n"
    ]

    expect(FetchUtil::ExtractAssetState.duplicate_top_level_callables(entries, contents)).to be_empty
  end

  it "recognizes duplicate top-level callable forms" do
    entries = %w[function.js binding.js class.js]
    contents = [
      "function sharedOwner() {}\n",
      "const sharedOwner = async (value) => value;\n",
      "class sharedOwner {}\n"
    ]

    expect(FetchUtil::ExtractAssetState.duplicate_top_level_callables(entries, contents)).to eq(
      "sharedOwner" => %w[function.js:1 binding.js:1 class.js:1]
    )
  end

  it "recognizes duplicate async and generator declarations" do
    entries = %w[async.js generator.js async_generator.js]
    contents = [
      "  async function sharedOwner() {}\n",
      "  function* sharedOwner() {}\n",
      "  async function * sharedOwner() {}\n"
    ]

    expect(FetchUtil::ExtractAssetState.duplicate_top_level_callables(entries, contents)).to eq(
      "sharedOwner" => %w[async.js:1 generator.js:1 async_generator.js:1]
    )
  end

  it "ignores block comment indentation when locating top-level declarations" do
    entries = %w[first.js second.js]
    contents = entries.map do
      "/*\nAn unstarred comment continuation.\n*/\n  function sharedOwner() {}\n"
    end

    expect(FetchUtil::ExtractAssetState.duplicate_top_level_callables(entries, contents)).to eq(
      "sharedOwner" => %w[first.js:4 second.js:4]
    )
  end

  it "registers generic portal homepages once in the source graph" do
    registrations = Dir[File.join(project_root, "websieve", "**", "*.js")].sum do |path|
      File.read(path).scan(/^\s+registerGenericPortalHomepageProfiles\(\);$/).length
    end

    expect(registrations).to eq(1)
  end

  it "keeps warning policy delegates ordered before the entrypoint" do
    source_root = File.join(project_root, "websieve")
    manifest = File.readlines(File.join(source_root, "manifest.txt"), chomp: true)
    warning_paths = manifest.select { |path| path.start_with?("classifiers/warnings/") }

    expected_warning_paths = %w[
      classifiers/warnings/homepage_docs.js
      classifiers/warnings/access.js
      classifiers/warnings/content_integrity.js
      classifiers/warnings/index.js
    ]
    expect(warning_paths.last(4)).to eq(expected_warning_paths)
    expect(warning_paths.uniq).to eq(warning_paths)
    expect(File.read(File.join(source_root, "classifiers/warnings/index.js"))).to include("reasons = reasons.concat(accessWarningReasons")
    expect(File.read(File.join(source_root, "classifiers/warnings/index.js"))).to include("reasons = reasons.concat(contentIntegrityWarningReasons")

    {
      "credibleHomepageListFeed" => "classifiers/warnings/homepage_docs.js",
      "credibleDocsIndexReferenceList" => "classifiers/warnings/homepage_docs.js",
      "accessWarningReasons" => "classifiers/warnings/access.js",
      "contentIntegrityWarningReasons" => "classifiers/warnings/content_integrity.js",
      "suspicionReasons" => "classifiers/warnings/index.js"
    }.each do |function, expected_path|
      definitions = warning_paths.select do |path|
        File.read(File.join(source_root, path)).match?(/function\s+#{Regexp.escape(function)}\s*\(/)
      end
      expect(definitions).to eq([expected_path]), function
    end
  end

  it "places shared list rendering and glossary scoring before their consumers" do
    source_root = File.join(project_root, "websieve")
    manifest = File.readlines(File.join(source_root, "manifest.txt"), chomp: true)
    list_source = File.read(File.join(source_root, "markdown/lists.js"))
    expect(list_source).to include("var listMarkdown = function(items)", "item.author", "item.score", "item.replyCount", "item.community", "function cardField")
    expect(list_source.index("function cardField")).to be < list_source.index("var listMarkdown = function(items)")
    list_definitions = Dir[File.join(source_root, "**", "*.js")].sum do |path|
      File.read(path).scan(/(?:function\s+listMarkdown\s*\(|var\s+listMarkdown\s*=\s*function\s*\()/).length
    end
    expect(list_definitions).to eq(1)
    expect(Dir[File.join(source_root, "**", "*.js")].sum { |path| File.read(path).scan(/function\s+definitionReferenceMetadataScore\s*\(/).length }).to eq(1)
    expect(File.read(File.join(source_root, "extractors/lists/generic/card_evidence.js"))).not_to include("function listMarkdown")
    expect(File.read(File.join(source_root, "core/metadata/structured_data.js"))).not_to include("function definitionReferenceMetadataScore")
    detection_source = File.read(File.join(source_root, "extractors/glossary/detection.js"))
    expect(detection_source.index("function definitionReferenceMetadataScore")).to be < detection_source.index("function glossaryLikePage")

    list_index = manifest.index("markdown/lists.js")
    expect(list_index).to be < manifest.index("core/metadata/content_results.js")
    Dir[File.join(source_root, "**", "*.js")].each do |path|
      next if path.end_with?("/markdown/lists.js")
      next unless File.read(path).include?("listMarkdown(")

      expect(list_index).to be < manifest.index(path.delete_prefix("#{source_root}/"))
    end
    expect(manifest.index("extractors/glossary/detection.js")).to be < manifest.index("extractors/glossary/extraction.js")
  end

  it "defines list helpers before the parser-sensitive renderer snapshot" do
    list_source = File.read(File.join(project_root, "websieve", "markdown", "lists.js"))
    renderer_index = list_source.index("var listMarkdown = function(items)")

    expect(list_source.index("function listSupplementalDetail")).to be < renderer_index
    expect(list_source.index("function cardField")).to be < renderer_index
  end

  it "loads browsable inventories and GitHub thread primitives before their consumers" do
    source_root = File.join(project_root, "websieve")
    manifest = File.readlines(File.join(source_root, "manifest.txt"), chomp: true)
    inventory_path = "markdown/inventory.js"
    thread_entries_path = "profiles/community/forge_thread_entries.js"
    shared_path = "profiles/community/github_thread_shared.js"
    thread_path = "profiles/community/github_threads.js"
    file_resources_path = "profiles/community/github_pull_file_resources.js"
    resources_path = "profiles/community/github_pull_resources.js"
    gitlab_shared_path = "profiles/community/gitlab_thread_shared.js"
    gitlab_thread_path = "profiles/community/gitlab_threads.js"
    gitlab_resource_shared_path = "profiles/community/gitlab_merge_request_resource_shared.js"
    gitlab_diff_path = "profiles/community/gitlab_merge_request_diffs.js"
    gitlab_resources_path = "profiles/community/gitlab_merge_request_resources.js"
    gitea_shared_path = "profiles/community/gitea_family_shared.js"
    gitea_resource_shared_path = "profiles/community/gitea_family_pull_resource_shared.js"
    gitea_commits_path = "profiles/community/gitea_family_pull_commits.js"
    gitea_files_path = "profiles/community/gitea_family_pull_files.js"
    gitea_resources_path = "profiles/community/gitea_family_pull_resources.js"
    gitea_entries_path = "profiles/community/gitea_family_thread_entries.js"
    gitea_thread_path = "profiles/community/gitea_family_threads.js"
    bitbucket_shared_path = "profiles/community/bitbucket_cloud_shared.js"
    bitbucket_api_shared_path = "profiles/community/bitbucket_cloud_api_shared.js"
    bitbucket_activity_path = "profiles/community/bitbucket_cloud_pull_activity.js"
    bitbucket_statuses_path = "profiles/community/bitbucket_cloud_pull_statuses.js"
    bitbucket_diff_files_path = "profiles/community/bitbucket_cloud_pull_diff_files.js"
    bitbucket_diffs_path = "profiles/community/bitbucket_cloud_pull_diffs.js"
    bitbucket_resources_path = "profiles/community/bitbucket_cloud_pull_resources.js"
    bitbucket_thread_path = "profiles/community/bitbucket_cloud_threads.js"
    pagure_shared_path = "profiles/community/pagure_shared.js"
    pagure_thread_path = "profiles/community/pagure_threads.js"
    pagure_pull_path = "profiles/community/pagure_pull_requests.js"
    sourcehut_git_shared_path = "profiles/community/sourcehut_git_shared.js"
    sourcehut_git_commit_path = "profiles/community/sourcehut_git_commits.js"
    sourcehut_shared_path = "profiles/community/sourcehut_todo_shared.js"
    sourcehut_thread_path = "profiles/community/sourcehut_todo_threads.js"
    sourcehut_lists_shared_path = "profiles/community/sourcehut_lists_shared.js"
    sourcehut_lists_entries_path = "profiles/community/sourcehut_lists_entries.js"
    sourcehut_lists_patchset_path = "profiles/community/sourcehut_lists_patchsets.js"
    sourcehut_lists_thread_path = "profiles/community/sourcehut_lists_threads.js"
    azure_shared_path = "profiles/community/azure_devops_pr_shared.js"
    azure_entries_path = "profiles/community/azure_devops_pr_entries.js"
    azure_thread_path = "profiles/community/azure_devops_pr_threads.js"
    gerrit_shared_path = "profiles/community/gerrit_change_shared.js"
    gerrit_entries_path = "profiles/community/gerrit_change_entries.js"
    gerrit_resource_shared_path = "profiles/community/gerrit_change_resource_shared.js"
    gerrit_resource_entries_path = "profiles/community/gerrit_change_resource_entries.js"
    gerrit_resources_path = "profiles/community/gerrit_change_resources.js"
    gerrit_thread_path = "profiles/community/gerrit_change_threads.js"

    expect(File.read(File.join(source_root, inventory_path))).to include("function browsableInventory")
    expect(File.read(File.join(source_root, thread_entries_path))).to include("function deduplicateForgeThreadPermalinks")
    expect(File.read(File.join(source_root, shared_path))).to include("function githubResourceRoute")
    expect(manifest.index(inventory_path)).to be < manifest.index(thread_path)
    expect(manifest.index(thread_entries_path)).to be < manifest.index(thread_path)
    expect(manifest.index(thread_entries_path)).to be < manifest.index(gitlab_thread_path)
    expect(manifest.index(thread_entries_path)).to be < manifest.index(gitea_entries_path)
    expect(manifest.index(shared_path)).to be < manifest.index(thread_path)
    expect(manifest.index(thread_path)).to be < manifest.index(file_resources_path)
    expect(manifest.index(file_resources_path)).to be < manifest.index(resources_path)
    expect(manifest.index(resources_path)).to be < manifest.index(gitlab_shared_path)
    expect(manifest.index(gitlab_shared_path)).to be < manifest.index(gitlab_thread_path)
    expect(File.read(File.join(source_root, gitlab_shared_path))).to include("function gitlabResourceRoute")
    expect(File.read(File.join(source_root, gitlab_thread_path))).to include("function gitlabThreadContent")
    expect(manifest.index(gitlab_thread_path)).to be < manifest.index(gitlab_resource_shared_path)
    expect(manifest.index(gitlab_resource_shared_path)).to be < manifest.index(gitlab_diff_path)
    expect(manifest.index(gitlab_diff_path)).to be < manifest.index(gitlab_resources_path)
    expect(File.read(File.join(source_root, gitlab_resource_shared_path))).to include("function gitlabResourceResult")
    expect(File.read(File.join(source_root, gitlab_resources_path))).to include("function gitlabMergeRequestResourceContent")
    expect(File.read(File.join(source_root, gitea_shared_path))).to include("function giteaFamilyRoute")
    expect(File.read(File.join(source_root, gitea_resource_shared_path))).to include("function giteaFamilyPullResourceRoute")
    expect(File.read(File.join(source_root, gitea_commits_path))).to include("function giteaFamilyPullCommitsContent")
    expect(File.read(File.join(source_root, gitea_files_path))).to include("function giteaFamilyPullFilesContent")
    expect(File.read(File.join(source_root, gitea_resources_path))).to include("function giteaFamilyPullResourceContent")
    expect(File.read(File.join(source_root, gitea_entries_path))).to include("function giteaFamilyThreadEntry")
    expect(File.read(File.join(source_root, gitea_thread_path))).to include("function giteaFamilyThreadContent")
    expect(File.read(File.join(source_root, bitbucket_shared_path))).to include("function bitbucketCloudPullRequestRoute")
    expect(File.read(File.join(source_root, bitbucket_shared_path))).to include("function bitbucketCloudSafeSupplementalValue")
    expect(File.read(File.join(source_root, bitbucket_api_shared_path))).to include("function bitbucketCloudPullApiRouteFromPath")
    expect(File.read(File.join(source_root, bitbucket_activity_path))).to include("function bitbucketCloudPullActivityContent")
    expect(File.read(File.join(source_root, bitbucket_statuses_path))).to include("function bitbucketCloudPullStatusesContent")
    expect(File.read(File.join(source_root, bitbucket_diff_files_path))).to include("function bitbucketCloudDiffFileSections")
    expect(File.read(File.join(source_root, bitbucket_diffs_path))).to include("function bitbucketCloudPullDiffContent")
    expect(File.read(File.join(source_root, bitbucket_resources_path))).to include("function bitbucketCloudPullResourceContent")
    expect(File.read(File.join(source_root, bitbucket_thread_path))).to include("function bitbucketCloudPullRequestContent")
    expect(File.read(File.join(source_root, pagure_shared_path))).to include("function pagureIssueRoute")
    expect(File.read(File.join(source_root, pagure_shared_path))).to include("function pagureThreadEntrySections")
    expect(File.read(File.join(source_root, pagure_thread_path))).to include("function pagureIssueContent")
    expect(File.read(File.join(source_root, pagure_pull_path))).to include("function pagurePullRequestContent")
    expect(File.read(File.join(source_root, sourcehut_git_shared_path))).to include("function sourcehutGitCommitRoute")
    expect(File.read(File.join(source_root, sourcehut_git_commit_path))).to include("function sourcehutGitCommitContent")
    expect(File.read(File.join(source_root, sourcehut_shared_path))).to include("function sourcehutTodoRoute")
    expect(File.read(File.join(source_root, sourcehut_thread_path))).to include("function sourcehutTodoTicketContent")
    expect(File.read(File.join(source_root, sourcehut_lists_shared_path))).to include("function sourcehutListsPatchsetRoute")
    expect(File.read(File.join(source_root, sourcehut_lists_entries_path))).to include("function sourcehutListsPatchRecords")
    expect(File.read(File.join(source_root, sourcehut_lists_patchset_path))).to include("function sourcehutListsPatchsetContent")
    expect(File.read(File.join(source_root, sourcehut_lists_thread_path))).to include("function sourcehutListsArchiveThreadContent")
    expect(File.read(File.join(source_root, azure_shared_path))).to include("function azureDevopsPullRequestRoute")
    expect(File.read(File.join(source_root, azure_entries_path))).to include("function azureDevopsThreadSections")
    expect(File.read(File.join(source_root, azure_thread_path))).to include("function azureDevopsPullRequestContent")
    expect(File.read(File.join(source_root, gerrit_shared_path))).to include("function gerritChangeRoute")
    expect(File.read(File.join(source_root, gerrit_shared_path))).to include("function gerritChangeFileInventoryEntries")
    expect(File.read(File.join(source_root, gerrit_entries_path))).to include("function gerritTimelineRecords")
    expect(File.read(File.join(source_root, gerrit_resource_shared_path))).to include("function gerritFileResourceRoute")
    expect(File.read(File.join(source_root, gerrit_resource_shared_path))).not_to include("function gerritFileInventoryEntries")
    expect(File.read(File.join(source_root, gerrit_resource_entries_path))).to include("function gerritDiffTextLines")
    expect(File.read(File.join(source_root, gerrit_resources_path))).to include("function gerritFileResourceContent")
    expect(File.read(File.join(source_root, gerrit_thread_path))).to include("function gerritChangeContent")
    expect(manifest.index(gitlab_resources_path)).to be < manifest.index(gitea_shared_path)
    expect(manifest.index(gitea_shared_path)).to be < manifest.index(gitea_resource_shared_path)
    expect(manifest.index(gitea_resource_shared_path)).to be < manifest.index(gitea_commits_path)
    expect(manifest.index(gitea_commits_path)).to be < manifest.index(gitea_files_path)
    expect(manifest.index(gitea_files_path)).to be < manifest.index(gitea_resources_path)
    expect(manifest.index(gitea_resources_path)).to be < manifest.index(gitea_entries_path)
    expect(manifest.index(gitea_entries_path)).to be < manifest.index(gitea_thread_path)
    expect(manifest.index(gitea_thread_path)).to be < manifest.index(bitbucket_shared_path)
    expect(manifest.index(bitbucket_shared_path)).to be < manifest.index(bitbucket_api_shared_path)
    expect(manifest.index(bitbucket_api_shared_path)).to be < manifest.index(bitbucket_activity_path)
    expect(manifest.index(bitbucket_activity_path)).to be < manifest.index(bitbucket_statuses_path)
    expect(manifest.index(bitbucket_statuses_path)).to be < manifest.index(bitbucket_diff_files_path)
    expect(manifest.index(bitbucket_diff_files_path)).to be < manifest.index(bitbucket_diffs_path)
    expect(manifest.index(bitbucket_diffs_path)).to be < manifest.index(bitbucket_resources_path)
    expect(manifest.index(bitbucket_resources_path)).to be < manifest.index(bitbucket_thread_path)
    expect(manifest.index(bitbucket_thread_path)).to be < manifest.index("profiles/register.js")
    expect(manifest.index(bitbucket_thread_path)).to be < manifest.index(pagure_shared_path)
    expect(manifest.index(pagure_shared_path)).to be < manifest.index(pagure_thread_path)
    expect(manifest.index(pagure_thread_path)).to be < manifest.index(pagure_pull_path)
    expect(manifest.index(pagure_pull_path)).to be < manifest.index("profiles/register.js")
    expect(manifest.index(pagure_pull_path)).to be < manifest.index(sourcehut_git_shared_path)
    expect(manifest.index(sourcehut_git_shared_path)).to be < manifest.index(sourcehut_git_commit_path)
    expect(manifest.index(sourcehut_git_commit_path)).to be < manifest.index(sourcehut_shared_path)
    expect(manifest.index(sourcehut_shared_path)).to be < manifest.index(sourcehut_thread_path)
    expect(manifest.index(sourcehut_thread_path)).to be < manifest.index(sourcehut_lists_shared_path)
    expect(manifest.index(sourcehut_lists_shared_path)).to be < manifest.index(sourcehut_lists_entries_path)
    expect(manifest.index(sourcehut_lists_entries_path)).to be < manifest.index(sourcehut_lists_patchset_path)
    expect(manifest.index(sourcehut_lists_patchset_path)).to be < manifest.index(sourcehut_lists_thread_path)
    expect(manifest.index(sourcehut_lists_thread_path)).to be < manifest.index(azure_shared_path)
    expect(manifest.index(azure_shared_path)).to be < manifest.index(azure_entries_path)
    expect(manifest.index(azure_entries_path)).to be < manifest.index(azure_thread_path)
    expect(manifest.index(azure_thread_path)).to be < manifest.index(gerrit_shared_path)
    expect(manifest.index(gerrit_shared_path)).to be < manifest.index(gerrit_entries_path)
    expect(manifest.index(gerrit_entries_path)).to be < manifest.index(gerrit_resource_shared_path)
    expect(manifest.index(gerrit_resource_shared_path)).to be < manifest.index(gerrit_resource_entries_path)
    expect(manifest.index(gerrit_resource_entries_path)).to be < manifest.index(gerrit_resources_path)
    expect(manifest.index(gerrit_resources_path)).to be < manifest.index(gerrit_thread_path)
    expect(manifest.index(gerrit_thread_path)).to be < manifest.index("profiles/register.js")
    expect(manifest.index(gitlab_resources_path)).to be < manifest.index("profiles/register.js")
    expect(manifest.index(resources_path)).to be < manifest.index("profiles/register.js")
  end

  it "keeps relocated definitions before their consumers" do
    source_root = File.join(project_root, "websieve")
    manifest = File.readlines(File.join(source_root, "manifest.txt"), chomp: true)
    sources = manifest.to_h { |path| [path, File.read(File.join(source_root, path))] }

    expect(sources.values.join.scan(/function\s+mwananchiPrePageTextCleanup\s*\(/).length).to eq(1)
    expect(sources.values.join.scan(/function\s+genericHomepageLeadRoot\s*\(/).length).to eq(1)
    expect(sources.values.join.scan(/function\s+registerGenericPortalHomepageProfiles\s*\(/).length).to eq(1)
    expect(manifest.index("profiles/news/mwananchi.js")).to be < manifest.index("boot/pipeline_helpers.js")
    expect(manifest.index("systems/news_engines/generic_portal_homepages.js")).to be < manifest.index("profiles/news/news_homepages.js")

    pipeline = sources.fetch("boot/pipeline_helpers.js")
    extract_api = sources.fetch("boot/extract_api.js")
    generic_portal = sources.fetch("systems/news_engines/generic_portal_homepages.js")
    news_homepages = sources.fetch("profiles/news/news_homepages.js")
    expect(pipeline).not_to include("function mwananchiPrePageTextCleanup")
    expect(extract_api.index("mwananchiPrePageTextCleanup")).to be > 0
    expect(generic_portal.index("function genericHomepageLeadRoot")).to be < generic_portal.index("function genericPortalHomepageContent")
    expect(news_homepages.index("function registerGenericPortalHomepageProfiles")).to be < news_homepages.index("function registerNewsHomepageProfiles")
  end

  it "keeps visibility-pruned cloning in the shared DOM owner" do
    source_root = File.join(project_root, "websieve")
    manifest = File.readlines(File.join(source_root, "manifest.txt"), chomp: true)
    base_path = "core/dom/base.js"
    list_path = "extractors/lists/generic/flat_extraction.js"
    base_source = File.read(File.join(source_root, base_path))
    list_source = File.read(File.join(source_root, list_path))

    expect(manifest.index(base_path)).to be < manifest.index(list_path)
    expect(base_source).to include("function pruneHiddenClone", "function visibilityPrunedClone")
    expect(list_source).to include("pruneHiddenClone(node, clone)")
    expect(list_source).not_to include("function pruneHiddenListClone")
  end

  it "loads the shared generic list card boundary before its consumers" do
    source_root = File.join(project_root, "websieve")
    manifest = File.readlines(File.join(source_root, "manifest.txt"), chomp: true)
    ownership_path = "classifiers/list_pages/card_ownership.js"
    renderer_path = "markdown/lists.js"
    dominance_path = "classifiers/list_pages/dominance.js"
    card_evidence_path = "extractors/lists/generic/card_evidence.js"
    flat_extraction_path = "extractors/lists/generic/flat_extraction.js"
    section_discovery_path = "extractors/lists/generic/section_discovery.js"
    sources = [ownership_path, renderer_path, dominance_path, card_evidence_path, flat_extraction_path, section_discovery_path].to_h do |path|
      [path, File.read(File.join(source_root, path))]
    end

    expect(sources.values.join.scan(/function\s+genericListCardSelector\s*\(/).length).to eq(1)
    [renderer_path, dominance_path, card_evidence_path, flat_extraction_path, section_discovery_path].each do |consumer_path|
      expect(manifest.index(ownership_path)).to be < manifest.index(consumer_path)
    end
    expect(sources.fetch(ownership_path)).to include(
      "function genericListCardBoundary",
      "function genericListPresentationCardNode",
      "function closestGenericListCard",
      "function genericListFieldBoundary",
      "function closestGenericListFieldCard",
      "function genericListContextCard",
      "function genericListNestedCardReplaces",
      'fallback.matches("tr")'
    )
    expect(sources.fetch(dominance_path)).to include(
      "genericListCardText(detailSource)",
      "listCandidateScore(text, url, detail, container || link.parentElement, context)"
    )
    expect(sources.fetch(card_evidence_path)).to include(
      "closestGenericListFieldCard(node)",
      'card.matches("tr")',
      "genericListNestedCardReplaces(card, nested)"
    )
    expect(sources.fetch(flat_extraction_path)).to include("closestGenericListCard(node)")
    expect(sources.fetch(section_discovery_path)).to include(
      "customSelector || genericListCardSelector()",
      "allCards.filter(genericListCardBoundary)",
      "genericListNestedCardReplaces(card, nested)"
    )
  end

  it "keeps MediaWiki extraction in its canonical CMS owner" do
    source_root = File.join(project_root, "websieve")
    sources = Dir[File.join(source_root, "**", "*.js")].to_h do |path|
      [path.delete_prefix("#{source_root}/"), File.read(path)]
    end
    combined_source = sources.values.join

    expect(combined_source.scan(/function\s+mediaWikiContent\s*\(/).length).to eq(1)
    expect(combined_source.scan(/registerHostAwareProfile\(true, mediaWikiContent\);/).length).to eq(1)
    expect(sources.fetch("profiles/families/community_wikis.js")).not_to include("mediaWikiContent")
    expect(sources.fetch("systems/cms/mediawiki.js")).to include(
      "function mediaWikiContent(metadata)",
      "registerHostAwareProfile(true, mediaWikiContent);"
    )
  end

  it "keeps docs and Unidad Editorial modules in their ownership slots" do
    source_root = File.join(project_root, "websieve")
    manifest = File.readlines(File.join(source_root, "manifest.txt"), chomp: true)

    antora_index = manifest.index("systems/docs/generic/antora.js")
    expect(antora_index).to be < manifest.index("systems/docs/generic/index.js")
    expect(File).to exist(File.join(source_root, "systems/docs/generic/antora.js"))
    expect(File).not_to exist(File.join(source_root, "systems/antora.js"))

    unidad_path = "profiles/news/europe/southern/spain/unidad_editorial.js"
    unidad_index = manifest.index(unidad_path)
    marca_index = manifest.index("profiles/news/europe/southern/spain/marca.js")
    engine_path = "systems/news_engines/unidad_editorial_engine.js"
    expect(unidad_index).to eq(marca_index - 1)
    expect(unidad_index).to be > manifest.index("profiles/register.js")
    expect(File).to exist(File.join(source_root, unidad_path))
    expect(File).to exist(File.join(source_root, engine_path))
    expect(File).not_to exist(File.join(source_root, "systems/news_engines/unidad_editorial.js"))
  end

  it "loads Markdown cleanup helpers before their consumer" do
    source_root = File.join(project_root, "websieve")
    manifest = File.readlines(File.join(source_root, "manifest.txt"), chomp: true)
    fence_path = "core/markdown_cleanup/fences.js"
    duplicate_path = "core/markdown_cleanup/duplicates.js"
    cleanup_path = "core/markdown_cleanup.js"

    expect(manifest.index(fence_path)).to be < manifest.index(cleanup_path)
    expect(manifest.index(duplicate_path)).to be_between(manifest.index(fence_path), manifest.index(cleanup_path)).exclusive
    expect(File.read(File.join(source_root, fence_path))).to include("function protectMarkdownFences")
    expect(File.read(File.join(source_root, duplicate_path))).to include("function collapseMarkdownDuplicateLines")
    expect(File.read(File.join(source_root, cleanup_path))).to include("protectMarkdownFences(markdown)")
    expect(File.read(File.join(source_root, cleanup_path))).to include("collapseMarkdownDuplicateLines(result)")
    expect(File.read(File.join(source_root, cleanup_path))).to include("restoreMarkdownFences(")
  end

  it "keeps Websieve source modules below 300 lines" do
    source_root = File.join(project_root, "websieve")
    manifest = File.readlines(File.join(source_root, "manifest.txt"), chomp: true)
    oversized = manifest.filter_map do |path|
      line_count = File.readlines(File.join(source_root, path)).length
      [path, line_count] if line_count >= 300
    end

    expect(oversized).to eq([])
  end

  it "preserves social profile registration precedence" do
    source_root = File.join(project_root, "websieve")
    manifest = File.readlines(File.join(source_root, "manifest.txt"), chomp: true)
    register_path = "profiles/register.js"
    register_index = manifest.index(register_path)
    paths_before_register = manifest.take(register_index)
    register_source = File.read(File.join(source_root, register_path))
    calls = register_source.scan(/^\s*(register[A-Z]\w*)\(\);$/).flatten

    expect(calls).to eq(%w[
                          registerCommunityWikiLeadProfiles
                          registerPinterestSearchProfile
                          registerTikTokProfile
                          registerEbaySearchProfile
                          registerGlassdoorProfiles
                          registerRingierAxelSpringerProfiles
                          registerMediaCommerceLeadProfiles
                          registerNewsHomepageProfiles
                          registerWpHomepageProfile
                          registerOnetHomepageProfile
                          registerZeitProfiles
                          registerBookingProfiles
                          registerAcademicPublisherProfiles
                          registerAcademicPreprintProfiles
                          registerCsdnProfiles
                          registerSubstackProfiles
                          registerPackageRegistryProfiles
                          registerStatuspageProfiles
                          registerLegalReferenceProfiles
                          registerWykopProfiles
                          registerRailsRdocProfiles
                          registerRepoHostProfiles
                          registerGitHubThreadProfiles
                          registerGitHubPullResourceProfiles
                          registerGitLabThreadProfiles
                          registerGitLabMergeRequestResourceProfiles
                          registerGiteaFamilyPullResourceProfiles
                          registerGiteaFamilyThreadProfiles
                          registerBitbucketCloudPullActivityProfiles
                          registerBitbucketCloudPullStatusProfiles
                          registerBitbucketCloudPullResourceProfiles
                          registerBitbucketCloudThreadProfiles
                          registerPagurePullRequestProfiles
                          registerPagureThreadProfiles
                          registerSourcehutGitCommitProfiles
                          registerSourcehutTodoThreadProfiles
                          registerSourcehutListsPatchsetProfiles
                          registerSourcehutListsArchiveThreadProfiles
                          registerAzureDevopsPullRequestProfiles
                          registerGerritFileResourceProfiles
                          registerGerritChangeProfiles
                          registerCommunityWikiProfiles
                          registerHackerNewsProfiles
                          registerMastodonProfiles
                          registerDiscourseProfiles
                          registerRedditProfiles
                          registerStackOverflowProfiles
                          registerBehanceProfiles
                          registerInstagramProfiles
                          registerFacebookProfiles
                          registerTelegramProfiles
                          registerTwitterProfiles
                          registerThreadsProfiles
                          registerLinkedinProfiles
                          registerBlueskyProfiles
                          registerQuoraProfiles
                        ])
    expect(register_source).to include(
      "registerHostAwareProfile(true, hatenaBlogContent);\n  registerHostAwareProfile(true, scientificRecordContent);"
    )
    expected_search_manifest = %w[
      profiles/social/search.js
      profiles/social/networks/tiktok.js
      profiles/media_commerce/search.js
      profiles/media_commerce/index.js
    ]
    expect(manifest[(manifest.index("profiles/host_aware.js") + 1), 4]).to eq(expected_search_manifest)

    registration_prefix = register_source.lines.grep(
      /^\s*register(?:PinterestSearchProfile|TikTokProfile|EbaySearchProfile|RingierAxelSpringerProfiles|MediaCommerceLeadProfiles|NewsHomepageProfiles)\(\);$/
    ).map do |line|
      line.strip.delete_suffix("();")
    end
    expected_registration_prefix = %w[
      registerPinterestSearchProfile
      registerTikTokProfile
      registerEbaySearchProfile
      registerRingierAxelSpringerProfiles
      registerMediaCommerceLeadProfiles
      registerNewsHomepageProfiles
    ]
    expect(registration_prefix).to eq(expected_registration_prefix)
    expect(File).not_to exist(File.join(source_root, "profiles/search.js"))
    source_files = Dir[File.join(source_root, "**", "*.js")]
    old_wrapper_count = source_files.sum do |path|
      File.read(path).scan(/function\s+registerSocialSearchProfiles\s*\(/).length
    end
    expect(old_wrapper_count).to eq(0)
    wykop_source = File.read(File.join(source_root, "profiles/community/social_news/wykop.js"))
    expect(wykop_source).to include("registerHostAwareProfile(/(^|\\.)wykop\\.pl$/i, wykopContent);")
    expect(wykop_source).not_to include("docsHostSignature")
    expect(manifest.index("profiles/news/news_homepages.js")).to be < register_index
    expect(manifest.index("profiles/community/social_news/wykop.js")).to be < register_index

    expect(manifest.index("systems/social/content_type.js")).to be < manifest.index("boot/result_finalization.js")
    expect(manifest.index("boot/result_finalization.js")).to be < manifest.index("boot/extract_api.js")
    expect(manifest.index("extractors/lists/generic/canonical_identity.js")).to be < manifest.index("core/dom/selectors.js")
    expect(manifest.index("profiles/host_aware.js")).to be < register_index
    expect(manifest.index("profiles/social/networks/meta/index.js")).to be < manifest.index("profiles/social/networks/meta/instagram.js")
    expect(manifest.index("profiles/social/networks/meta/index.js")).to be < manifest.index("profiles/social/networks/meta/facebook.js")
    expect(manifest.index("profiles/social/networks/meta/index.js")).to be < manifest.index("profiles/social/networks/meta/threads.js")
    expect(manifest.index("profiles/news/europe/central/poland/ringier_axel_springer.js")).to be < register_index
    wp_path = "profiles/news/europe/central/poland/wp.js"
    onet_path = "profiles/news/europe/central/poland/onet.js"
    expect(manifest.index(wp_path)).to be < manifest.index(onet_path)
    expect(manifest.index(onet_path)).to be < register_index
    expect(File).to exist(File.join(source_root, wp_path))
    expect(File).to exist(File.join(source_root, onet_path))
    expect(File).not_to exist(File.join(source_root, "profiles/news/europe/central/poland/wp_onet.js"))
    expect(File).not_to exist(File.join(source_root, "systems/news_engines/polish_portal_descriptors.js"))
    expect(manifest).not_to include("profiles/news/europe/central/poland/wp_onet.js")
    expect(manifest).not_to include("systems/news_engines/polish_portal_descriptors.js")
    expect(register_source).to include(
      "registerNewsHomepageProfiles();\n  registerWpHomepageProfile();\n  registerOnetHomepageProfile();\n  registerZeitProfiles();"
    )
    wp_source = File.read(File.join(source_root, wp_path))
    onet_source = File.read(File.join(source_root, onet_path))
    expect(wp_source).to include("function wpHomepageContent", "function registerWpHomepageProfile")
    expect(onet_source).to include("function onetHomepageContent", "function registerOnetHomepageProfile")
    expect(onet_source).to include("function onetRegionHeading", "function onetUtilityRegion", "function onetUtilityLabel")
    expect(onet_source).to include("function onetContinuationRegions", "function onetContinuationCard")
    expect(wp_source).not_to include("onetHomepageContent", "polishPortal")
    expect(onet_source).not_to include("wpHomepageContent", "polishPortal")
    source_files = Dir[File.join(source_root, "**", "*.js")]
    combined_symbols = source_files.sum do |path|
      File.read(path).scan(/(?:polishPortalDescriptors|polishPortalDescriptor|registerPolishPortalProfiles)/).length
    end
    expect(combined_symbols).to eq(0)

    ringier_source = File.read(File.join(source_root, "profiles/news/europe/central/poland/ringier_axel_springer.js"))
    expect(ringier_source.scan(/function\s+registerRingierAxelSpringerProfiles\s*\(/).length).to eq(1)
    expect(ringier_source).to include("registerHostAwareProfile(true, ringierAxelSpringerArticleContent);")
    expect(ringier_source).not_to include("mediaWatchContent =")
    expect(ringier_source).not_to include("ringierAxelSpringerBaseMediaWatchContent")
    expect(register_source.index("registerRingierAxelSpringerProfiles();")).to be < register_source.index("registerMediaCommerceLeadProfiles();")

    calls.each do |call|
      definitions = paths_before_register.flat_map do |path|
        File.read(File.join(source_root, path)).scan(/function\s+#{Regexp.escape(call)}\s*\(/).map { path }
      end
      expect(definitions.length).to eq(1), "#{call}: #{definitions.inspect}"
    end

    media_commerce_source = File.read(File.join(source_root, "profiles/media_commerce/index.js"))
    expect(media_commerce_source.scan(/registerHostAwareProfile\(true, (mediaWatchContent|youtubeContent)\);/).flatten).to eq(
      %w[mediaWatchContent youtubeContent]
    )

    institutional_europa_path = File.join(source_root, "profiles/families/institutional/europa.js")
    institutional_europa = File.exist?(institutional_europa_path) ? File.read(institutional_europa_path) : ""
    institutional_core = File.read(File.join(source_root, "profiles/families/institutional/core.js"))
    {
      "governmentProgramMicrositeContent" => "profiles/government/europa.js",
      "europaServiceLandingContent" => "profiles/government/europa.js",
      "eurLexDocumentContent" => "profiles/legal/eurlex.js",
      "legalConventionIndexContent" => "profiles/families/legal_reference/conventions.js"
    }.each do |function_name, destination|
      destination_source = File.read(File.join(source_root, destination))
      expect(destination_source.scan(/function\s+#{function_name}\s*\(/).length).to eq(1)
      expect(institutional_europa).not_to include("function #{function_name}(")
      expect(institutional_core).not_to include("function #{function_name}(")
      expect(manifest.index(destination)).to be < register_index
    end

    expected_dispatcher_order = [
      "eurLexDocumentContent(metadata) ||",
      "      governmentProgramMicrositeContent(metadata) ||",
      "      europaServiceLandingContent(metadata) ||",
      "      standardsRecordContent(metadata) ||",
      "      legalConventionIndexContent(metadata) ||"
    ].join("\n")
    expect(File.read(File.join(source_root, "profiles/families/institutional/index.js"))).to include(expected_dispatcher_order)

    direct_tail = manifest.drop(register_index + 1).select do |path|
      File.read(File.join(source_root, path)).match?(/(?:^[ \t]*|;[ \t]*)registerHostAwareProfile\(/)
    end
    expect(direct_tail).to eq(%w[
                                profiles/news/global/xinhua.js
                                profiles/news/middle_east/walla.js
                                profiles/news/asia/east/chosun.js
                                profiles/news/asia/south/india/dinakaran.js
                                profiles/news/europe/southern/spain/20minutos.js
                                profiles/news/asia/east/nhk.js
                                profiles/news/europe/southern/protothema.js
                                systems/cms/joomla.js
                                systems/cms/drupal.js
                                systems/cms/blogger.js
                                systems/cms/static_ssg.js
                                systems/cms/ghost.js
                                systems/cms/mediawiki.js
                                systems/cms/wordpress.js
                                profiles/news/asia/south/india/hindustantimes.js
                                profiles/news/europe/central/derstandard.js
                                profiles/news/asia/central/azerbaijan/oxu.js
                                profiles/news/europe/eastern/index_hr.js
                                profiles/news/europe/eastern/serbia/danas.js
                                profiles/news/europe/eastern/serbia/kurir.js
                                profiles/news/middle_east/almasryalyoum.js
                                profiles/news/asia/south/kalerkantho.js
                                profiles/news/asia/central/azerbaijan/trend.js
                                profiles/news/asia/south/pakistan/jang.js
                                profiles/news/middle_east/skynewsarabia.js
                                profiles/news/middle_east/turkey/milliyet_live.js
                                profiles/news/europe/central/aktuality_sk.js
                                profiles/news/middle_east/turkey/sabah.js
                                profiles/news/middle_east/turkey/sozcu.js
                                profiles/news/europe/central/poland/interia.js
                                profiles/news/americas/south/clarin.js
                                profiles/news/europe/eastern/serbia/blic.js
                                profiles/news/europe/central/hungary/tempo.js
                                profiles/news/europe/southern/spain/unidad_editorial.js
                                profiles/news/europe/southern/spain/marca.js
                                profiles/news/europe/western/germany/faz.js
                                profiles/news/europe/central/poland/agora_wyborcza.js
                                profiles/news/europe/central/hungary/index_hu.js
                                profiles/news/europe/central/czech/root_cz.js
                                profiles/news/americas/south/brazil/abril.js
                                profiles/news/asia/east/netease_news.js
                                profiles/publishing/ameba_blog.js
                                profiles/news/europe/dnevnik.js
                                profiles/publishing/segmentfault.js
                                profiles/social/networks/weibo_mobile.js
                                profiles/community/social_news/pikabu.js
                                profiles/news/europe/southern/rcs_corriere.js
                                profiles/news/europe/western/le_monde.js
                                profiles/news/europe/central/czech/idnes.js
                                profiles/news/americas/south/brazil/folha.js
                                profiles/publishing/naver_blog.js
                              ])
  end

  it "rebuilds deterministically" do
    with_asset_project(
      manifest: "00_prelude.js\n99_outro.js\n",
      files: {
        "00_prelude.js" => "(function(){\n",
        "99_outro.js" => "window.fetchUtilAssetSmoke = true;\n}());\n"
      }
    ) do |root|
      bin_dir = File.join(root, "bin")
      args_path = File.join(root, "npx-args")
      source_path = File.join(root, "npx-source")
      FileUtils.mkdir_p(bin_dir)
      install_fake_terser(root)
      File.write(
        File.join(bin_dir, "npx"),
        <<~SH
          #!/bin/sh
          printf '%s\\n' "$@" > "$NPX_ARGS"
          cp "$3" "$NPX_SOURCE"
          printf 'window.fetchUtilAssetSmoke=!0;\\n'
        SH
      )
      FileUtils.chmod(0o755, File.join(bin_dir, "npx"))
      path = [bin_dir, ENV.fetch("PATH")].join(File::PATH_SEPARATOR)

      stdout, stderr, status = run_build_script(
        root: root,
        env: { "NPX_ARGS" => args_path, "NPX_SOURCE" => source_path, "PATH" => path }
      )
      expect(status.success?).to be(true), [stdout, stderr].reject(&:empty?).join("\n")

      output = File.join(root, "lib", "fetch_util", "assets", "extract.js")
      expect(File.read(output)).to eq("window.fetchUtilAssetSmoke=!0;\n")
      expect(File.readlines(args_path, chomp: true)).to match(
        ["--no-install", "terser", match(%r{/fetch_util_extract[^/]*\.js\z}), "-cm"]
      )
      expect(File.read(source_path)).to eq(
        "(function(){\n\n" \
        "window.fetchUtilAssetSmoke = true;\n}());\n"
      )
    end
  end

  it "requires the local pinned Terser before invoking npx" do
    with_asset_project(manifest: "present.js\n", files: { "present.js" => "const present = true;\n" }) do |root|
      bin_dir = File.join(root, "bin")
      marker = File.join(root, "npx-invoked")
      FileUtils.mkdir_p(bin_dir)
      File.write(File.join(bin_dir, "npx"), "#!/bin/sh\ntouch \"$NPX_MARKER\"\nexit 97\n")
      FileUtils.chmod(0o755, File.join(bin_dir, "npx"))
      path = [bin_dir, ENV.fetch("PATH")].join(File::PATH_SEPARATOR)

      _stdout, stderr, status = run_build_script(root: root, env: { "NPX_MARKER" => marker, "PATH" => path })

      expect(status.success?).to be(false)
      expect(stderr).to include("Missing local Terser 5.51.2: run `npm ci`")
      expect(File).not_to exist(marker)
    end
  end

  it "rejects an installed Terser version that does not match the project pin" do
    with_asset_project(manifest: "present.js\n", files: { "present.js" => "const present = true;\n" }) do |root|
      bin_dir = File.join(root, "bin")
      marker = File.join(root, "npx-invoked")
      FileUtils.mkdir_p(bin_dir)
      install_fake_terser(root, version: "0.0.0")
      File.write(File.join(bin_dir, "npx"), "#!/bin/sh\ntouch \"$NPX_MARKER\"\nexit 97\n")
      FileUtils.chmod(0o755, File.join(bin_dir, "npx"))
      path = [bin_dir, ENV.fetch("PATH")].join(File::PATH_SEPARATOR)

      _stdout, stderr, status = run_build_script(root: root, env: { "NPX_MARKER" => marker, "PATH" => path })

      expect(status.success?).to be(false)
      expect(stderr).to include("Missing local Terser 5.51.2: run `npm ci`")
      expect(File).not_to exist(marker)
    end
  end

  it "validates the installed Terser before accepting a cached check" do
    with_asset_project(manifest: "present.js\n", files: { "present.js" => "const present = true;\n" }) do |root|
      bin_dir = File.join(root, "bin")
      invocation_count = File.join(root, "npx-invocations")
      FileUtils.mkdir_p(bin_dir)
      install_fake_terser(root)
      File.write(
        File.join(bin_dir, "npx"),
        "#!/bin/sh\nprintf x >> \"$NPX_INVOCATIONS\"\nprintf 'window.fetchUtilAssetSmoke=!0;\\n'\n"
      )
      FileUtils.chmod(0o755, File.join(bin_dir, "npx"))
      env = {
        "NPX_INVOCATIONS" => invocation_count,
        "PATH" => [bin_dir, ENV.fetch("PATH")].join(File::PATH_SEPARATOR)
      }

      _stdout, stderr, status = run_build_script(root: root, env: env)
      expect(status.success?).to be(true), stderr
      install_fake_terser(root, version: "0.0.0")

      _stdout, stderr, status = run_build_script("--check", root: root, env: env)

      expect(status.success?).to be(false)
      expect(stderr).to include("Missing local Terser 5.51.2: run `npm ci`")
      expect(File.read(invocation_count)).to eq("x")
    end
  end

  it "rejects a non-executable Terser before accepting a cached check" do
    with_asset_project(manifest: "present.js\n", files: { "present.js" => "const present = true;\n" }) do |root|
      bin_dir = File.join(root, "bin")
      invocation_count = File.join(root, "npx-invocations")
      FileUtils.mkdir_p(bin_dir)
      binary = install_fake_terser(root)
      File.write(
        File.join(bin_dir, "npx"),
        "#!/bin/sh\nprintf x >> \"$NPX_INVOCATIONS\"\nprintf 'window.fetchUtilAssetSmoke=!0;\\n'\n"
      )
      FileUtils.chmod(0o755, File.join(bin_dir, "npx"))
      env = {
        "NPX_INVOCATIONS" => invocation_count,
        "PATH" => [bin_dir, ENV.fetch("PATH")].join(File::PATH_SEPARATOR)
      }

      _stdout, stderr, status = run_build_script(root: root, env: env)
      expect(status.success?).to be(true), stderr
      FileUtils.chmod(0o644, binary)

      _stdout, stderr, status = run_build_script("--check", root: root, env: env)

      expect(status.success?).to be(false)
      expect(stderr).to include("Missing local Terser 5.51.2: run `npm ci`")
      expect(File.read(invocation_count)).to eq("x")
    end
  end

  it "fails check mode when the manifest lists a source file that does not exist" do
    with_asset_project(manifest: "present.js\nmissing.js\n", files: { "present.js" => "const present = true;\n" }) do |root|
      _stdout, stderr, status = run_build_script("--check", root: root)

      expect(status.success?).to be(false)
      expect(stderr).to include("Manifest entries missing source files: missing.js")
    end
  end

  it "fails check mode when a source file is not listed in the manifest" do
    with_asset_project(
      manifest: "present.js\n",
      files: { "present.js" => "const present = true;\n", "extra.js" => "const extra = true;\n" }
    ) do |root|
      _stdout, stderr, status = run_build_script("--check", root: root)

      expect(status.success?).to be(false)
      expect(stderr).to include("Source files missing from manifest: extra.js")
    end
  end

  it "fails build mode when the manifest lists a source file twice" do
    with_asset_project(
      manifest: "present.js\npresent.js\n",
      files: { "present.js" => "const present = true;\n" }
    ) do |root|
      _stdout, stderr, status = run_build_script(root: root)

      expect(status.success?).to be(false)
      expect(stderr).to include("Duplicate manifest entries: present.js")
    end
  end

  it "rejects duplicate top-level callable owners before bundling" do
    with_asset_project(
      manifest: "first.js\nsecond.js\n",
      files: {
        "first.js" => "function duplicateOwner() {}\n",
        "second.js" => "function duplicateOwner() {}\n"
      }
    ) do |root|
      [[], ["--check"]].each do |arguments|
        _stdout, stderr, status = run_build_script(*arguments, root: root)

        expect(status.success?).to be(false)
        expect(stderr).to include(
          "Duplicate top-level callable declarations:\n" \
          "duplicateOwner: first.js:1, second.js:1"
        )
      end
    end
  end

  it "reports a missing built asset before invoking terser in check mode" do
    with_asset_project(manifest: "present.js\n", files: { "present.js" => "const present = true;\n" }) do |root|
      bin_dir = File.join(root, "bin")
      FileUtils.mkdir_p(bin_dir)
      File.write(File.join(bin_dir, "npx"), "#!/bin/sh\necho unexpected terser invocation >&2\nexit 97\n")
      FileUtils.chmod(0o755, File.join(bin_dir, "npx"))

      path = [bin_dir, ENV.fetch("PATH")].join(File::PATH_SEPARATOR)
      _stdout, stderr, status = run_build_script("--check", root: root, env: { "PATH" => path })

      expect(status.success?).to be(false)
      expect(stderr).to include("Missing built asset:")
      expect(stderr).not_to include("unexpected terser invocation")
    end
  end

  it "fails build mode when a source file is not listed in the manifest" do
    with_asset_project(
      manifest: "present.js\n",
      files: { "present.js" => "const present = true;\n", "extra.js" => "const extra = true;\n" }
    ) do |root|
      _stdout, stderr, status = run_build_script(root: root)

      expect(status.success?).to be(false)
      expect(stderr).to include("Source files missing from manifest: extra.js")
    end
  end

  it "packages the generated runtime asset but not Websieve sources" do
    specification = Gem::Specification.load(File.join(project_root, "fetch_util.gemspec"))

    expect(specification.files).to include("lib/fetch_util/assets/extract.js")
    expect(specification.files.grep(%r{\Awebsieve/})).to be_empty
  end

  it "rejects direct package builds when the generated runtime asset is stale" do
    Dir.mktmpdir("fetch_util_gemspec") do |root|
      version_dir = File.join(root, "lib", "fetch_util")
      asset_dir = File.join(version_dir, "assets")
      source_dir = File.join(root, "websieve")
      FileUtils.mkdir_p([asset_dir, source_dir])
      copy_gemspec_support(root)
      File.write(
        File.join(version_dir, "version.rb"),
        "module FetchUtil\n  VERSION = '0.0.0' unless const_defined?(:VERSION, false)\nend\n"
      )
      File.write(File.join(source_dir, "manifest.txt"), "present.js\n")
      File.write(File.join(source_dir, "present.js"), "const present = true;\n")
      File.write(File.join(asset_dir, "extract.js"), "window.fetchUtil = {};\n")
      File.write(File.join(asset_dir, "extract.js.sha256"), "stale stale\n")

      specification = Gem::Specification.load(File.join(root, "fetch_util.gemspec"))
      package = File.join(root, specification.file_name)

      expect do
        Gem::DefaultUserInteraction.use_ui(Gem::SilentUI.new) do
          Dir.chdir(root) { Gem::Package.build(specification, false, false, package) }
        end
      end.to raise_error(
        Gem::InvalidSpecificationException,
        'Stale built asset: run `bundle exec rake build_extract_assets`'
      )
      expect(File.exist?(package)).to be(false)
    end
  end

  it "rejects direct package builds when the Websieve manifest is missing" do
    Dir.mktmpdir("fetch_util_gemspec") do |root|
      version_dir = File.join(root, "lib", "fetch_util")
      asset_dir = File.join(version_dir, "assets")
      source_dir = File.join(root, "websieve")
      FileUtils.mkdir_p([asset_dir, source_dir])
      copy_gemspec_support(root)
      File.write(
        File.join(version_dir, "version.rb"),
        "module FetchUtil\n  VERSION = '0.0.0' unless const_defined?(:VERSION, false)\nend\n"
      )
      File.write(File.join(source_dir, "present.js"), "const present = true;\n")
      File.write(File.join(asset_dir, "extract.js"), "window.fetchUtil = {};\n")

      specification = Gem::Specification.load(File.join(root, "fetch_util.gemspec"))
      package = File.join(root, specification.file_name)

      expect do
        Gem::DefaultUserInteraction.use_ui(Gem::SilentUI.new) do
          Dir.chdir(root) { Gem::Package.build(specification, false, false, package) }
        end
      end.to raise_error(
        Gem::InvalidSpecificationException,
        'Stale built asset: run `bundle exec rake build_extract_assets`'
      )
      expect(File.exist?(package)).to be(false)
    end
  end

  it "rejects direct package builds when a source file is missing from the manifest" do
    Dir.mktmpdir("fetch_util_gemspec") do |root|
      version_dir = File.join(root, "lib", "fetch_util")
      asset_dir = File.join(version_dir, "assets")
      source_dir = File.join(root, "websieve")
      FileUtils.mkdir_p([asset_dir, source_dir])
      copy_gemspec_support(root)
      File.write(
        File.join(version_dir, "version.rb"),
        "module FetchUtil\n  VERSION = '0.0.0' unless const_defined?(:VERSION, false)\nend\n"
      )
      source = "const present = true;\n"
      output = "window.fetchUtil = {};\n"
      entries = ["present.js"]
      File.write(File.join(source_dir, "manifest.txt"), "#{entries.join("\n")}\n")
      File.write(File.join(source_dir, "present.js"), source)
      File.write(File.join(source_dir, "extra.js"), "const extra = true;\n")
      File.write(File.join(asset_dir, "extract.js"), output)
      File.write(
        File.join(asset_dir, "extract.js.sha256"),
        "#{FetchUtil::ExtractAssetState.source_digest(entries, source)} #{Digest::SHA256.hexdigest(output)}\n"
      )

      specification = Gem::Specification.load(File.join(root, "fetch_util.gemspec"))
      package = File.join(root, specification.file_name)

      expect do
        Gem::DefaultUserInteraction.use_ui(Gem::SilentUI.new) do
          Dir.chdir(root) { Gem::Package.build(specification, false, false, package) }
        end
      end.to raise_error(
        Gem::InvalidSpecificationException,
        'Stale built asset: run `bundle exec rake build_extract_assets`'
      )
      expect(File.exist?(package)).to be(false)
    end
  end

  it "rejects direct package builds with duplicate top-level callable owners" do
    Dir.mktmpdir("fetch_util_gemspec") do |root|
      version_dir = File.join(root, "lib", "fetch_util")
      asset_dir = File.join(version_dir, "assets")
      source_dir = File.join(root, "websieve")
      FileUtils.mkdir_p([asset_dir, source_dir])
      copy_gemspec_support(root)
      File.write(
        File.join(version_dir, "version.rb"),
        "module FetchUtil\n  VERSION = '0.0.0' unless const_defined?(:VERSION, false)\nend\n"
      )
      entries = %w[first.js second.js]
      contents = ["function duplicateOwner() {}\n", "function duplicateOwner() {}\n"]
      entries.zip(contents).each do |entry, content|
        File.write(File.join(source_dir, entry), content)
      end
      source = contents.join("\n")
      output = "window.fetchUtil = {};\n"
      File.write(File.join(source_dir, "manifest.txt"), "#{entries.join("\n")}\n")
      File.write(File.join(asset_dir, "extract.js"), output)
      File.write(
        File.join(asset_dir, "extract.js.sha256"),
        "#{FetchUtil::ExtractAssetState.source_digest(entries, source)} #{Digest::SHA256.hexdigest(output)}\n"
      )

      specification = Gem::Specification.load(File.join(root, "fetch_util.gemspec"))
      package = File.join(root, specification.file_name)

      expect do
        Gem::DefaultUserInteraction.use_ui(Gem::SilentUI.new) do
          Dir.chdir(root) { Gem::Package.build(specification, false, false, package) }
        end
      end.to raise_error(
        Gem::InvalidSpecificationException,
        'Stale built asset: run `bundle exec rake build_extract_assets`'
      )
      expect(File.exist?(package)).to be(false)
    end
  end

  it "requires the generated runtime asset when the gemspec is loaded without it" do
    Dir.mktmpdir("fetch_util_gemspec") do |root|
      version_dir = File.join(root, "lib", "fetch_util")
      FileUtils.mkdir_p(version_dir)
      copy_gemspec_support(root)
      File.write(
        File.join(version_dir, "version.rb"),
        "module FetchUtil\n  VERSION = '0.0.0' unless const_defined?(:VERSION, false)\nend\n"
      )
      File.write(File.join(root, "package.json"), "{}\n")
      File.write(File.join(root, "package-lock.json"), "{}\n")

      specification = Gem::Specification.load(File.join(root, "fetch_util.gemspec"))
      package = File.join(root, specification.file_name)

      expect(specification.files).to include("lib/fetch_util/assets/extract.js")
      expect(specification.files).not_to include("package.json", "package-lock.json")
      expect do
        Gem::DefaultUserInteraction.use_ui(Gem::SilentUI.new) do
          Dir.chdir(root) { Gem::Package.build(specification, false, false, package) }
        end
      end.to raise_error(Gem::InvalidSpecificationException, %r{lib/fetch_util/assets/extract\.js})
      expect(File.exist?(package)).to be(false)
    end
  end

  it "excludes hidden paths when the gemspec is loaded without git" do
    Dir.mktmpdir("fetch_util_gemspec") do |root|
      version_dir = File.join(root, "lib", "fetch_util")
      asset = File.join(version_dir, "assets", "extract.js")
      FileUtils.mkdir_p(File.dirname(asset))
      copy_gemspec_support(root)
      File.write(
        File.join(version_dir, "version.rb"),
        "module FetchUtil\n  VERSION = '0.0.0' unless const_defined?(:VERSION, false)\nend\n"
      )
      File.write(asset, "window.fetchUtil = {};\n")
      File.write(File.join(root, "README.md"), "Visible package documentation.\n")
      File.write(File.join(root, ".rspec_status"), "private test state\n")
      File.write(File.join(version_dir, ".credentials"), "private runtime state\n")
      FileUtils.mkdir_p(File.join(root, "docs", ".draft"))
      File.write(File.join(root, "docs", ".draft", "notes.md"), "private draft\n")

      specification = Gem::Specification.load(File.join(root, "fetch_util.gemspec"))

      expect(specification.files).to include("README.md", "lib/fetch_util/assets/extract.js")
      expect(specification.files).not_to include(
        ".rspec_status", "lib/fetch_util/.credentials", "docs/.draft/notes.md"
      )
    end
  end

  it "excludes dependency trees when the gemspec is loaded without git" do
    Dir.mktmpdir("fetch_util_gemspec") do |root|
      version_dir = File.join(root, "lib", "fetch_util")
      asset = File.join(version_dir, "assets", "extract.js")
      FileUtils.mkdir_p(File.dirname(asset))
      copy_gemspec_support(root)
      File.write(
        File.join(version_dir, "version.rb"),
        "module FetchUtil\n  VERSION = '0.0.0' unless const_defined?(:VERSION, false)\nend\n"
      )
      File.write(asset, "window.fetchUtil = {};\n")
      File.write(File.join(root, "Gemfile.lock"), "dependency lock\n")
      FileUtils.mkdir_p(File.join(root, "vendor", "bundle"))
      File.write(File.join(root, "vendor", "bundle", "Gemfile.lock"), "nested dependency lock\n")
      FileUtils.mkdir_p(File.join(root, "node_modules", "terser"))
      File.write(File.join(root, "node_modules", "terser", "sentinel.js"), "dependency\n")
      FileUtils.mkdir_p(File.join(root, "vendor", "node_modules", "helper"))
      File.write(File.join(root, "vendor", "node_modules", "helper", "sentinel.js"), "dependency\n")

      specification = Gem::Specification.load(File.join(root, "fetch_util.gemspec"))

      expect(specification.files).to include("lib/fetch_util/assets/extract.js")
      expect(specification.files.grep(%r{(?:\A|/)Gemfile\.lock\z})).to be_empty
      expect(specification.files.grep(%r{(?:\A|/)node_modules/})).to be_empty
    end
  end
end
