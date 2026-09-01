# frozen_string_literal: true

module FetchUtil
  class Regulatory
    module CacheStore
      private

      def cache_fetch(key)
        path = cache_file_path(key)
        cached = read_cache(path)
        return cached if cached

        payload, cacheable = yield
        begin
          write_cache(path, payload) if cacheable
        rescue SystemCallError, IOError
          nil
        end
        payload
      end

      def fetch_record(key, uri, fallback: nil, require_success: true)
        cache_fetch(key) do
          response, cacheable = record_response(uri, require_success: require_success)
          payload = response ? yield(response.body, response) : fallback
          [payload, cacheable]
        end
      end

      def record_response(uri, require_success:)
        cacheable = true
        Array(uri).each do |candidate|
          response, completed = safe_get(candidate)
          cacheable &&= completed
          next unless response

          return [response, cacheable] if !require_success || response.status&.between?(200, 299)
        end

        [nil, cacheable]
      end

      def cache_file_path(key)
        digest = Digest::SHA256.hexdigest("v#{CACHE_VERSION}:#{key}")
        File.join(cache_path, "#{digest}.json")
      end

      def read_cache(path)
        return nil unless File.exist?(path)

        parsed = JSON.parse(File.read(path))
        return nil unless parsed.is_a?(Hash)

        cached_at = Time.parse(parsed.fetch("cached_at"))
        now = Time.now.utc
        return nil if cached_at > now || now - cached_at > CACHE_TTL

        parsed["payload"]
      rescue SystemCallError, IOError, JSON::ParserError, KeyError, TypeError, ArgumentError
        nil
      end

      def write_cache(path, payload)
        directory = File.dirname(path)
        serialized = JSON.generate({ "cached_at" => Time.now.utc.iso8601, "payload" => json_safe(payload) })
        FileUtils.mkdir_p(directory)
        existing_mode = cache_file_mode(path)
        temp_path = File.join(directory, ".#{File.basename(path)}.#{Process.pid}.#{SecureRandom.hex(6)}.tmp")

        File.open(temp_path, File::WRONLY | File::CREAT | File::EXCL, 0o666) do |file|
          file.write(serialized)
        end
        File.chmod(existing_mode, temp_path) if existing_mode
        File.rename(temp_path, path)
      ensure
        FileUtils.rm_f(temp_path) if temp_path
      end

      def cache_file_mode(path)
        File.stat(path).mode & 0o777
      rescue Errno::ENOENT
        nil
      end

      def safe_get(url)
        response = client.get(url)
        [response, cacheable_response?(response)]
      rescue ArgumentError, IOError, SocketError, Timeout::Error
        [nil, false]
      rescue FetchUtil::Error, SystemCallError, OpenSSL::SSL::SSLError
        [nil, false]
      end

      def cacheable_response?(response)
        status = response.status
        ![408, 429].include?(status) && !status&.between?(500, 599)
      end

      def deep_copy(value)
        JSON.parse(JSON.generate(json_safe(value)))
      end

      def response_chain(response)
        Array(response&.redirects) + [response].compact
      end

      def json_safe(value)
        case value
        when String
          value.encode(Encoding::UTF_8, invalid: :replace, undef: :replace)
        when Array
          value.map { |item| json_safe(item) }
        when Hash
          safe = {}
          value.each do |key, item|
            safe[json_safe(key)] = json_safe(item)
          end
          safe
        else
          value
        end
      end
    end
  end
end
