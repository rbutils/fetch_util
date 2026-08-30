# frozen_string_literal: true

require "digest"
require "pathname"

module FetchUtil
  module ExtractAssetState
    unless const_defined?(:CALLABLE_DECLARATION_PATTERNS, false)
      CALLABLE_DECLARATION_PATTERNS = [
        /\A([ \t]*)(?:async\s+)?function(?:\s*\*\s*|\s+)([A-Za-z_$][\w$]*)\s*\(/,
        /\A([ \t]*)(?:var|let|const)\s+([A-Za-z_$][\w$]*)\s*=\s*(?:(?:async\s+)?function(?:\s*\*)?(?![\w$])|(?:async\s*)?(?:\([^)]*\)|[A-Za-z_$][\w$]*)\s*=>)/,
        /\A([ \t]*)class\s+([A-Za-z_$][\w$]*)\b/
      ].freeze
    end

    module_function

    def manifest_entries(manifest)
      manifest.readlines(chomp: true).map(&:strip).reject { |line| line.empty? || line.start_with?("#") }
    end

    def source_digest(entries, source)
      Digest::SHA256.hexdigest("#{entries.join("\n")}\n#{source}")
    end

    def duplicate_top_level_callables(entries, contents)
      owners = Hash.new { |hash, name| hash[name] = [] }

      entries.zip(contents).each do |entry, source|
        top_level_indent = source_top_level_indent(source)
        source.each_line.with_index(1) do |line, line_number|
          declaration = callable_declaration(line)
          next unless declaration && declaration.first == top_level_indent

          owners[declaration.last] << "#{entry}:#{line_number}"
        end
      end

      owners.select { |_name, locations| locations.length > 1 }
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
      return true unless source_root.directory?
      return false unless manifest.file?

      entries = manifest_entries(manifest)
      source_entries = source_root.glob("**/*.js").select(&:file?).map do |path|
        path.relative_path_from(source_root).to_s
      end
      return false unless entries.uniq.length == entries.length && entries.sort == source_entries.sort

      contents = entries.map { |entry| source_root.join(entry).read }
      return false unless duplicate_top_level_callables(entries, contents).empty?

      source = contents.join("\n")
      digest = source_digest(entries, source)
      cached_build_current?(
        digest,
        output: root.join("lib", "fetch_util", "assets", "extract.js"),
        digest_output: root.join("lib", "fetch_util", "assets", "extract.js.sha256")
      )
    rescue Errno::ENOENT
      false
    end

    def callable_declaration(line)
      CALLABLE_DECLARATION_PATTERNS.each do |pattern|
        match = line.match(pattern)
        next unless match

        indent = match[1].each_char.sum { |character| character == "\t" ? 2 : 1 }
        return [indent, match[2]]
      end

      nil
    end

    def source_top_level_indent(source)
      in_block_comment = false
      source.each_line.filter_map do |line|
        stripped = line.lstrip
        if in_block_comment
          in_block_comment = false if stripped.include?("*/")
          next
        end
        next if stripped.strip.empty? || stripped.start_with?("//")
        if stripped.start_with?("/*")
          in_block_comment = true unless stripped.include?("*/")
          next
        end

        line[/\A[ \t]*/].each_char.sum { |character| character == "\t" ? 2 : 1 }
      end.min
    end
    private_class_method :callable_declaration
    private_class_method :source_top_level_indent
  end
end
