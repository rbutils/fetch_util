# frozen_string_literal: true

require "fileutils"
require "digest"
require "json"
require "pathname"

module NativeReplay
  module Support
    module_function

    def read_json(path)
      JSON.parse(File.read(path, encoding: "UTF-8"), max_nesting: false)
    end

    def write_json(path, value)
      FileUtils.mkdir_p(File.dirname(path))
      temporary = "#{path}.#{Process.pid}.tmp"
      File.write(temporary, "#{JSON.pretty_generate(value, max_nesting: false)}\n")
      File.rename(temporary, path)
    ensure
      FileUtils.rm_f(temporary) if temporary
    end

    def file_sha(path)
      Digest::SHA256.file(path).hexdigest
    end

    def value_sha(value)
      Digest::SHA256.hexdigest(JSON.generate(canonical(value), max_nesting: false))
    end

    def canonical(value)
      case value
      when Hash then value.keys.sort.to_h { |key| [key, canonical(value.fetch(key))] }
      when Array then value.map { |item| canonical(item) }
      else value
      end
    end

    def resolve(base, path)
      File.expand_path(path, base)
    end

    def verify_file!(base, reference, label)
      path = resolve(base, reference.fetch("path"))
      raise "missing #{label}: #{path}" unless File.file?(path)

      actual = file_sha(path)
      raise "#{label} SHA-256 mismatch" unless actual == reference.fetch("sha256")

      path
    end

    def asset_fingerprints(asset_root)
      %w[vendor/readability.js vendor/turndown.js extract.js].to_h do |relative_path|
        path = File.join(asset_root, relative_path)
        raise "missing extractor asset: #{path}" unless File.file?(path)

        [relative_path, file_sha(path)]
      end
    end

    def directory_fingerprints(root)
      Dir.glob(File.join(root, "**", "*"), File::FNM_DOTMATCH).filter_map do |path|
        next unless File.file?(path)

        [Pathname.new(path).relative_path_from(Pathname.new(root)).to_s, file_sha(path)]
      end.sort.to_h
    end

    def directory_sha(root)
      value_sha(directory_fingerprints(root))
    end

    def artifact_root(output_path, run_id, variant)
      stem = File.basename(output_path, File.extname(output_path))
      File.join(File.dirname(output_path), "artifacts", stem, safe_id(run_id), variant)
    end

    def safe_id(value)
      raise "artifact identity must be a non-empty string" unless value.is_a?(String) && !value.empty?

      Digest::SHA256.hexdigest(value)
    end

    def validate_error!(error, deadline)
      if error.nil?
        raise "deadline flag without error" unless deadline == false
        return
      end

      required = %w[class message backtrace]
      raise "malformed error record" unless error.is_a?(Hash) && error.keys.sort == required.sort
      valid_text = %w[class message].all? { |key| error[key].is_a?(String) && !error[key].empty? }
      raise "malformed error class or message" unless valid_text
      raise "malformed error backtrace" unless error["backtrace"].is_a?(Array) && error["backtrace"].all? { |line| line.is_a?(String) }
      raise "deadline flag must be boolean" unless [true, false].include?(deadline)
      raise "deadline error must be Timeout::Error" if deadline && error["class"] != "Timeout::Error"
    end

    def snapshot(page)
      expression = File.read(File.join(__dir__, "native_replay", "diagnostics.js"), encoding: "UTF-8")
      reply = page.command("Runtime.evaluate", expression: expression, returnByValue: true, awaitPromise: true)
      raise "diagnostic JavaScript error: #{reply.fetch("exceptionDetails").inspect}" if reply["exceptionDetails"]

      result = reply.fetch("result")
      raise "diagnostics returned #{result["type"]} without a value" unless result.key?("value")

      value = result.fetch("value")
      raise "incomplete diagnostics" unless value.is_a?(Hash) && value["documentHtml"].is_a?(String) && value["elements"].is_a?(Array)

      value
    end

    def restore_runtime(page, state)
      raise "runtime state must be an object" unless state.is_a?(Hash)

      state.each do |name, json|
        unless name.match?(/\A[A-Za-z_$][A-Za-z0-9_$]*\z/) && !%w[__proto__ prototype constructor].include?(name)
          raise "unsafe runtime global name: #{name.inspect}"
        end
        raise "runtime value for #{name} must be JSON text" unless json.is_a?(String)

        JSON.parse(json, max_nesting: false)
        page.evaluate("Object.defineProperty(window, #{JSON.generate(name)}, { configurable: true, writable: true, value: JSON.parse(#{JSON.generate(json)}) })")
      end
    end
  end
end
