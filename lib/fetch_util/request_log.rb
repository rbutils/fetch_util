# frozen_string_literal: true

require "fileutils"
require "time"

module FetchUtil
  class RequestLog
    DEFAULT_PATH = File.expand_path("~/.local/state/fetch_util/requests.log")
    DELIMITER_ESCAPES = { "\t" => "\\t", "\r" => "\\r", "\n" => "\\n" }.freeze

    def initialize(path: nil)
      configured_path = path || ENV.fetch("FETCH_UTIL_REQUEST_LOG", DEFAULT_PATH)
      @path = (path.nil? ? configured_path.dup : normalized_path(path)).freeze
    end

    attr_reader :path

    def append(entry, duration: nil)
      FileUtils.mkdir_p(File.dirname(path))
      escaped_entry = entry.to_s.gsub(/[\t\r\n]/, DELIMITER_ESCAPES)
      line = "#{Time.now.utc.iso8601}\t#{escaped_entry}"
      line = "#{line}\t#{format("%.2f", duration)}s" if duration
      File.open(path, "a") { |file| file.puts(line) }
      path
    end

    private

    def normalized_path(value)
      raw_path = value.to_s
      return raw_path.dup if raw_path.empty? || directory_path?(raw_path)

      expanded_path = File.expand_path(raw_path)
      basename = File.basename(raw_path)
      return expanded_path if basename.start_with?(".") || !File.extname(basename).empty?

      "#{expanded_path}.log"
    end

    def directory_path?(path)
      separators = [File::SEPARATOR, File::ALT_SEPARATOR].compact
      separators.any? { |separator| path.end_with?(separator) } || %w[. ..].include?(File.basename(path))
    end
  end
end
