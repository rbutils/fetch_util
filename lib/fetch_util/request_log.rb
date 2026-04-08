# frozen_string_literal: true

require "fileutils"
require "time"

module FetchUtil
  class RequestLog
    DEFAULT_PATH = File.expand_path("~/.local/state/fetch_util/requests.log")

    def initialize(path: ENV.fetch("FETCH_UTIL_REQUEST_LOG", DEFAULT_PATH))
      @path = path
    end

    attr_reader :path

    def append(entry, duration: nil)
      FileUtils.mkdir_p(File.dirname(path))
      line = "#{Time.now.utc.iso8601}\t#{entry}"
      line = "#{line}\t#{format("%.2f", duration)}s" if duration
      File.open(path, "a") { |file| file.puts(line) }
      path
    end
  end
end
