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

    def append(entry)
      FileUtils.mkdir_p(File.dirname(path))
      File.open(path, "a") do |file|
        file.puts("#{Time.now.utc.iso8601}\t#{entry}")
      end
      path
    end
  end
end
