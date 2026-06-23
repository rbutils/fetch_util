# frozen_string_literal: true

module FetchUtil
  class Regulatory
    module CacheStore
      private

      def cache_fetch(key)
        path = cache_file_path(key)
        cached = read_cache(path)
        return cached if cached

        payload = yield
        write_cache(path, payload)
        payload
      end

      def fetch_record(key, uri, fallback: nil, require_success: true)
        cache_fetch(key) do
          response = record_response(uri, require_success: require_success)
          response ? yield(response.body, response) : fallback
        end
      end

      def record_response(uri, require_success:)
        Array(uri).each do |candidate|
          response = safe_get(candidate)
          next unless response

          return response if !require_success || response.status&.between?(200, 299)
        end

        nil
      end

      def cache_file_path(key)
        digest = Digest::SHA256.hexdigest("v#{CACHE_VERSION}:#{key}")
        File.join(cache_path, "#{digest}.json")
      end

      def read_cache(path)
        return nil unless File.exist?(path)

        parsed = JSON.parse(File.read(path))
        cached_at = Time.parse(parsed.fetch("cached_at"))
        return nil if Time.now.utc - cached_at > CACHE_TTL

        parsed["payload"]
      rescue Errno::ENOENT, JSON::ParserError, KeyError, TypeError, ArgumentError
        nil
      end

      def write_cache(path, payload)
        FileUtils.mkdir_p(File.dirname(path))
        File.write(path, JSON.generate({ "cached_at" => Time.now.utc.iso8601, "payload" => json_safe(payload) }))
      end

      def safe_get(url)
        client.get(url)
      rescue ArgumentError, IOError, SocketError, Timeout::Error
        nil
      rescue FetchUtil::Error, SystemCallError, OpenSSL::SSL::SSLError
        nil
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
          value.each_with_object({}) do |(key, item), memo|
            memo[json_safe(key)] = json_safe(item)
          end
        else
          value
        end
      end
    end
  end
end
