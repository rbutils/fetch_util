# frozen_string_literal: true

require "open3"
require "pathname"
require "tempfile"
require "digest"
require "json"
require_relative "extract_asset_state"

PROJECT_ROOT = Pathname(__dir__).join("..").expand_path
ROOT = PROJECT_ROOT.join("lib", "fetch_util", "assets")
SOURCE_ROOT = PROJECT_ROOT.join("websieve")
MANIFEST = SOURCE_ROOT.join("manifest.txt")
OUTPUT = ROOT.join("extract.js")
DIGEST_OUTPUT = ROOT.join("extract.js.sha256")
LOCAL_TERSER = PROJECT_ROOT.join("node_modules", ".bin", "terser")
TERSER_VERSION = JSON.parse(PROJECT_ROOT.join("package.json").read).fetch("devDependencies").fetch("terser")

abort("Missing manifest: #{MANIFEST}") unless MANIFEST.file?

entries = FetchUtil::ExtractAssetState.manifest_entries(MANIFEST)

def validate_manifest_completeness(entries)
  duplicate_files = entries.tally.select { |_path, count| count > 1 }.keys.sort
  abort("Duplicate manifest entries: #{duplicate_files.join(", ")}") unless duplicate_files.empty?

  listed_files = entries.sort
  source_files = Dir.glob("**/*.js", base: SOURCE_ROOT).sort

  missing_files = listed_files - source_files
  unlisted_files = source_files - listed_files
  return if missing_files.empty? && unlisted_files.empty?

  messages = []
  messages << "Manifest entries missing source files: #{missing_files.join(", ")}" unless missing_files.empty?
  messages << "Source files missing from manifest: #{unlisted_files.join(", ")}" unless unlisted_files.empty?
  abort(messages.join("\n"))
end

validate_manifest_completeness(entries)

contents = entries.map do |entry|
  path = SOURCE_ROOT.join(entry)
  abort("Missing source file: #{path}") unless path.file?

  path.read
end
source = contents.join("\n")
source_digest = FetchUtil::ExtractAssetState.source_digest(entries, source)

def installed_terser_version
  package = PROJECT_ROOT.join("node_modules", "terser", "package.json")
  return unless package.file?

  JSON.parse(package.read).fetch("version")
rescue Errno::ENOENT, JSON::ParserError, KeyError
  nil
end

def verify_terser_installation
  return if LOCAL_TERSER.file? && installed_terser_version == TERSER_VERSION

  abort("Missing local Terser #{TERSER_VERSION}: run `npm ci`")
end

check_mode = ARGV.include?("--check")
if check_mode
  abort("Missing built asset: #{OUTPUT}") unless OUTPUT.file?

  if FetchUtil::ExtractAssetState.cached_build_current?(
    source_digest,
    output: OUTPUT,
    digest_output: DIGEST_OUTPUT
  )
    verify_terser_installation
    puts "Verified #{OUTPUT} is up to date"
    exit 0
  end
end

def terser_build(source)
  verify_terser_installation

  Tempfile.create(["fetch_util_extract", ".js"]) do |file|
    file.write(source)
    file.flush

    stdout, stderr, status = Open3.capture3("npx", "--no-install", "terser", file.path, "-cm", chdir: PROJECT_ROOT.to_s)
    abort("terser failed: #{stderr.strip}") unless status.success?

    stdout
  end
end

built = terser_build(source)

if check_mode
  if OUTPUT.read == built
    puts "Verified #{OUTPUT} is up to date"
    exit 0
  end

  abort("Stale built asset: run `bundle exec rake build_extract_assets`")
end

OUTPUT.write(built)
DIGEST_OUTPUT.write("#{source_digest} #{Digest::SHA256.hexdigest(built)}\n")
puts "Built #{OUTPUT} from #{entries.length} source files via terser"
