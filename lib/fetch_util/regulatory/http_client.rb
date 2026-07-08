# frozen_string_literal: true

require "net/http"
require "uri"

module FetchUtil
  class HttpRedirectClient
    REDIRECT_LIMIT = 5
    TRANSIENT_ERRORS = [EOFError, IOError, SocketError, SystemCallError, Timeout::Error].freeze
    Response = Struct.new(:url, :status, :headers, :body, :redirects, keyword_init: true)

    def initialize(timeout:, headers: {})
      @timeout = timeout.to_f
      @headers = headers.reject { |_key, value| value.to_s.empty? }
    end

    def get(url, limit: REDIRECT_LIMIT)
      @connections = {}
      fetch(parse_http_uri(url), limit, [])
    ensure
      close_connections
    end

    private

    attr_reader :timeout, :headers

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
      attempts = 0
      begin
        http = connection_for(uri)
        request = Net::HTTP::Get.new(uri.request_uri.empty? ? "/" : uri.request_uri)
        headers.each { |key, value| request[key] = value }
        http.request(request)
      rescue *TRANSIENT_ERRORS
        close_connection(uri)
        attempts += 1
        retry if attempts <= 1
        raise
      end
    end

    def connection_for(uri)
      key = [uri.scheme, uri.host, uri.port]
      @connections[key] ||= Net::HTTP.start(
        uri.host,
        uri.port,
        use_ssl: uri.scheme == "https",
        open_timeout: timeout,
        read_timeout: timeout
      )
    end

    def close_connection(uri)
      key = [uri.scheme, uri.host, uri.port]
      @connections.delete(key)&.finish
    rescue IOError
      nil
    end

    def close_connections
      @connections&.each_value do |http|
        http.finish if http.started?
      rescue IOError
        nil
      end
      @connections = nil
    end

    def build_response(uri, response, redirects: [])
      Response.new(
        url: uri.to_s,
        status: response.code.to_i,
        headers: response.to_hash.transform_keys(&:downcase),
        body: response.body.to_s,
        redirects: redirects
      )
    end

    def parse_http_uri(url)
      uri = URI.parse(url.to_s)
      raise URI::InvalidURIError, "unsupported url: #{url}" unless uri.is_a?(URI::HTTP) && uri.host

      uri
    end
  end

  class Regulatory
    class HttpClient
      DEFAULT_ACCEPT = "text/html,application/json,text/plain,*/*"

      def initialize(timeout:, user_agent:, redirect_client: nil)
        @user_agent = user_agent.to_s.strip
        @redirect_client = redirect_client || FetchUtil::HttpRedirectClient.new(timeout: timeout, headers: request_headers)
      end

      def get(url, limit: FetchUtil::HttpRedirectClient::REDIRECT_LIMIT)
        build_response(redirect_client.get(url, limit: limit))
      rescue URI::InvalidURIError
        raise ArgumentError, "unsupported url: #{url}"
      end

      private

      attr_reader :redirect_client, :user_agent

      def build_response(response)
        FetchUtil::Regulatory::Response.new(
          url: response.url,
          status: response.status,
          headers: response.headers,
          body: response.body,
          redirects: response.redirects.map { |redirect| build_response(redirect) }
        )
      end

      def request_headers
        {
          "Accept" => DEFAULT_ACCEPT,
          "User-Agent" => user_agent
        }
      end
    end
  end
end
