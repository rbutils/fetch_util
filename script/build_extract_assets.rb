# frozen_string_literal: true

require "open3"
require "pathname"
require "tempfile"

PROJECT_ROOT = Pathname(__dir__).join("..").expand_path
ROOT = PROJECT_ROOT.join("lib", "fetch_util", "assets")
SOURCE_ROOT = ROOT.join("src")
MANIFEST = SOURCE_ROOT.join("manifest.txt")
OUTPUT = ROOT.join("extract.js")

entries = MANIFEST.readlines(chomp: true).map(&:strip).reject { |line| line.empty? || line.start_with?("#") }

abort("Missing manifest: #{MANIFEST}") unless MANIFEST.file?

contents = entries.map do |entry|
  path = SOURCE_ROOT.join(entry)
  abort("Missing source file: #{path}") unless path.file?

  path.read
end

def terser_build(source)
  Tempfile.create(["fetch_util_extract", ".js"]) do |file|
    file.write(source)
    file.flush

    stdout, stderr, status = Open3.capture3("npx", "terser", file.path, "-cm", chdir: PROJECT_ROOT.to_s)
    abort("terser failed: #{stderr.strip}") unless status.success?

    stdout
  end
end

built = terser_build(contents.join("\n"))

if ARGV.include?("--check")
  abort("Missing built asset: #{OUTPUT}") unless OUTPUT.file?

  if OUTPUT.read == built
    puts "Verified #{OUTPUT} is up to date"
    exit 0
  end

  abort("Stale built asset: run `bundle exec rake build_extract_assets`")
end

OUTPUT.write(built)
puts "Built #{OUTPUT} from #{entries.length} source files via terser"
