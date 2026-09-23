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

  def expect_manifest_order(manifest, *paths)
    expect(manifest & paths).to eq(paths)
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
    sozcu_source = File.read(File.join(project_root, "websieve", "profiles", "news", "middle_east", "turkey", "sozcu.js"))
    faz_source = File.read(File.join(project_root, "websieve", "profiles", "news", "europe", "western", "germany", "faz.js"))

    expect(registrations).to eq(1)
    expect(sozcu_source.scan(/registerNewsHomepageListProfile\(/).length).to eq(1)
    expect(sozcu_source).not_to include("sozcuContent", "registerHostAwareProfile")
    expect(faz_source.scan(/registerNewsHomepageListProfile\(/).length).to eq(1)
    expect(faz_source).to include("registerHostAwareProfile(/(^|\\.)faz\\.net$/, fazArticleContent);")
    expect(faz_source).not_to include("fazContent")
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

  it "loads structured data entity helpers before their consumers" do
    source_root = File.join(project_root, "websieve")
    manifest = File.readlines(File.join(source_root, "manifest.txt"), chomp: true)
    entities_path = "core/metadata/structured_data_entities.js"
    structured_data_path = "core/metadata/structured_data.js"
    entities_source = File.read(File.join(source_root, entities_path))

    expect(manifest.index(entities_path)).to be < manifest.index(structured_data_path)
    expect(entities_source).to include(
      "function mergeStructuredDataEntity", "function structuredDataIdentityKey", "function nodeTypes"
    )
  end

  it "groups Markdown families without changing their load order" do
    source_root = File.join(project_root, "websieve")
    manifest = File.readlines(File.join(source_root, "manifest.txt"), chomp: true)
    families = [
      %w[markdown/code/code_helpers.js markdown/code/code_surfaces.js],
      %w[
        markdown/lists/list_aliases.js markdown/lists/list_metadata.js
        markdown/lists/list_supplemental.js markdown/lists/lists.js
      ],
      %w[
        markdown/materialization/materialization_inline.js
        markdown/materialization/materialization_containers.js
        markdown/materialization/materialization_blocks.js
        markdown/materialization/materialization.js
      ]
    ]

    families.each do |paths|
      expect(paths).to all(satisfy { |path| File.exist?(File.join(source_root, path)) })
      expect(manifest & paths).to eq(paths)
    end
    old_names = %w[
      code_helpers code_surfaces list_aliases list_metadata list_supplemental lists
      materialization_inline materialization_containers materialization_blocks materialization
    ]
    old_paths = old_names.filter_map do |name|
      path = File.join(source_root, "markdown/#{name}.js")
      path if File.exist?(path)
    end
    expect(old_paths).to eq([])
  end

  it "places shared list rendering and glossary scoring before their consumers" do
    source_root = File.join(project_root, "websieve")
    manifest = File.readlines(File.join(source_root, "manifest.txt"), chomp: true)
    aliases_path = "markdown/lists/list_aliases.js"
    metadata_path = "markdown/lists/list_metadata.js"
    supplemental_path = "markdown/lists/list_supplemental.js"
    list_path = "markdown/lists/lists.js"
    list_source = File.read(File.join(source_root, list_path))
    alias_source = File.read(File.join(source_root, aliases_path))
    metadata_source = File.read(File.join(source_root, metadata_path))
    supplemental_source = File.read(File.join(source_root, supplemental_path))
    expect(list_source).to include(
      "var listMarkdown = function(items, primaryUrls, primaryRecordKeys)", "item.author", "item.score", "item.replyCount", "item.community"
    )
    expect(alias_source).to include("function listTrackingAliasKey", "function listExactPrimaryAliasDetail")
    expect(metadata_source).to include(
      "function listCompactMetadataRow", "function listCompactMetadataRepresents", "function listCompactMetadataContains",
      "function listCompactMetadataFollowingField", "function cardField"
    )
    expect(list_source).not_to include("function listTrackingAliasKey")
    expect(list_source).not_to include("function listCompactMetadataRow")
    expect(list_source).not_to include("function cardField")
    expect(list_source).not_to include("function listSupplementalDetail")
    expect(manifest.index(aliases_path)).to be < manifest.index(list_path)
    expect(manifest.index(metadata_path)).to be < manifest.index(list_path)
    expect(manifest.index(supplemental_path)).to be < manifest.index(list_path)
    expect(supplemental_source).to include("function listClonedCardFields", "function listSupplementalDetail")
    list_definitions = Dir[File.join(source_root, "**", "*.js")].sum do |path|
      File.read(path).scan(/(?:function\s+listMarkdown\s*\(|var\s+listMarkdown\s*=\s*function\s*\()/).length
    end
    expect(list_definitions).to eq(1)
    expect(Dir[File.join(source_root, "**", "*.js")].sum { |path| File.read(path).scan(/function\s+definitionReferenceMetadataScore\s*\(/).length }).to eq(1)
    expect(File.read(File.join(source_root, "extractors/lists/generic/records/card_evidence.js"))).not_to include(
      "function listMarkdown"
    )
    expect(File.read(File.join(source_root, "core/metadata/structured_data.js"))).not_to include("function definitionReferenceMetadataScore")
    detection_source = File.read(File.join(source_root, "extractors/glossary/detection.js"))
    expect(detection_source.index("function definitionReferenceMetadataScore")).to be < detection_source.index("function glossaryLikePage")

    list_index = manifest.index(list_path)
    expect(list_index).to be < manifest.index("core/metadata/content_results.js")
    Dir[File.join(source_root, "**", "*.js")].each do |path|
      next if path == File.join(source_root, list_path)
      next unless File.read(path).include?("listMarkdown(")

      expect(list_index).to be < manifest.index(path.delete_prefix("#{source_root}/"))
    end
    expect(manifest.index("extractors/glossary/detection.js")).to be < manifest.index("extractors/glossary/extraction.js")
  end

  it "defines list helpers before the parser-sensitive renderer snapshot" do
    manifest = File.readlines(File.join(project_root, "websieve", "manifest.txt"), chomp: true)
    metadata_path = "markdown/lists/list_metadata.js"
    supplemental_path = "markdown/lists/list_supplemental.js"
    list_path = "markdown/lists/lists.js"
    metadata_source = File.read(File.join(project_root, "websieve", metadata_path))
    supplemental_source = File.read(File.join(project_root, "websieve", supplemental_path))
    list_source = File.read(File.join(project_root, "websieve", list_path))
    renderer_index = list_source.index("var listMarkdown = function(items, primaryUrls, primaryRecordKeys)")

    expect(renderer_index).not_to be_nil
    expect(supplemental_source).to include("function listSupplementalDetail")
    expect(list_source).not_to include("function listSupplementalDetail")
    expect(metadata_source).to include("function cardField")
    expect(manifest.index(metadata_path)).to be < manifest.index(list_path)
    expect(manifest.index(supplemental_path)).to be < manifest.index(list_path)
  end

  it "loads structured card-link shaping before the Markdown runtime" do
    manifest = File.readlines(File.join(project_root, "websieve", "manifest.txt"), chomp: true)
    helper = "markdown/card_links.js"
    runtime = "markdown/runtime.js"
    helper_source = File.read(File.join(project_root, "websieve", helper))

    expect(manifest.count(helper)).to eq(1)
    expect(manifest.index(helper)).to be < manifest.index(runtime)
    expect(helper_source).to include(
      "function preserveStructuredCardLinks", "function structuredCardOwnerLinkCounts"
    )
    expect(helper_source).not_to include('owner.querySelectorAll("article > a[href]")')
    expect(File.read(File.join(project_root, "websieve", runtime))).to include(
      "preserveStructuredCardLinks(root);"
    )
  end

  it "loads list byline finalization before result finalization" do
    source_root = File.join(project_root, "websieve")
    manifest = File.readlines(File.join(source_root, "manifest.txt"), chomp: true)
    byline_path = "boot/list_byline.js"
    finalization_path = "boot/result_finalization.js"
    byline_source = File.read(File.join(source_root, byline_path))
    finalization_source = File.read(File.join(source_root, finalization_path))

    expect(manifest.index(byline_path)).to be < manifest.index(finalization_path)
    expect(byline_source).to include("function listPageBylineSourceOwnership", "function listPageByline")
    expect(finalization_source).not_to include("function listPageBylineSourceOwnership")
    expect(finalization_source).to include("byline = listPageByline(byline, metadata, content, markdown)")
  end

  it "loads source-owned adjacent headings before result finalization" do
    source_root = File.join(project_root, "websieve")
    manifest = File.readlines(File.join(source_root, "manifest.txt"), chomp: true)
    helper_path = "core/docs_cleanup/adjacent_headings.js"
    finalization_path = "boot/result_finalization.js"

    expect(manifest.count(helper_path)).to eq(1)
    expect(manifest.index(helper_path)).to be < manifest.index(finalization_path)
    expect(File.read(File.join(source_root, helper_path))).to include("function articleTitleFromOwnedExternalHeading")
  end

  it "loads browsable inventories and GitHub thread primitives before their consumers" do
    source_root = File.join(project_root, "websieve")
    manifest = File.readlines(File.join(source_root, "manifest.txt"), chomp: true)
    inventory_path = "markdown/inventory.js"
    repository_hosts_path = "profiles/forges/shared/repository_hosts.js"
    thread_entries_path = "profiles/forges/shared/thread_entries.js"
    shared_path = "profiles/forges/github/thread_shared.js"
    thread_path = "profiles/forges/github/threads.js"
    file_resources_path = "profiles/forges/github/pull_requests/file_resources.js"
    resources_path = "profiles/forges/github/pull_requests/resources.js"
    gitlab_shared_path = "profiles/forges/gitlab/thread_shared.js"
    gitlab_thread_path = "profiles/forges/gitlab/threads.js"
    gitlab_resource_shared_path = "profiles/forges/gitlab/merge_requests/resource_shared.js"
    gitlab_diff_path = "profiles/forges/gitlab/merge_requests/diffs.js"
    gitlab_resources_path = "profiles/forges/gitlab/merge_requests/resources.js"
    gitea_shared_path = "profiles/forges/gitea/shared.js"
    gitea_resource_shared_path = "profiles/forges/gitea/pulls/resource_shared.js"
    gitea_commits_path = "profiles/forges/gitea/pulls/commits.js"
    gitea_files_path = "profiles/forges/gitea/pulls/files.js"
    gitea_resources_path = "profiles/forges/gitea/pulls/resources.js"
    gitea_entries_path = "profiles/forges/gitea/threads/entries.js"
    gitea_thread_path = "profiles/forges/gitea/threads/index.js"
    bitbucket_shared_path = "profiles/forges/bitbucket/shared.js"
    bitbucket_api_shared_path = "profiles/forges/bitbucket/api_shared.js"
    bitbucket_activity_path = "profiles/forges/bitbucket/pull_requests/activity.js"
    bitbucket_statuses_path = "profiles/forges/bitbucket/pull_requests/statuses.js"
    bitbucket_diff_files_path = "profiles/forges/bitbucket/pull_requests/diff_files.js"
    bitbucket_diffs_path = "profiles/forges/bitbucket/pull_requests/diffs.js"
    bitbucket_resources_path = "profiles/forges/bitbucket/pull_requests/resources.js"
    bitbucket_thread_path = "profiles/forges/bitbucket/threads.js"
    pagure_shared_path = "profiles/forges/pagure/shared.js"
    pagure_thread_path = "profiles/forges/pagure/threads.js"
    pagure_pull_path = "profiles/forges/pagure/pull_requests.js"
    sourcehut_git_shared_path = "profiles/forges/sourcehut/git/shared.js"
    sourcehut_git_commit_path = "profiles/forges/sourcehut/git/commits.js"
    sourcehut_shared_path = "profiles/forges/sourcehut/todo/shared.js"
    sourcehut_thread_path = "profiles/forges/sourcehut/todo/threads.js"
    sourcehut_lists_shared_path = "profiles/forges/sourcehut/lists/shared.js"
    sourcehut_lists_entries_path = "profiles/forges/sourcehut/lists/entries.js"
    sourcehut_lists_patchset_path = "profiles/forges/sourcehut/lists/patchsets.js"
    sourcehut_lists_thread_path = "profiles/forges/sourcehut/lists/threads.js"
    azure_shared_path = "profiles/forges/azure_devops/shared.js"
    azure_entries_path = "profiles/forges/azure_devops/entries.js"
    azure_thread_path = "profiles/forges/azure_devops/threads.js"
    gerrit_shared_path = "profiles/forges/gerrit/shared.js"
    gerrit_entries_path = "profiles/forges/gerrit/entries.js"
    gerrit_resource_shared_path = "profiles/forges/gerrit/resources/shared.js"
    gerrit_resource_entries_path = "profiles/forges/gerrit/resources/entries.js"
    gerrit_resources_path = "profiles/forges/gerrit/resources/index.js"
    gerrit_thread_path = "profiles/forges/gerrit/threads.js"

    expect(File.read(File.join(source_root, inventory_path))).to include("function browsableInventory")
    expect(File.read(File.join(source_root, repository_hosts_path))).to include("function registerRepoHostProfiles")
    expect(File.read(File.join(source_root, thread_entries_path))).to include("function deduplicateForgeThreadPermalinks")
    expect(File.read(File.join(source_root, shared_path))).to include("function githubResourceRoute")
    expect(manifest.index("profiles/families/institutional/index.js")).to be < manifest.index(repository_hosts_path)
    expect(manifest.index(repository_hosts_path)).to be < manifest.index(thread_entries_path)
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
    expect_manifest_order(
      manifest,
      gitlab_resources_path,
      gitea_shared_path,
      gitea_resource_shared_path,
      gitea_commits_path,
      gitea_files_path,
      gitea_resources_path,
      gitea_entries_path,
      gitea_thread_path,
      bitbucket_shared_path,
      bitbucket_api_shared_path,
      bitbucket_activity_path,
      bitbucket_statuses_path,
      bitbucket_diff_files_path,
      bitbucket_diffs_path,
      bitbucket_resources_path,
      bitbucket_thread_path,
      pagure_shared_path,
      pagure_thread_path,
      pagure_pull_path,
      sourcehut_git_shared_path,
      sourcehut_git_commit_path,
      sourcehut_shared_path,
      sourcehut_thread_path,
      sourcehut_lists_shared_path,
      sourcehut_lists_entries_path,
      sourcehut_lists_patchset_path,
      sourcehut_lists_thread_path,
      azure_shared_path,
      azure_entries_path,
      azure_thread_path,
      gerrit_shared_path,
      gerrit_entries_path,
      gerrit_resource_shared_path,
      gerrit_resource_entries_path,
      gerrit_resources_path,
      gerrit_thread_path,
      "profiles/register.js"
    )
    expect_manifest_order(manifest, resources_path, "profiles/register.js")
  end

  it "keeps forge profiles grouped by product and separate from communities" do
    source_root = File.join(project_root, "websieve")
    community_root = File.join(source_root, "profiles/community")
    forge_root = File.join(source_root, "profiles/forges")
    integration_root = File.join(project_root, "spec/fetch_util/extractor_integration")
    fixture_root = File.join(project_root, "spec/fetch_util/fixtures")
    expected_community_sources = %w[
      profiles/community/forums/discourse.js
      profiles/community/q_and_a/stack_exchange.js
      profiles/community/shared/thread_entries.js
      profiles/community/social_news/hacker_news.js
      profiles/community/wikis/tv_tropes.js
    ]
    expected_community_specs = %w[
      community/forums/discourse_topics_spec.rb
      community/forums/homepages_spec.rb
      community/q_and_a/stackoverflow_spec.rb
      community/shared/record_fidelity_spec.rb
      community/shared/thread_contracts_spec.rb
      community/social_news/hacker_news_spec.rb
      community/social_news/pikabu_spec.rb
      community/social_news/wykop_spec.rb
      community/wikis/tv_tropes_spec.rb
    ]
    expected_social_specs = %w[
      social/consent_walls_spec.rb
      social/content_spec.rb
      social/native_networks_spec.rb
      social/platform_walls_spec.rb
      social/record_fidelity_spec.rb
      social/telegram_spec.rb
      social/weibo_spec.rb
    ]
    expected_social_fixtures = %w[
      social/mastodon/detailed_status.html
      social/mastodon/explore_timeline.html
      social/mastodon/profile_cleanup.html
      social/mastodon/profile_over_cap.html
      social/reddit/challenge_shell.html
      social/telegram/channel_shell.html
      social/telegram/current_message.html
      social/telegram/login_shell.html
      social/telegram/public_channel.html
      social/telegram/public_message.html
      social/telegram/telegraph_article.html
    ]
    expected_community_fixtures = %w[
      community/contracts/discourse_list.html
      community/contracts/discourse_topic.html
      community/contracts/generic_article.html
      community/contracts/generic_list.html
      community/contracts/login_wall.html
      community/contracts/reddit_thread.html
      community/contracts/stack_exchange_question.html
      community/contracts/stackoverflow_question.html
      community/forums/discourse_list.html
      community/forums/discourse_topic.html
      community/q_and_a/stackoverflow_question.html
    ]
    expected_forge_sources = %w[
      profiles/forges/azure_devops/entries.js
      profiles/forges/azure_devops/shared.js
      profiles/forges/azure_devops/threads.js
      profiles/forges/bitbucket/api_shared.js
      profiles/forges/bitbucket/pull_requests/activity.js
      profiles/forges/bitbucket/pull_requests/diff_files.js
      profiles/forges/bitbucket/pull_requests/diffs.js
      profiles/forges/bitbucket/pull_requests/resources.js
      profiles/forges/bitbucket/pull_requests/statuses.js
      profiles/forges/bitbucket/shared.js
      profiles/forges/bitbucket/threads.js
      profiles/forges/gerrit/entries.js
      profiles/forges/gerrit/resources/entries.js
      profiles/forges/gerrit/resources/index.js
      profiles/forges/gerrit/resources/shared.js
      profiles/forges/gerrit/shared.js
      profiles/forges/gerrit/threads.js
      profiles/forges/gitea/pulls/commits.js
      profiles/forges/gitea/pulls/files.js
      profiles/forges/gitea/pulls/resource_shared.js
      profiles/forges/gitea/pulls/resources.js
      profiles/forges/gitea/shared.js
      profiles/forges/gitea/threads/entries.js
      profiles/forges/gitea/threads/index.js
      profiles/forges/github/pull_requests/file_resources.js
      profiles/forges/github/pull_requests/resources.js
      profiles/forges/github/thread_shared.js
      profiles/forges/github/threads.js
      profiles/forges/gitlab/merge_requests/diffs.js
      profiles/forges/gitlab/merge_requests/resource_shared.js
      profiles/forges/gitlab/merge_requests/resources.js
      profiles/forges/gitlab/thread_shared.js
      profiles/forges/gitlab/threads.js
      profiles/forges/pagure/pull_requests.js
      profiles/forges/pagure/shared.js
      profiles/forges/pagure/threads.js
      profiles/forges/shared/repository_hosts.js
      profiles/forges/shared/thread_entries.js
      profiles/forges/sourcehut/git/commits.js
      profiles/forges/sourcehut/git/shared.js
      profiles/forges/sourcehut/lists/entries.js
      profiles/forges/sourcehut/lists/patchsets.js
      profiles/forges/sourcehut/lists/shared.js
      profiles/forges/sourcehut/lists/threads.js
      profiles/forges/sourcehut/todo/shared.js
      profiles/forges/sourcehut/todo/threads.js
    ]
    expected_forge_specs = %w[
      forges/azure_devops/pull_requests_spec.rb
      forges/bitbucket/pull_activity_spec.rb
      forges/bitbucket/pull_resources_spec.rb
      forges/bitbucket/pull_statuses_spec.rb
      forges/bitbucket/threads_spec.rb
      forges/gerrit/change_resources_spec.rb
      forges/gerrit/changes_spec.rb
      forges/gitea/pull_resources_spec.rb
      forges/gitea/threads_spec.rb
      forges/github/pull_resources_spec.rb
      forges/github/threads_spec.rb
      forges/gitlab/merge_request_resources_spec.rb
      forges/gitlab/threads_spec.rb
      forges/pagure/pull_requests_spec.rb
      forges/pagure/threads_spec.rb
      forges/sourcehut/git_commits_spec.rb
      forges/sourcehut/lists_patchsets_spec.rb
      forges/sourcehut/lists_threads_spec.rb
      forges/sourcehut/todo_threads_spec.rb
      forges/shared/record_fidelity_spec.rb
      forges/shared/repository_readmes_spec.rb
    ]
    expected_forge_fixtures = %w[
      forges/azure_devops/pull_request.html
      forges/bitbucket/pull_activity.json
      forges/bitbucket/pull_commits.html
      forges/bitbucket/pull_diff.html
      forges/bitbucket/pull_request.html
      forges/bitbucket/pull_statuses.json
      forges/gerrit/change.html
      forges/gitea/forgejo_issue_thread.html
      forges/gitea/forgejo_pull_commits.html
      forges/gitea/forgejo_pull_files.html
      forges/gitea/gitea_issue_thread.html
      forges/gitea/gitea_pull_commits.html
      forges/gitea/gitea_pull_files.html
      forges/github/discussion_no_comments.html
      forges/github/issue_thread.html
      forges/github/login_wall.html
      forges/github/modern_issue_thread.html
      forges/github/modern_pull_thread.html
      forges/github/not_found.html
      forges/github/pull_checks.html
      forges/github/pull_commits.html
      forges/github/pull_files.html
      forges/github/pull_thread.html
      forges/github/repository_root.html
      forges/github/timeline_page.html
      forges/gitlab/merge_request_thread.html
      forges/gitlab/mr_commits.html
      forges/gitlab/mr_diffs.html
      forges/gitlab/mr_pipelines.html
      forges/gitlab/mr_reports.html
      forges/gitlab/work_item_thread.html
      forges/pagure/issue_thread.html
      forges/pagure/pull_request_thread.html
      forges/sourcehut/git_commit.html
      forges/sourcehut/lists_patchset.html
      forges/sourcehut/lists_thread.html
      forges/sourcehut/todo_ticket.html
    ]
    actual_forge_sources = Dir.glob(File.join(forge_root, "**/*.js")).map do |path|
      path.delete_prefix("#{source_root}/")
    end
    actual_community_sources = Dir.glob(File.join(community_root, "**/*.js")).map do |path|
      path.delete_prefix("#{source_root}/")
    end
    actual_community_specs = Dir.glob(File.join(integration_root, "community/**/*_spec.rb")).map do |path|
      path.delete_prefix("#{integration_root}/")
    end
    flat_community_specs = %w[
      community_threads_social_spec.rb
      discourse_topics_spec.rb
      forum_homepages_spec.rb
      hacker_news_spec.rb
      pikabu_spec.rb
      stackoverflow_spec.rb
      trope_wiki_pages_spec.rb
      wykop_social_spec.rb
    ].select do |name|
      File.exist?(File.join(integration_root, name))
    end
    actual_social_specs = Dir.glob(File.join(integration_root, "social/**/*_spec.rb")).map do |path|
      path.delete_prefix("#{integration_root}/")
    end
    flat_social_specs = %w[
      consent_and_social_walls_spec.rb
      native_social_networks_spec.rb
      social_cap_fidelity_spec.rb
      social_content_spec.rb
      social_platform_walls_spec.rb
      telegram_social_spec.rb
      weibo_mobile_spec.rb
    ].select do |name|
      File.exist?(File.join(integration_root, name))
    end
    actual_social_fixtures = Dir.glob(File.join(fixture_root, 'social/**/*.{html,json}')).map do |path|
      path.delete_prefix("#{fixture_root}/")
    end
    legacy_social_fixtures = %w[
      mastodon_detailed_status.html
      mastodon_explore_timeline.html
      mastodon_profile_cleanup.html
      mastodon_profile_over_cap.html
      reddit_challenge_shell.html
      telegram_channel_shell.html
      telegram_current_message.html
      telegram_login_shell.html
      telegram_public_channel.html
      telegram_public_message.html
      telegraph_article.html
    ].select do |name|
      File.exist?(File.join(project_root, 'spec/fixtures', name))
    end
    actual_community_fixtures = Dir.glob(File.join(fixture_root, 'community/**/*.{html,json}')).map do |path|
      path.delete_prefix("#{fixture_root}/")
    end
    legacy_community_fixtures = %w[
      community_discourse_list.html
      community_discourse_topic.html
      community_generic_article.html
      community_generic_list.html
      community_login_wall.html
      community_reddit_thread.html
      community_stackexchange_question.html
      community_stackoverflow_question.html
      discourse_list.html
      discourse_topic.html
      stackoverflow_question.html
    ].select do |name|
      File.exist?(File.join(project_root, 'spec/fixtures', name))
    end
    actual_forge_specs = Dir.glob(File.join(integration_root, "forges/**/*_spec.rb")).map do |path|
      path.delete_prefix("#{integration_root}/")
    end
    flat_forge_specs = %w[repo_hosts_readme_spec.rb].select do |name|
      File.exist?(File.join(integration_root, name))
    end
    actual_forge_fixtures = Dir.glob(File.join(fixture_root, "forges/**/*.{html,json}")).map do |path|
      path.delete_prefix("#{fixture_root}/")
    end
    flat_forge_fixtures = Dir.children(fixture_root).grep(
      /\A(?:azure_devops|bitbucket_cloud|forgejo|gerrit|gitea|github|gitlab|pagure|sourcehut)_/
    )

    expect(Dir.children(community_root).sort).to eq(%w[forums q_and_a shared social_news wikis])
    expect(actual_community_sources.sort).to eq(expected_community_sources.sort)
    expect(actual_community_specs.sort).to eq(expected_community_specs.sort)
    expect(flat_community_specs).to eq([])
    expect(actual_social_specs.sort).to eq(expected_social_specs.sort)
    expect(flat_social_specs).to eq([])
    expect(actual_social_fixtures.sort).to eq(expected_social_fixtures.sort)
    expect(legacy_social_fixtures).to eq([])
    expect(actual_community_fixtures.sort).to eq(expected_community_fixtures.sort)
    expect(legacy_community_fixtures).to eq([])
    expect(actual_forge_sources.sort).to eq(expected_forge_sources.sort)
    expect(Dir.glob(File.join(forge_root, "*.js"))).to eq([])
    expect(actual_forge_specs.sort).to eq(expected_forge_specs.sort)
    expect(flat_forge_specs).to eq([])
    expect(actual_forge_fixtures.sort).to eq(expected_forge_fixtures.sort)
    expect(flat_forge_fixtures).to eq([])

    manifest = File.readlines(File.join(source_root, "manifest.txt"), chomp: true)
    thread_entries_index = manifest.index("profiles/community/shared/thread_entries.js")
    expect(thread_entries_index).to be < manifest.index("profiles/community/forums/discourse.js")
    expect(thread_entries_index).to be < manifest.index("profiles/community/q_and_a/stack_exchange.js")
  end

  it "keeps relocated definitions before their consumers" do
    source_root = File.join(project_root, "websieve")
    manifest = File.readlines(File.join(source_root, "manifest.txt"), chomp: true)
    sources = manifest.to_h { |path| [path, File.read(File.join(source_root, path))] }

    expect(sources.values.join.scan(/function\s+mwananchiPrePageTextCleanup\s*\(/).length).to eq(1)
    expect(sources.values.join.scan(/function\s+genericHomepageLeadRoot\s*\(/).length).to eq(1)
    expect(sources.values.join.scan(/function\s+registerGenericPortalHomepageProfiles\s*\(/).length).to eq(1)
    expect_manifest_order(manifest, "profiles/news/mwananchi.js", "boot/pipeline_helpers.js")
    expect_manifest_order(
      manifest,
      "systems/news_engines/portal_lead_records.js",
      "systems/news_engines/portal_lead_context.js",
      "systems/news_engines/generic_portal_homepages.js",
      "profiles/news/news_homepages.js"
    )

    pipeline = sources.fetch("boot/pipeline_helpers.js")
    extract_api = sources.fetch("boot/extract_api.js")
    portal_leads = sources.fetch("systems/news_engines/portal_lead_records.js")
    portal_context = sources.fetch("systems/news_engines/portal_lead_context.js")
    generic_portal = sources.fetch("systems/news_engines/generic_portal_homepages.js")
    news_homepages = sources.fetch("profiles/news/news_homepages.js")
    expect(pipeline).not_to include("function mwananchiPrePageTextCleanup")
    expect(extract_api.index("mwananchiPrePageTextCleanup")).to be > 0
    expect(portal_leads).to include("function leadTitle", "function preserveHomepageLeadTitleMedia")
    expect(portal_context).to include("function homepageLeadContextDescriptions")
    expect(portal_leads).not_to include("function homepageLeadContextDescriptions")
    expect(generic_portal).not_to include("function leadTitle", "function preserveHomepageLeadTitleMedia")
    expect(generic_portal.index("function genericHomepageLeadRoot")).to be < generic_portal.index("function genericPortalHomepageContent")
    expect(news_homepages.index("function registerGenericPortalHomepageProfiles")).to be < news_homepages.index("function registerNewsHomepageProfiles")
  end

  it "keeps visibility-pruned cloning in the shared DOM owner" do
    source_root = File.join(project_root, "websieve")
    manifest = File.readlines(File.join(source_root, "manifest.txt"), chomp: true)
    base_path = "core/dom/base.js"
    list_path = "extractors/lists/generic/records/flat_extraction.js"
    base_source = File.read(File.join(source_root, base_path))
    list_source = File.read(File.join(source_root, list_path))

    expect(manifest.index(base_path)).to be < manifest.index(list_path)
    expect(base_source).to include("function pruneHiddenClone", "function visibilityPrunedClone")
    expect(list_source).to include("pruneHiddenClone(node, clone, preservedRoots)")
    expect(list_source).not_to include("function pruneHiddenListClone")
  end

  it "loads promotional and publisher CTA cleanup before their shared consumer" do
    source_root = File.join(project_root, "websieve")
    manifest = File.readlines(File.join(source_root, "manifest.txt"), chomp: true)

    expect(manifest.index("core/dom/promo_cleanup.js")).to be < manifest.index("core/dom/noise_cleanup.js")
    expect(manifest.index("core/dom/promo_cleanup.js")).to be < manifest.index("core/dom/cleanup.js")
    expect(manifest.index("core/dom/publisher_cta.js")).to be < manifest.index("core/dom/cleanup.js")
  end

  it "loads the shared generic list card boundary before its consumers" do
    source_root = File.join(project_root, "websieve")
    manifest = File.readlines(File.join(source_root, "manifest.txt"), chomp: true)
    ownership_path = "classifiers/list_pages/card_ownership.js"
    media_cards_path = "classifiers/list_pages/media_cards.js"
    presentation_path = "classifiers/list_pages/anchor_cards.js"
    media_cards_source = File.read(File.join(source_root, media_cards_path))
    presentation_source = File.read(File.join(source_root, presentation_path))
    record_titles_path = "classifiers/list_pages/record_titles.js"
    record_titles_source = File.read(File.join(source_root, record_titles_path))
    linked_media_path = "classifiers/list_pages/linked_media_rows.js"
    chrome_path = "classifiers/list_pages/chrome.js"
    renderer_path = "markdown/lists/lists.js"
    dominance_path = "classifiers/list_pages/dominance.js"
    card_evidence_path = "extractors/lists/generic/records/card_evidence.js"
    duplicate_metadata_path = "extractors/lists/generic/records/duplicate_record_metadata.js"
    flat_extraction_path = "extractors/lists/generic/records/flat_extraction.js"
    record_fallback_path = "extractors/lists/generic/sections/record_section_fallback.js"
    section_discovery_path = "extractors/lists/generic/sections/section_discovery.js"
    sources = [ownership_path, renderer_path, dominance_path, card_evidence_path, duplicate_metadata_path,
               flat_extraction_path, record_fallback_path, section_discovery_path].to_h do |path|
      [path, File.read(File.join(source_root, path))]
    end

    expect(sources.values.join.scan(/function\s+genericListCardSelector\s*\(/).length).to eq(1)
    expect(manifest.index(linked_media_path)).to be < manifest.index(presentation_path)
    expect(manifest.index(media_cards_path)).to be < manifest.index(presentation_path)
    expect(manifest.index(presentation_path)).to be < manifest.index(record_titles_path)
    expect(manifest.index(record_titles_path)).to be < manifest.index(dominance_path)
    expect(manifest.index(presentation_path)).to be < manifest.index(ownership_path)
    expect(presentation_source).to include("function genericListPresentationCardNode", "function genericListAlignmentOnlyCard")
    expect(media_cards_source).to include("function genericListPairedMediaCard", "function genericListImageTitleCard")
    expect(presentation_source).not_to include("function genericListDirectAnchorTitle")
    expect(record_titles_source).to include(
      "function genericListDirectAnchorTitle",
      "function genericListOwnedAnchorTitle",
      "function genericLinkedCollectionHeading"
    )
    expect(sources.fetch(dominance_path)).not_to include("function genericLinkedCollectionHeading")
    expect(presentation_source).not_to include("function genericListLinkedMediaRow")
    expect(File.read(File.join(source_root, linked_media_path))).to include("function genericListLinkedMediaRow")
    expect(manifest.index(chrome_path)).to be < manifest.index(dominance_path)
    expect(File.read(File.join(source_root, chrome_path))).to include(
      "function listExplicitAdvertisementNode",
      "function listExplicitAdvertisementOwner"
    )
    expect(File.read(File.join(source_root, linked_media_path))).to include("listExplicitAdvertisementOwner(row)")
    expect(sources.fetch(dominance_path)).to include("listExplicitAdvertisementOwner(link)")
    expect(sources.fetch(ownership_path)).not_to include("function genericListPresentationCardNode")
    [renderer_path, dominance_path, card_evidence_path, flat_extraction_path, record_fallback_path,
     section_discovery_path].each do |consumer_path|
      expect(manifest.index(ownership_path)).to be < manifest.index(consumer_path)
    end
    expect(sources.fetch(ownership_path)).to include(
      "function genericListCardBoundary",
      "function closestGenericListCard",
      "function genericListFieldBoundary",
      "function closestGenericListFieldCard",
      "function genericListContextCard",
      "function genericListNestedCardReplaces",
      'fallback.matches("tr")'
    )
    expect(sources.fetch(dominance_path)).to include(
      "genericListOwnedAnchorTitle(link)",
      "genericListCardText(detailSource)",
      "listCandidateScore(text, url, detail, container || link.parentElement, context)"
    )
    expect(sources.fetch(card_evidence_path)).to include(
      "closestGenericListFieldCard(node)",
      'card.matches("tr")',
      "genericListNestedCardReplaces(card, nested)"
    )
    expect(manifest.index(card_evidence_path)).to be < manifest.index(duplicate_metadata_path)
    [flat_extraction_path, section_discovery_path, "extractors/lists/core.js",
     "extractors/lists/homepage/lead_coverage.js"].each do |consumer_path|
      expect(manifest.index(duplicate_metadata_path)).to be < manifest.index(consumer_path)
    end
    expect(sources.fetch(duplicate_metadata_path)).to include("function mergeDuplicateRecordAuthorContext")
    expect(sources.fetch(flat_extraction_path)).to include("closestGenericListCard(node)")
    expect(sources.fetch(section_discovery_path)).to include(
      "customSelector || genericListCardSelector()",
      "allCards.filter(genericListCardBoundary)",
      "genericListNestedCardReplaces(card, nested)"
    )
  end

  it "groups generic list record producers in dependency order" do
    source_root = File.join(project_root, "websieve")
    manifest = File.readlines(File.join(source_root, "manifest.txt"), chomp: true)
    record_paths = %w[
      extractors/lists/generic/records/card_evidence.js
      extractors/lists/generic/records/duplicate_record_metadata.js
      extractors/lists/generic/records/inline_descriptions.js
      extractors/lists/generic/records/headline_extraction.js
      extractors/lists/generic/records/nested_coverage.js
      extractors/lists/generic/records/flat_extraction.js
    ]

    expect(record_paths).to all(satisfy { |path| File.exist?(File.join(source_root, path)) })
    expect(manifest & record_paths).to eq(record_paths)
    old_names = %w[
      card_evidence duplicate_record_metadata inline_descriptions
      headline_extraction nested_coverage flat_extraction
    ]
    old_paths = old_names.filter_map do |name|
      path = File.join(source_root, "extractors/lists/generic/#{name}.js")
      path if File.exist?(path)
    end
    expect(old_paths).to eq([])
  end

  it "groups generic list section helpers in dependency order" do
    source_root = File.join(project_root, "websieve")
    manifest = File.readlines(File.join(source_root, "manifest.txt"), chomp: true)
    editorial_path = "extractors/lists/generic/sections/editorial_asides.js"
    heading_path = "extractors/lists/generic/sections/heading_context.js"
    rendering_path = "extractors/lists/generic/sections/section_rendering.js"
    fallback_path = "extractors/lists/generic/sections/record_section_fallback.js"
    discovery_path = "extractors/lists/generic/sections/section_discovery.js"
    section_paths = [editorial_path, heading_path, rendering_path, fallback_path, discovery_path]
    rendering_source = File.read(File.join(source_root, rendering_path))
    fallback_source = File.read(File.join(source_root, fallback_path))
    discovery_source = File.read(File.join(source_root, discovery_path))

    expect(section_paths).to all(satisfy { |path| File.exist?(File.join(source_root, path)) })
    expect(manifest & section_paths).to eq(section_paths)
    expect(manifest.index(rendering_path)).to be < manifest.index(discovery_path)
    expect(manifest.index(fallback_path)).to be < manifest.index(discovery_path)
    expect(rendering_source).to include("function sectionedListMarkdownWithDescriptions")
    expect(fallback_source).to include(
      "function sectionHeadingLinks",
      "function sectionRecordDestination",
      "function simpleRecordCollection",
      "function sectionRecordCollectionFallback"
    )
    expect(discovery_source).not_to include("function sectionedListMarkdownWithDescriptions")
    expect(discovery_source).not_to include(
      "function sectionHeadingLinks",
      "function sectionRecordDestination",
      "function simpleRecordCollection",
      "function sectionRecordCollectionFallback"
    )
    old_names = %w[
      editorial_asides heading_context section_rendering
      record_section_fallback section_discovery
    ]
    old_paths = old_names.filter_map do |name|
      path = File.join(source_root, "extractors/lists/generic/#{name}.js")
      path if File.exist?(path)
    end
    expect(old_paths).to eq([])
  end

  it "groups homepage list strategies in dependency order" do
    source_root = File.join(project_root, "websieve")
    manifest = File.readlines(File.join(source_root, "manifest.txt"), chomp: true)
    search_path = "extractors/lists/homepage/search_tools.js"
    mapping_path = "extractors/lists/homepage/homepage_lead_mapping.js"
    exact_path = "extractors/lists/homepage/homepage_lead_exact.js"
    coverage_path = "extractors/lists/homepage/lead_coverage.js"
    news_path = "extractors/lists/homepage/news_homepages.js"
    homepage_paths = [search_path, mapping_path, exact_path, coverage_path, news_path]
    mapping_source = File.read(File.join(source_root, mapping_path))
    coverage_source = File.read(File.join(source_root, coverage_path))

    expect(homepage_paths).to all(satisfy { |path| File.exist?(File.join(source_root, path)) })
    expect(manifest & homepage_paths).to eq(homepage_paths)
    expect(manifest.index(mapping_path)).to be < manifest.index(exact_path)
    expect(manifest.index(exact_path)).to be < manifest.index(coverage_path)
    expect(manifest.index(mapping_path)).to be < manifest.index(coverage_path)
    expect(mapping_source).to include(
      "function homepageLeadListOwnership",
      "function homepageLeadDescriptionSourceNodes"
    )
    expect(coverage_source).not_to include(
      "function homepageLeadListOwnership",
      "function homepageLeadDescriptionSourceNodes"
    )
    old_paths = Dir.glob(
      File.join(
        source_root,
        "extractors/lists/{homepage_lead_mapping,homepage_lead_exact,lead_coverage,search_tools,news_homepages}.js"
      )
    )
    expect(old_paths).to eq([])
  end

  it "keeps MediaWiki extraction in its canonical CMS owner" do
    source_root = File.join(project_root, "websieve")
    sources = Dir[File.join(source_root, "**", "*.js")].to_h do |path|
      [path.delete_prefix("#{source_root}/"), File.read(path)]
    end
    combined_source = sources.values.join

    expect(combined_source.scan(/function\s+mediaWikiContent\s*\(/).length).to eq(1)
    expect(combined_source.scan(/registerHostAwareProfile\(true, mediaWikiContent\);/).length).to eq(0)
    community_sources = [
      sources.fetch("profiles/community/wikis/tv_tropes.js"),
      sources.fetch("profiles/community/q_and_a/stack_exchange.js")
    ].join
    expect(community_sources).not_to include("mediaWikiContent")
    expect(community_sources).not_to include("fandomWikiPage")
    expect(community_sources).not_to include("fandomContent")
    expect(sources).not_to have_key("profiles/families/community_wikis.js")
    expect(sources.fetch("systems/cms/mediawiki.js")).to include("function mediaWikiContent(metadata)")
  end

  it "keeps docs and Unidad Editorial modules in their ownership slots" do
    source_root = File.join(project_root, "websieve")
    manifest = File.readlines(File.join(source_root, "manifest.txt"), chomp: true)
    rails_source = File.read(File.join(source_root, "systems/docs/hosted/rails_rdoc.js"))

    expect(rails_source).to include("function rdocDocsContent(metadata)")
    expect(rails_source).not_to include("railsApiContent")

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

  it "groups article coverage helpers without changing their load order" do
    source_root = File.join(project_root, "websieve")
    manifest = File.readlines(File.join(source_root, "manifest.txt"), chomp: true)
    coverage_paths = %w[
      extractors/article/coverage/code_coverage.js
      extractors/article/coverage/intro_order.js
      extractors/article/coverage/intro_coverage.js
      extractors/article/coverage/carousel_coverage.js
      extractors/article/coverage/resources.js
      extractors/article/coverage/main_coverage.js
      extractors/article/coverage/hidden_substantive_main.js
    ]

    expect(coverage_paths).to all(satisfy { |path| File.exist?(File.join(source_root, path)) })
    expect(manifest & coverage_paths).to eq(coverage_paths)
    expect(manifest.index(coverage_paths[0])).to be < manifest.index("classifiers/list_pages/dominance.js")
    expect(manifest.index(coverage_paths[1])).to be > manifest.index("extractors/article/roots.js")
    expect(manifest.index(coverage_paths[4])).to be < manifest.index(coverage_paths[5])
    expect(manifest.index(coverage_paths[6])).to be > manifest.index("extractors/article/readability/readability.js")
    expect(Dir.glob(File.join(source_root, "extractors/article/*_coverage.js"))).to eq([])
  end

  it "groups article fallback helpers without changing their load order" do
    source_root = File.join(project_root, "websieve")
    manifest = File.readlines(File.join(source_root, "manifest.txt"), chomp: true)
    fallback_paths = %w[
      extractors/article/fallback/focal_ownership.js
      extractors/article/fallback/fallback_excerpt.js
      extractors/article/fallback/section_ownership.js
      extractors/article/fallback/fallback.js
    ]

    expect(fallback_paths).to all(satisfy { |path| File.exist?(File.join(source_root, path)) })
    expect(manifest & fallback_paths).to eq(fallback_paths)
    expect(manifest.index(fallback_paths[0])).to be > manifest.index("extractors/article/coverage/main_coverage.js")
    expect(manifest.index(fallback_paths[2])).to be < manifest.index("extractors/article/readability/readability_excerpt.js")
    expect(Dir.glob(File.join(source_root, "extractors/article/{fallback,fallback_excerpt,focal_ownership}.js"))).to eq([])
  end

  it "loads readability excerpt helpers before their runtime consumer" do
    source_root = File.join(project_root, "websieve")
    manifest = File.readlines(File.join(source_root, "manifest.txt"), chomp: true)
    excerpt_path = "extractors/article/readability/readability_excerpt.js"
    caption_path = "extractors/article/readability/caption_credit_excerpt.js"
    compact_path = "extractors/article/readability/compact_body_excerpt.js"
    runtime_path = "extractors/article/readability/readability.js"
    excerpt_source = File.read(File.join(source_root, excerpt_path))
    runtime_source = File.read(File.join(source_root, runtime_path))

    expect(manifest.index(excerpt_path)).to be < manifest.index(caption_path)
    expect(manifest.index(caption_path)).to be < manifest.index(compact_path)
    expect(manifest.index(compact_path)).to be < manifest.index(runtime_path)
    expect(File.read(File.join(source_root, caption_path))).to include("function readabilityCaptionCreditExcerpt")
    expect(File.read(File.join(source_root, compact_path))).to include("function readabilityCompactBodyExcerpt")
    expect(excerpt_source).to include(
      "function readabilityArticleExcerpt",
      "function stripReadabilityExcerptMarkers"
    )
    expect(runtime_source).to include("function readabilityContent")
    expect(runtime_source).not_to include(
      "function readabilityArticleExcerpt",
      "function stripReadabilityExcerptMarkers"
    )
  end

  it "loads article action ownership before the widget cleanup consumer" do
    manifest = File.readlines(File.join(project_root, "websieve/manifest.txt"), chomp: true)
    expect(manifest.index("core/dom/widgets/action_prompts.js")).to be < manifest.index("core/dom/widgets/article.js")
  end

  it "loads structured detail arbitration before late list dominance" do
    source_root = File.join(project_root, "websieve")
    manifest = File.readlines(File.join(source_root, "manifest.txt"), chomp: true)
    detail_path = "classifiers/list_pages/detail_articles.js"
    dominance_path = "classifiers/list_pages/dominance.js"
    boot_path = "boot/extract_api.js"

    expect(manifest.index(detail_path)).to be < manifest.index(dominance_path)
    expect(manifest.index(detail_path)).to be < manifest.index(boot_path)
    expect(File.read(File.join(source_root, detail_path))).to include(
      "function selectedArticleHasExplicitDetailOwnership",
      "function lateListHasIndependentRoot"
    )
    expect(File.read(File.join(source_root, boot_path))).to include(
      "selectedArticleHasExplicitDetailOwnership(content, metadata, indexListCandidate)"
    )
  end

  it "loads shared browse-index ownership before reader list arbitration" do
    manifest = File.readlines(File.join(project_root, "websieve/manifest.txt"), chomp: true)
    browse_path = "extractors/lists/generic/browse_indexes.js"

    expect(manifest.count(browse_path)).to eq(1)
    expect(manifest.index(browse_path)).to be < manifest.index("extractors/lists/relabeling.js")
    expect(manifest.index(browse_path)).to be < manifest.index("boot/extract_api.js")
  end

  it "groups dynamic list collections while preserving load order" do
    source_root = File.join(project_root, "websieve")
    manifest = File.readlines(File.join(source_root, "manifest.txt"), chomp: true)
    carousel_paths = %w[
      extractors/lists/generic/carousels/controlled_carousels.js
      extractors/lists/generic/carousels/slick_carousels.js
    ]
    recovery_paths = %w[
      extractors/lists/generic/visibility_recovery/dormant_body_root.js
      extractors/lists/generic/visibility_recovery/stale_opacity_sections.js
      extractors/lists/generic/visibility_recovery/controlled_panels.js
    ]

    expect(carousel_paths + recovery_paths).to all(satisfy { |path| File.exist?(File.join(source_root, path)) })
    expect(manifest & carousel_paths).to eq(carousel_paths)
    expect(manifest & recovery_paths).to eq(recovery_paths)
    expect(manifest.index(carousel_paths[1])).to be < manifest.index(recovery_paths[2])
    old_names = %w[
      controlled_carousels slick_carousels controlled_panels
      dormant_body_root stale_opacity_sections
    ]
    old_paths = old_names.filter_map do |name|
      path = File.join(source_root, "extractors/lists/generic/#{name}.js")
      path if File.exist?(path)
    end
    expect(old_paths).to eq([])
  end

  it "keeps reorganized source families in their release pipeline slots" do
    source_root = File.join(project_root, "websieve")
    manifest = File.readlines(File.join(source_root, "manifest.txt"), chomp: true)
    segments = [
      ["classifiers/list_pages/card_ownership.js", %w[
        extractors/lists/generic/sections/editorial_asides.js
      ], "classifiers/list_pages/chrome.js"],
      ["classifiers/list_pages/link_groups.js", %w[
        markdown/lists/list_aliases.js
        markdown/lists/list_metadata.js
        markdown/lists/list_supplemental.js
        markdown/lists/lists.js
      ], "markdown/inventory.js"],
      ["core/docs_cleanup/engines.js", %w[
        markdown/code/code_helpers.js
        markdown/code/code_surfaces.js
      ], "markdown/tables.js"],
      ["markdown/tables.js", %w[
        markdown/materialization/materialization_inline.js
        markdown/materialization/materialization_containers.js
        markdown/materialization/materialization_blocks.js
        markdown/materialization/materialization.js
      ], "markdown/card_links.js"],
      ["classifiers/list_pages/detail_articles.js", %w[
        extractors/article/coverage/code_coverage.js
      ], "classifiers/list_pages/dominance.js"],
      ["extractors/article/roots.js", %w[
        extractors/article/coverage/intro_order.js
        extractors/article/coverage/intro_coverage.js
        extractors/article/coverage/carousel_coverage.js
        extractors/article/coverage/resources.js
        extractors/article/coverage/main_coverage.js
        extractors/article/fallback/focal_ownership.js
        extractors/article/fallback/fallback_excerpt.js
        extractors/article/fallback/section_ownership.js
        extractors/article/fallback/fallback.js
        extractors/article/readability/readability_excerpt.js
        extractors/article/readability/caption_credit_excerpt.js
        extractors/article/readability/compact_body_excerpt.js
        extractors/article/readability/readability.js
        extractors/article/coverage/hidden_substantive_main.js
      ], "extractors/glossary/cleanup.js"],
      ["extractors/lists/relabeling.js", %w[
        extractors/lists/generic/records/card_evidence.js
        extractors/lists/generic/records/duplicate_record_metadata.js
        extractors/lists/generic/records/inline_descriptions.js
        extractors/lists/generic/records/headline_extraction.js
        extractors/lists/generic/records/nested_coverage.js
      ], "extractors/lists/description_parts.js"],
      ["extractors/lists/description_parts.js", %w[
        extractors/lists/generic/records/flat_extraction.js
        extractors/lists/generic/sections/heading_context.js
        extractors/lists/generic/sections/section_rendering.js
        extractors/lists/generic/sections/record_section_fallback.js
        extractors/lists/generic/sections/section_discovery.js
      ], "extractors/lists/card_visibility.js"],
      ["extractors/lists/core.js", %w[
        extractors/lists/homepage/search_tools.js
        extractors/lists/homepage/homepage_lead_mapping.js
        extractors/lists/homepage/homepage_lead_exact.js
        extractors/lists/homepage/lead_coverage.js
        extractors/lists/generic/visibility_recovery/dormant_body_root.js
        extractors/lists/generic/visibility_recovery/stale_opacity_sections.js
        extractors/lists/generic/carousels/controlled_carousels.js
        extractors/lists/generic/carousels/slick_carousels.js
        extractors/lists/generic/visibility_recovery/controlled_panels.js
      ], "extractors/lists/products/cards.js"],
      ["extractors/lists/events.js", %w[
        extractors/lists/homepage/news_homepages.js
      ], "extractors/search.js"]
    ]

    segments.each do |before_path, family_paths, after_path|
      before_index = manifest.index(before_path)

      expect(before_index).not_to be_nil
      expect(manifest.slice(before_index + 1, family_paths.length)).to eq(family_paths)
      expect(manifest.fetch(before_index + family_paths.length + 1)).to eq(after_path)
    end
  end

  it "keeps product-specific social profiles below the social root" do
    source_root = File.join(project_root, "websieve")
    social_root = File.join(source_root, "profiles/social")
    manifest = File.readlines(File.join(source_root, "manifest.txt"), chomp: true)

    expect(Dir.children(social_root).sort).to eq(%w[networks search.js telegram])
    expect(Dir[File.join(social_root, "telegram/**/*.js")].map { |path| File.basename(path) }).to eq(["telegram.js"])
    expect(manifest).to include("profiles/social/telegram/telegram.js")
    expect(manifest).not_to include("profiles/social/telegram.js")
  end

  it "preserves social profile registration precedence" do
    source_root = File.join(project_root, "websieve")
    manifest = File.readlines(File.join(source_root, "manifest.txt"), chomp: true)
    register_path = "profiles/register.js"
    register_index = manifest.index(register_path)
    register_source = File.read(File.join(source_root, register_path))
    calls = register_source.scan(/^\s*(register[A-Z]\w*)\(\);$/).flatten

    expect(calls).to eq(%w[
                          registerTvTropesProfiles
                          registerPinterestSearchProfile
                          registerEbaySearchProfile
                          registerRingierAxelSpringerProfiles
                          registerMediaCommerceLeadProfiles
                          registerNewsHomepageProfiles
                          registerBookingProfiles
                          registerAcademicPublisherProfiles
                          registerAcademicPreprintProfiles
                          registerCsdnProfiles
                          registerSubstackProfiles
                          registerPackageRegistryProfiles
                          registerStatuspageProfiles
                          registerLegalReferenceProfiles
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
                          registerStackExchangeProfiles
                          registerHackerNewsProfiles
                          registerMastodonProfiles
                          registerDiscourseProfiles
                          registerTelegramProfiles
                          registerTwitterProfiles
                          registerBlueskyProfiles
                        ])
    expect(register_source).to include(
      "registerAcademicPreprintProfiles();\n  registerHostAwareProfile(true, scientificRecordContent);"
    )
    expected_search_manifest = %w[
      profiles/social/search.js
      profiles/media_commerce/search.js
      profiles/media_commerce/index.js
    ]
    expect(manifest[(manifest.index("profiles/host_aware.js") + 1), 3]).to eq(expected_search_manifest)

    registration_prefix = register_source.lines.grep(
      /^\s*register(?:PinterestSearchProfile|EbaySearchProfile|RingierAxelSpringerProfiles|MediaCommerceLeadProfiles|NewsHomepageProfiles)\(\);$/
    ).map do |line|
      line.strip.delete_suffix("();")
    end
    expected_registration_prefix = %w[
      registerPinterestSearchProfile
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
    expect_manifest_order(manifest, "profiles/news/news_homepages.js", register_path)
    expect_manifest_order(
      manifest,
      "systems/social/visible_content.js",
      "systems/social/profile_content.js",
      "systems/social/content_type.js",
      "boot/result_finalization.js",
      "boot/extract_api.js"
    )
    expect_manifest_order(
      manifest,
      "extractors/lists/generic/canonical_identity.js",
      "core/dom/selectors.js"
    )
    expect_manifest_order(manifest, "profiles/host_aware.js", register_path)
    expect(manifest.index("profiles/news/europe/central/poland/ringier_axel_springer.js")).to be < register_index
  end

  it "keeps retired profile implementations absent" do
    source_root = File.join(project_root, "websieve")
    manifest = File.readlines(File.join(source_root, "manifest.txt"), chomp: true)
    register_source = File.read(File.join(source_root, "profiles/register.js"))

    wp_path = "profiles/news/europe/central/poland/wp.js"
    onet_path = "profiles/news/europe/central/poland/onet.js"
    expect(manifest).not_to include(wp_path)
    expect(manifest).not_to include(onet_path)
    expect(File).not_to exist(File.join(source_root, wp_path))
    expect(File).not_to exist(File.join(source_root, onet_path))
    expect(File).not_to exist(File.join(source_root, "profiles/news/europe/central/poland/wp_onet.js"))
    expect(File).not_to exist(File.join(source_root, "systems/news_engines/polish_portal_descriptors.js"))
    expect(manifest).not_to include("profiles/news/europe/central/poland/wp_onet.js")
    expect(manifest).not_to include("systems/news_engines/polish_portal_descriptors.js")
    expect(register_source).to include("registerNewsHomepageProfiles();\n  registerBookingProfiles();")
    source_files = Dir[File.join(source_root, "**", "*.js")]
    combined_symbols = source_files.sum do |path|
      File.read(path).scan(/(?:polishPortalDescriptors|polishPortalDescriptor|registerPolishPortalProfiles)/).length
    end
    expect(combined_symbols).to eq(0)
    retired_onet_pattern = Regexp.union(
      %w[
        onetHomepageContent onetHomepageDescriptor registerOnetHomepageProfile onetRegionHeading
        onetContinuationRegions onetContinuationCard onetUtilityRegion onetUtilityLabel
      ]
    )
    retired_onet_symbols = source_files.sum { |path| File.read(path).scan(retired_onet_pattern).length }
    expect(retired_onet_symbols).to eq(0)
    zeit_path = "profiles/news/europe/western/germany/zeit.js"
    expect(manifest).not_to include(zeit_path)
    expect(File).not_to exist(File.join(source_root, zeit_path))
    retired_zeit_symbols = source_files.sum do |path|
      File.read(path).scan(/(?:zeitArticleContent|registerZeitProfiles)/).length
    end
    expect(retired_zeit_symbols).to eq(0)
    protothema_path = "profiles/news/europe/southern/protothema.js"
    expect(manifest).not_to include(protothema_path)
    expect(File).not_to exist(File.join(source_root, protothema_path))
    retired_protothema_symbols = source_files.sum do |path|
      File.read(path).scan(/protothemaArticleContent/).length
    end
    expect(retired_protothema_symbols).to eq(0)
    kaler_kantho_path = "profiles/news/asia/south/kalerkantho.js"
    expect(manifest).not_to include(kaler_kantho_path)
    expect(File).not_to exist(File.join(source_root, kaler_kantho_path))
    retired_kaler_kantho_symbols = source_files.sum do |path|
      File.read(path).scan(
        /(?:kalerKanthoArticleContent|kalerKanthoArticlePage|kalerKanthoArticleBody|kalerKanthoUsefulArticleNode)/
      ).length
    end
    expect(retired_kaler_kantho_symbols).to eq(0)
    blick_path = "profiles/news/europe/central/blick.js"
    expect(manifest).not_to include(blick_path)
    expect(File).not_to exist(File.join(source_root, blick_path))
    retired_blick_selectors = source_files.sum do |path|
      File.read(path).scan(/(?:Body__StyledContainer|containerPiano1|CMPPlaceholder__Wrapper)/).length
    end
    expect(retired_blick_selectors).to eq(0)
    trend_path = "profiles/news/asia/central/azerbaijan/trend.js"
    expect(manifest).not_to include(trend_path)
    expect(File).not_to exist(File.join(source_root, trend_path))
    retired_trend_symbols = source_files.sum do |path|
      File.read(path).scan(/(?:trendArticleContent|trendArticlePage|trendBaseSlugKeywords)/).length
    end
    expect(retired_trend_symbols).to eq(0)
    wordpress_source = File.read(File.join(source_root, "systems/cms/wordpress.js"))
    expect(wordpress_source).not_to include("trend\\.az")

    ringier_source = File.read(File.join(source_root, "profiles/news/europe/central/poland/ringier_axel_springer.js"))
    expect(ringier_source.scan(/function\s+registerRingierAxelSpringerProfiles\s*\(/).length).to eq(1)
    expect(ringier_source).to include("registerHostAwareProfile(true, ringierAxelSpringerArticleContent);")
    expect(ringier_source).not_to include("mediaWatchContent =")
    expect(ringier_source).not_to include("ringierAxelSpringerBaseMediaWatchContent")
    expect(register_source.index("registerRingierAxelSpringerProfiles();")).to be < register_source.index("registerMediaCommerceLeadProfiles();")
  end

  it "keeps registration functions singly owned before dispatch" do
    source_root = File.join(project_root, "websieve")
    manifest = File.readlines(File.join(source_root, "manifest.txt"), chomp: true)
    register_path = "profiles/register.js"
    register_index = manifest.index(register_path)
    paths_before_register = manifest.take(register_index)
    register_source = File.read(File.join(source_root, register_path))
    calls = register_source.scan(/^\s*(register[A-Z]\w*)\(\);$/).flatten

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
    expected_tail = %w[
      profiles/news/global/xinhua.js
      profiles/news/middle_east/walla.js
      profiles/news/asia/east/nhk.js
      systems/cms/joomla.js
      systems/cms/blogger.js
      systems/cms/ghost.js
      systems/cms/wordpress.js
      profiles/news/asia/central/azerbaijan/oxu.js
      profiles/news/middle_east/almasryalyoum.js
      profiles/news/asia/south/pakistan/jang.js
      profiles/news/middle_east/skynewsarabia.js
      profiles/news/middle_east/turkey/milliyet_live.js
      profiles/news/middle_east/turkey/sabah.js
      profiles/news/europe/central/poland/interia.js
      profiles/news/europe/southern/spain/unidad_editorial.js
      profiles/news/europe/southern/spain/marca.js
      profiles/news/europe/western/germany/faz.js
      profiles/news/europe/central/poland/agora_wyborcza.js
      profiles/news/europe/central/hungary/index_hu.js
      profiles/news/europe/central/czech/root_cz.js
      profiles/news/americas/south/brazil/abril.js
      profiles/news/asia/east/netease_news.js
      profiles/news/europe/dnevnik.js
      profiles/news/europe/southern/rcs_corriere.js
      profiles/news/europe/western/le_monde.js
      profiles/news/europe/central/czech/idnes.js
      profiles/publishing/naver_blog.js
    ]
    expect(direct_tail).to eq(expected_tail)
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

  it "rejects a matching build when its checksum record is invalid" do
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
      File.write(File.join(root, "lib", "fetch_util", "assets", "extract.js.sha256"), "invalid invalid\n")

      _stdout, stderr, status = run_build_script("--check", root: root, env: env)

      expect(status.success?).to be(false)
      expect(stderr).to include("Stale built asset: run `bundle exec rake build_extract_assets`")
      expect(File.read(invocation_count)).to eq("xx")
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
