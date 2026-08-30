# frozen_string_literal: true

require "net/http"
require "openssl"
require "timeout"
require "uri"

module FetchUtil
  class HttpRedirectClient
    REDIRECT_LIMIT = 5
    MAX_RESPONSE_BYTES = 10 * 1024 * 1024
    TRANSIENT_ERRORS = [EOFError, IOError, SocketError, SystemCallError, Timeout::Error].freeze
    CLEANUP_ERRORS = (TRANSIENT_ERRORS + [OpenSSL::SSL::SSLError]).freeze
    Response = Struct.new(:url, :status, :headers, :body, :redirects, keyword_init: true)

    def initialize(timeout:, headers: {}, max_response_bytes: MAX_RESPONSE_BYTES)
      @timeout = positive_timeout(timeout)
      owned_headers = {}
      headers.each do |key, value|
        next if value.to_s.empty?

        owned_headers[key.dup.freeze] = value.dup.freeze
      end
      @headers = owned_headers.freeze
      @max_response_bytes = positive_max_response_bytes(max_response_bytes)
    end

    def get(url, limit: REDIRECT_LIMIT)
      connections = {}
      fetch(parse_http_uri(url), limit, [], connections)
    ensure
      close_connections(connections) if connections
    end

    private

    attr_reader :timeout, :headers, :max_response_bytes

    def positive_timeout(value)
      timeout = Float(value)
      return timeout if timeout.positive? && timeout.finite?

      raise ArgumentError
    rescue ArgumentError, TypeError
      raise InputError, "timeout must be positive"
    end

    def positive_max_response_bytes(value)
      bytes = Integer(value)
      return bytes if bytes.positive?

      raise ArgumentError
    rescue ArgumentError, TypeError, FloatDomainError
      raise InputError, "max_response_bytes must be positive"
    end

    def fetch(uri, limit, redirects, connections)
      response, body = request(uri, connections)
      return build_response(uri, response, body: body, redirects: redirects) unless response.is_a?(Net::HTTPRedirection)

      raise FetchUtil::Error, "too many redirects for #{uri}" if limit <= 0

      location = response["location"].to_s.strip
      return build_response(uri, response, body: body, redirects: redirects) if location.empty?

      redirect_response = build_response(uri, response, body: body)
      redirect_uri = parse_http_uri(uri.merge(location))
      fetch(redirect_uri, limit - 1, redirects + [redirect_response], connections)
    end

    def request(uri, connections)
      attempts = 0
      begin
        http = connection_for(uri, connections)
        request = Net::HTTP::Get.new(uri.request_uri.empty? ? "/" : uri.request_uri)
        headers.each { |key, value| request[key] = value }
        body = +""
        response = http.request(request) do |incoming|
          incoming.read_body do |chunk|
            if body.bytesize + chunk.bytesize > max_response_bytes
              raise FetchUtil::Error, "response body exceeds #{max_response_bytes} bytes for #{uri}"
            end
            body << chunk
          end
        end
        [response, body]
      rescue *TRANSIENT_ERRORS
        close_connection(uri, connections)
        attempts += 1
        retry if attempts <= 1
        raise
      end
    end

    def connection_for(uri, connections)
      key = [uri.scheme, uri.host, uri.port]
      connections[key] ||= Net::HTTP.start(
        uri.host,
        uri.port,
        use_ssl: uri.scheme == "https",
        open_timeout: timeout,
        read_timeout: timeout
      )
    end

    def close_connection(uri, connections)
      key = [uri.scheme, uri.host, uri.port]
      connections.delete(key)&.finish
    rescue *CLEANUP_ERRORS
      nil
    end

    def close_connections(connections)
      connections.each_value do |http|
        http.finish if http.started?
      rescue *CLEANUP_ERRORS
        nil
      end
    ensure
      connections.clear
    end

    def build_response(uri, response, body:, redirects: [])
      Response.new(
        url: uri.to_s,
        status: response.code.to_i,
        headers: response.to_hash.transform_keys(&:downcase),
        body: body,
        redirects: redirects
      )
    end

    def parse_http_uri(url)
      uri = URI.parse(url.to_s)
      raise URI::InvalidURIError, "unsupported url: #{url}" unless uri.is_a?(URI::HTTP) && !uri.host.to_s.empty?

      uri
    end
  end
end
