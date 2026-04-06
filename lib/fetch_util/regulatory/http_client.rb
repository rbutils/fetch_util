# frozen_string_literal: true

require "net/http"

module FetchUtil
  class Regulatory
    class HttpClient
      REDIRECT_LIMIT = 5

      def initialize(timeout:, user_agent:)
        @timeout = timeout.to_f
        @user_agent = user_agent.to_s.strip
      end

      def get(url, limit: REDIRECT_LIMIT)
        uri = parse_http_uri(url)
        fetch(uri, limit, [])
      end

      private

      attr_reader :timeout, :user_agent

      def fetch(uri, limit, redirects)
        response = request(uri)
        return build_response(uri, response, redirects: redirects) unless response.is_a?(Net::HTTPRedirection)

        raise FetchUtil::Error, "too many redirects for #{uri}" if limit <= 0

        location = response["location"].to_s.strip
        return build_response(uri, response, redirects: redirects) if location.empty?

        redirect_response = build_response(uri, response)
        fetch(uri.merge(location), limit - 1, redirects + [redirect_response])
      end

      def request(uri)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = uri.scheme == "https"
        http.open_timeout = timeout
        http.read_timeout = timeout
        request = Net::HTTP::Get.new(uri.request_uri.empty? ? "/" : uri.request_uri)
        request["Accept"] = "text/html,application/json,text/plain,*/*"
        request["User-Agent"] = user_agent unless user_agent.empty?
        http.request(request)
      end

      def build_response(uri, response, redirects: [])
        FetchUtil::Regulatory::Response.new(
          url: uri.to_s,
          status: response.code.to_i,
          headers: response.to_hash.transform_keys(&:downcase),
          body: response.body.to_s,
          redirects: redirects
        )
      end

      def parse_http_uri(url)
        uri = URI.parse(url.to_s)
        unless uri.is_a?(URI::HTTP) && uri.host
          raise ArgumentError, "unsupported url: #{url}"
        end

        uri
      rescue URI::InvalidURIError
        raise ArgumentError, "unsupported url: #{url}"
      end
    end
  end
end
