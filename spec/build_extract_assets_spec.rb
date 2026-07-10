# frozen_string_literal: true

require "open3"
require "fileutils"
require "tmpdir"

RSpec.describe "extract asset bundle" do
  def project_root
    File.expand_path("..", __dir__)
  end

  def run_build_script(*args, root: project_root)
    script = File.join(root, "script", "build_extract_assets.rb")
    Open3.capture3(RbConfig.ruby, script, *args, chdir: root)
  end

  def with_asset_project(manifest:, files:)
    Dir.mktmpdir("fetch_util_assets") do |root|
      script_dir = File.join(root, "script")
      source_root = File.join(root, "lib", "fetch_util", "assets", "src")
      FileUtils.mkdir_p([script_dir, source_root])
      FileUtils.cp(File.join(project_root, "script", "build_extract_assets.rb"), script_dir)
      File.write(File.join(source_root, "manifest.txt"), manifest)

      files.each do |path, contents|
        file = File.join(source_root, path)
        FileUtils.mkdir_p(File.dirname(file))
        File.write(file, contents)
      end

      yield root
    end
  end

  it "verifies the checked-in extract.js is current" do
    stdout, stderr, status = run_build_script("--check")

    expect(status.success?).to be(true), [stdout, stderr].reject(&:empty?).join("\n")
    expect(stdout).to include("Verified")
  end

  it "registers generic portal homepages once in the source graph" do
    registrations = Dir[File.join(project_root, "lib", "fetch_util", "assets", "src", "**", "*.js")].sum do |path|
      File.read(path).scan(/^\s+registerGenericPortalHomepageProfiles\(\);$/).length
    end

    expect(registrations).to eq(1)
  end

  it "keeps warning policy delegates ordered before the entrypoint" do
    source_root = File.join(project_root, "lib", "fetch_util", "assets", "src")
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

  it "preserves social profile registration precedence" do
    source_root = File.join(project_root, "lib", "fetch_util", "assets", "src")
    manifest = File.readlines(File.join(source_root, "manifest.txt"), chomp: true)
    register_path = "profiles/register.js"
    register_index = manifest.index(register_path)
    paths_before_register = manifest.take(register_index)
    register_source = File.read(File.join(source_root, register_path))
    calls = register_source.scan(/^\s*(register(?:[A-Z]\w*)?Profiles)\(\);$/).flatten

    expect(calls).to eq(%w[
                          registerCommunityWikiLeadProfiles
                          registerSocialSearchProfiles
                          registerGlassdoorProfiles
                          registerMediaCommerceLeadProfiles
                          registerNewsHomepageProfiles
                          registerPolishPortalProfiles
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
    expect(manifest.index("profiles/news/europe/central/poland/wp_onet.js")).to be < register_index

    calls.each do |call|
      definitions = paths_before_register.flat_map do |path|
        File.read(File.join(source_root, path)).scan(/function\s+#{Regexp.escape(call)}\s*\(/).map { path }
      end
      expect(definitions.length).to eq(1), "#{call}: #{definitions.inspect}"
    end

    direct_tail = manifest.drop(register_index + 1).select do |path|
      File.read(File.join(source_root, path)).match?(/^\s*registerHostAwareProfile\(/)
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
                                systems/news_engines/unidad_editorial.js
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
      stdout, stderr, status = run_build_script(root: root)
      expect(status.success?).to be(true), [stdout, stderr].reject(&:empty?).join("\n")

      output = File.join(root, "lib", "fetch_util", "assets", "extract.js")
      expect(File.read(output)).to eq("window.fetchUtilAssetSmoke=!0;\n")
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
end
