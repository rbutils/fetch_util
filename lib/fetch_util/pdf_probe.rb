# frozen_string_literal: true

require "uri"
require "net/http"
require "timeout"

module FetchUtil
  class PdfProbe
    PDF_PATH_PATTERN = %r{(?:\.pdf\z|/pdf(?:/|\z)|[?&](?:format|download)=pdf\b)}i
    PDF_CONTENT_TYPE_PATTERN = %r{\Aapplication/(?:pdf|x-pdf)\b}i
    REDIRECT_LIMIT = 3

    def initialize(timeout:, header_probe: nil)
      @timeout = timeout
      @header_probe = header_probe
    end

    def probe(url)
      return { final_url: url, headers: {} } if self.class.pdf_url?(url)

      pdf_header_info(url)
    rescue URI::InvalidURIError
      nil
    end

    def self.pdf_url?(url)
      URI.parse(url.to_s).then do |uri|
        [uri.path, uri.query && "?#{uri.query}"].compact.join.match?(PDF_PATH_PATTERN)
      end
    end

    def title(url, headers)
      title_from_content_disposition(headers) || title_from_url(url)
    end

    private

    def pdf_header_info(url)
      info = @header_probe ? @header_probe.call(url) : probe_pdf_headers(url)
      return nil unless info && pdf_content_type?(info[:headers])

      info
    rescue URI::InvalidURIError, ArgumentError, FetchUtil::Error, IOError, SocketError, SystemCallError, Timeout::Error,
           OpenSSL::SSL::SSLError
      nil
    end

    def probe_pdf_headers(url, limit: REDIRECT_LIMIT, deadline: nil)
      deadline ||= monotonic_now + @timeout
      uri = parse_http_uri(url)
      remaining = deadline - monotonic_now
      return nil unless remaining.positive?

      response = request_head(uri, timeout: remaining)
      return nil unless deadline > monotonic_now

      if response.is_a?(Net::HTTPRedirection) && limit.positive? && !response["location"].to_s.strip.empty?
        return probe_pdf_headers(uri.merge(response["location"]).to_s, limit: limit - 1, deadline: deadline)
      end
      return nil unless response.is_a?(Net::HTTPSuccess)

      { final_url: uri.to_s, headers: response.to_hash.transform_keys(&:downcase) }
    end

    def request_head(uri, timeout: @timeout)
      Timeout.timeout(timeout) do
        Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", open_timeout: timeout, read_timeout: timeout) do |http|
          request = Net::HTTP::Head.new(uri.request_uri.empty? ? "/" : uri.request_uri)
          http.request(request)
        end
      end
    end

    def parse_http_uri(url)
      uri = URI.parse(url.to_s)
      raise URI::InvalidURIError, "unsupported url: #{url}" unless uri.is_a?(URI::HTTP) && !uri.host.to_s.empty?

      uri
    end

    def pdf_content_type?(headers)
      Array(headers&.fetch("content-type", nil)).any? { |value| value.to_s.match?(PDF_CONTENT_TYPE_PATTERN) }
    end

    def title_from_content_disposition(headers)
      value = Array(headers["content-disposition"]).first.to_s
      filename = value[/filename\*=UTF-8''([^;]+)/i, 1] || value[/filename="?([^";]+)"?/i, 1]
      return nil if filename.to_s.strip.empty?

      URI::DEFAULT_PARSER.unescape(filename).strip
    rescue ArgumentError
      filename.to_s.strip
    end

    def title_from_url(url)
      path = URI.parse(url.to_s).path.to_s
      basename = File.basename(path)
      title = basename.empty? || basename == "/" ? URI.parse(url.to_s).host.to_s : basename
      URI::DEFAULT_PARSER.unescape(title).strip
    rescue URI::InvalidURIError, ArgumentError
      url.to_s
    end

    def monotonic_now
      Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end
  end

  private_constant :PdfProbe
end
