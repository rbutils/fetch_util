# frozen_string_literal: true

require "digest"
require "pathname"

module FetchUtil
  module ExtractAssetState
    module_function

    def manifest_entries(manifest)
      manifest.readlines(chomp: true).map(&:strip).reject { |line| line.empty? || line.start_with?("#") }
    end

    def source_digest(entries, source)
      Digest::SHA256.hexdigest("#{entries.join("\n")}\n#{source}")
    end

    def cached_build_current?(source_digest, output:, digest_output:)
      return false unless output.file? && digest_output.file?

      cached_source_digest, cached_output_digest = digest_output.read.split(/\s+/, 3)
      cached_source_digest == source_digest && cached_output_digest == Digest::SHA256.file(output).hexdigest
    end

    def project_current?(project_root)
      root = Pathname(project_root)
      source_root = root.join("websieve")
      manifest = source_root.join("manifest.txt")
      return true unless manifest.file?

      entries = manifest_entries(manifest)
      source_entries = source_root.glob("**/*.js").select(&:file?).map do |path|
        path.relative_path_from(source_root).to_s
      end
      return false unless entries.uniq.length == entries.length && entries.sort == source_entries.sort

      source = entries.map { |entry| source_root.join(entry).read }.join("\n")
      digest = source_digest(entries, source)
      cached_build_current?(
        digest,
        output: root.join("lib", "fetch_util", "assets", "extract.js"),
        digest_output: root.join("lib", "fetch_util", "assets", "extract.js.sha256")
      )
    rescue Errno::ENOENT
      false
    end
  end
end
