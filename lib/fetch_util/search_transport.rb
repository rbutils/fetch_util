# frozen_string_literal: true

require "net/http"
require "nokogiri"
require "stringio"
require "timeout"
require "uri"
require "zlib"
require "base64"

module FetchUtil
  # Fetches and parses supported search result pages without involving the browser fetcher.
  class SearchTransport
    Candidate = Data.define(:source, :title, :url, :snippet, :source_rank) do
      def initialize(source:, title:, url:, source_rank:, snippet: nil)
        super(source: source.to_s.freeze, title: title.to_s.freeze, url: url.to_s.freeze,
              snippet: snippet&.to_s&.freeze, source_rank: Integer(source_rank))
      end
    end

    SourceResponse = Data.define(:source, :transport, :status, :candidates, :elapsed_ms, :final_url, :reason) do
      def initialize(source:, status:, elapsed_ms:, transport: "http", candidates: [], final_url: nil, reason: nil)
        super(source: source.to_s.freeze, transport: transport.to_s.freeze, status: status.to_s.freeze,
              candidates: candidates.freeze, elapsed_ms: Integer(elapsed_ms), final_url: final_url&.to_s&.freeze,
              reason: reason&.to_s&.freeze)
      end
    end

    HttpResponse = Data.define(:status, :headers, :body, :final_url)
    HttpFailure = Data.define(:reason, :final_url)

    SOURCES = {
      "brave" => { url: "https://search.brave.com/search?q=%{query}", hosts: %w[search.brave.com] },
      "bing" => { url: "https://www.bing.com/search?q=%{query}&setlang=en-US&cc=US", hosts: %w[www.bing.com cn.bing.com] },
      "duckduckgo" => { url: "https://html.duckduckgo.com/html/?q=%{query}", hosts: %w[html.duckduckgo.com] },
      "google" => { url: "https://www.google.com/search?q=%{query}", hosts: %w[www.google.com] },
      "ecosia" => { url: "https://www.ecosia.org/search?q=%{query}", hosts: %w[www.ecosia.org] }
    }.freeze
    DEFAULT_TIMEOUT = 10.0
    FAILURE_REASONS = %w[challenge failed host http_status parse redirect size timeout].freeze
    WRAPPER_HOSTS = {
      "bing" => %w[bing.com www.bing.com cn.bing.com],
      "duckduckgo" => %w[duckduckgo.com www.duckduckgo.com html.duckduckgo.com],
      "google" => %w[google.com www.google.com]
    }.freeze

    def initialize(sources: SOURCES.keys, timeout: DEFAULT_TIMEOUT, clock: nil, http_client: nil, html_parser: nil)
      @sources = sources.map(&:to_s).freeze
      unknown = @sources - SOURCES.keys
      raise ArgumentError, "unknown search sources: #{unknown.join(", ")}" if unknown.any?

      @timeout = Float(timeout)
      raise ArgumentError, "timeout must be positive" unless @timeout.positive?

      @clock = clock || -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) }
      @http_client = http_client || HttpClient.new(clock: @clock)
      @html_parser = html_parser || ->(body) { Nokogiri::HTML(body) }
    end

    def search(query)
      query = query.to_s.strip
      raise ArgumentError, "query must not be empty" if query.empty?

      deadline = clock.call + timeout
      responses = Array.new(sources.length)
      threads = sources.each_with_index.map do |source, index|
        Thread.new { responses[index] = search_source(source, query, deadline) }
      end
      threads.each(&:join)
      responses
    end

    private

    attr_reader :clock, :html_parser, :http_client, :sources, :timeout

    def search_source(source, query, deadline)
      started_at = clock.call
      url = build_url(source, query)
      result = http_client.get(url, deadline: deadline, allowed_hosts: SOURCES.fetch(source).fetch(:hosts))
      return failure(source, result.reason, elapsed_since(started_at), result.final_url) if result.is_a?(HttpFailure)
      outcome = within_deadline(deadline) do
        document = html_parser.call(result.body)
        next [:failed, "challenge"] if challenge?(source, result, document)
        next [:failed, "http_status"] unless result.status.between?(200, 299)
        next [:empty] if no_results?(source, document)

        [:ok, parse_candidates(source, document)]
      end
      elapsed_ms = elapsed_since(started_at)
      return failure(source, outcome.last, elapsed_ms, result.final_url) if outcome.first == :failed
      return empty(source, elapsed_ms, result.final_url) if outcome.first == :empty

      candidates = outcome.last
      return failure(source, "parse", elapsed_ms, result.final_url) if candidates.empty?

      SourceResponse.new(source: source, status: "ok", candidates: candidates, elapsed_ms: elapsed_ms, final_url: result.final_url)
    rescue HttpClient::DeadlineExceeded
      failure(source, "timeout", elapsed_since(started_at), url)
    rescue Nokogiri::XML::SyntaxError
      failure(source, "parse", elapsed_since(started_at), url)
    rescue StandardError
      # The public boundary intentionally maps implementation failures to a finite diagnostic code.
      failure(source, "failed", elapsed_since(started_at), url)
    end

    def build_url(source, query)
      SOURCES.fetch(source).fetch(:url) % { query: URI.encode_www_form_component(query) }
    end

    def parse_candidates(source, document)
      result_nodes(source, document).filter_map do |node|
        next if excluded_node?(node)

        anchor = result_anchor(source, node)
        next unless anchor

        url = destination(source, anchor["href"])
        title = normalized_text(title_node(source, node, anchor))
        next if url.nil? || title.empty? || engine_url?(source, url)

        snippet = normalized_text(node.at_css(snippet_selector(source)))
        [title, url, snippet]
      end.each_with_index.map do |(title, url, snippet), index|
        Candidate.new(source: source, title: title, url: url, snippet: snippet.empty? ? nil : snippet, source_rank: index + 1)
      end
    end

    def result_nodes(source, document)
      return brave_result_nodes(document) if source == "brave"

      selector = {
        "bing" => "#b_results li.b_algo",
        "duckduckgo" => ".results .result, .result.results_links",
        "google" => "#search .g, #search .MjjYud, #search [data-snhf]",
        "ecosia" => ".result, article.result"
      }.fetch(source)
      nodes = document.css(selector).uniq
      nodes.reject { |node| nodes.any? { |other| other != node && other.ancestors.include?(node) } }
    end

    def brave_result_nodes(document)
      current = document.css(".snippet[data-type='web']")
      legacy = document.css("#results > .snippet:not([id]):not([data-type])").select { |node| legacy_brave_result?(node) }
      (current.to_a + legacy).uniq
    end

    def legacy_brave_result?(node)
      node.at_css("h2, h3, .title.search-snippet-title") && result_anchor("brave", node)
    end

    def result_anchor(source, node)
      case source
      when "brave"
        node.css("a[href]").find do |candidate|
          url = destination(source, candidate["href"])
          url && !engine_url?(source, url)
        end
      when "bing" then node.at_css("h2 a[href]")
      when "duckduckgo" then node.at_css("a.result__a[href], h2 a[href]")
      when "google" then node.at_css("a[href]:has(h3)") || node.at_css("h3")&.ancestors("a[href]")&.first
      else node.at_css("h2 a[href], h3 a[href], a[href]:has(h3)")
      end
    end

    def title_node(source, node, anchor)
      return node.at_css(".title.search-snippet-title") || anchor.at_css("h2, h3") || anchor if source == "brave"

      anchor.at_css("h2, h3") || anchor
    end

    def snippet_selector(source)
      {
        "brave" => ".content, .snippet-description, .snippet-content, .description",
        "bing" => ".b_caption p, .b_paractl",
        "duckduckgo" => ".result__snippet",
        "google" => ".VwiC3b, .aCOpRe, [data-sncf]",
        "ecosia" => ".result-snippet, .result__description"
      }.fetch(source)
    end

    def excluded_node?(node)
      node.xpath("ancestor-or-self::*").any? do |ancestor|
        value = [ancestor["class"], ancestor["id"], ancestor["data-testid"]].compact.join(" ").downcase
        value.match?(/\b(ad|ads|advert|enrichment|knowledge|llm|nav|pagination|related|answer)\b/)
      end
    end

    def destination(source, href)
      value = href.to_s.strip
      value = decode_bing(value) if source == "bing"
      value = decode_wrapper(source, value) if %w[google duckduckgo].include?(source)
      uri = URI.parse(value)
      return unless uri.is_a?(URI::HTTP) && uri.host

      uri.to_s
    rescue URI::InvalidURIError
      nil
    end

    def decode_bing(value)
      uri = URI.parse(value)
      return value unless uri.path == "/ck/a" && (uri.host.nil? || wrapper_host?("bing", uri.host))

      encoded = URI.decode_www_form(uri.query.to_s).assoc("u")&.last.to_s
      return value unless encoded.start_with?("a1")

      decoded = encoded.delete_prefix("a1").tr("-_,", "+/=")
      decoded += "=" * ((4 - decoded.length % 4) % 4)
      Base64.strict_decode64(decoded).force_encoding("UTF-8").scrub
    rescue ArgumentError, URI::InvalidURIError
      value
    end

    def decode_wrapper(source, value)
      uri = URI.parse(value)
      key = source == "google" ? %w[q url] : %w[uddg]
      path = wrapper_path(source)
      return value unless uri.path == path && (uri.host.nil? || wrapper_host?(source, uri.host))

      URI.decode_www_form(uri.query.to_s).to_h.values_at(*key).compact.first || value
    rescue URI::InvalidURIError
      value
    end

    def engine_url?(source, value)
      host = URI.parse(value).host
      same_engine_host?(source, host) || wrapper_host?(source, host)
    rescue URI::InvalidURIError
      true
    end

    def same_engine_host?(source, host)
      SOURCES.fetch(source).fetch(:hosts).include?(host.to_s.downcase)
    end

    def wrapper_host?(source, host)
      WRAPPER_HOSTS.fetch(source, []).include?(host.to_s.downcase)
    end

    def wrapper_path(source)
      { "bing" => "/ck/a", "google" => "/url", "duckduckgo" => "/l/" }.fetch(source)
    end

    def normalized_text(node)
      node ? node.text.encode("UTF-8", invalid: :replace, undef: :replace, replace: " ").gsub(/\s+/, " ").strip : ""
    end

    def challenge?(source, response, document)
      return true if source == "google" && URI.parse(response.final_url).path.start_with?("/sorry")
      return true if source == "duckduckgo" && response.status == 202

      title = normalized_text(document.at_css("title")).downcase
      visible_text = visible_document_text(document)
      "#{title} #{visible_text}".match?(/captcha|unusual traffic|verify you are human|consent/)
    rescue URI::InvalidURIError
      true
    end

    def no_results?(source, document)
      text = visible_document_text(document)
      patterns = {
        "brave" => /no results|did not match any documents/,
        "bing" => /there are no results|no results found/,
        "duckduckgo" => /no results|no more results/,
        "google" => /did not match any documents|no results found/,
        "ecosia" => /no results found|we couldn't find/
      }
      text.match?(patterns.fetch(source))
    end

    def visible_document_text(document)
      visible = document.dup
      visible.css("script, style, template, noscript").remove
      normalized_text(visible).downcase
    end

    def failure(source, reason, elapsed_ms, final_url)
      reason = reason.to_s
      reason = "failed" unless FAILURE_REASONS.include?(reason)
      SourceResponse.new(source: source, status: "failed", elapsed_ms: elapsed_ms, final_url: final_url, reason: reason)
    end

    def empty(source, elapsed_ms, final_url)
      SourceResponse.new(source: source, status: "empty", elapsed_ms: elapsed_ms, final_url: final_url)
    end

    def elapsed_since(started_at)
      ((clock.call - started_at) * 1000).round
    end

    def within_deadline(deadline, &block)
      seconds = deadline - clock.call
      raise HttpClient::DeadlineExceeded unless seconds.positive?

      Timeout.timeout(seconds, HttpClient::DeadlineExceeded, &block)
    ensure
      raise HttpClient::DeadlineExceeded unless deadline - clock.call > 0
    end

    # Separate from the regulatory HTTP client: this enforces the SERP host and deadline contract.
    class HttpClient
      REDIRECT_LIMIT = 4
      MAX_RESPONSE_BYTES = 2 * 1024 * 1024
      INFLATE_CHUNK_BYTES = 16 * 1024

      def initialize(clock: -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) }, max_response_bytes: MAX_RESPONSE_BYTES,
                     net_http: nil)
        @clock = clock
        @max_response_bytes = Integer(max_response_bytes)
        @net_http = net_http || ->(uri) { Net::HTTP.new(uri.host, uri.port) }
      end

      def get(url, deadline:, allowed_hosts:)
        fetch(URI.parse(url), deadline, allowed_hosts.map(&:downcase), REDIRECT_LIMIT)
      rescue URI::InvalidURIError
        HttpFailure.new(reason: "host", final_url: url)
      end

      private

      attr_reader :clock, :max_response_bytes, :net_http

      def fetch(uri, deadline, allowed_hosts, redirects_left)
        return HttpFailure.new(reason: "host", final_url: uri.to_s) unless allowed_uri?(uri, allowed_hosts)
        return HttpFailure.new(reason: "timeout", final_url: uri.to_s) unless remaining(deadline).positive?

        response, body = request(uri, deadline)
        ensure_remaining!(deadline)
        if response.is_a?(Net::HTTPRedirection)
          return HttpFailure.new(reason: "redirect", final_url: uri.to_s) if redirects_left.zero? || response["location"].to_s.empty?

          target = begin
            uri.merge(response["location"])
          rescue URI::InvalidURIError
            return HttpFailure.new(reason: "redirect", final_url: uri.to_s)
          end
          return HttpFailure.new(reason: "host", final_url: target.to_s) unless allowed_uri?(target, allowed_hosts)

          return fetch(target, deadline, allowed_hosts, redirects_left - 1)
        end
        decoded = decode(body, response["content-encoding"], response["content-type"], deadline)
        ensure_remaining!(deadline)

        HttpResponse.new(status: response.code.to_i, headers: response.to_hash, body: decoded, final_url: uri.to_s)
      rescue DeadlineExceeded, Timeout::Error
        HttpFailure.new(reason: "timeout", final_url: uri.to_s)
      rescue ResponseTooLarge
        HttpFailure.new(reason: "size", final_url: uri.to_s)
      rescue Zlib::Error
        HttpFailure.new(reason: "parse", final_url: uri.to_s)
      rescue SystemCallError, IOError
        HttpFailure.new(reason: "failed", final_url: uri.to_s)
      end

      def request(uri, deadline)
        seconds = remaining(deadline)
        raise DeadlineExceeded unless seconds.positive?

        http = net_http.call(uri)
        http.use_ssl = uri.scheme == "https"
        http.open_timeout = seconds
        http.read_timeout = seconds
        http.write_timeout = seconds
        request = Net::HTTP::Get.new(
          uri.request_uri.empty? ? "/" : uri.request_uri,
          "Accept-Encoding" => "gzip, deflate",
          "Accept-Language" => "en-US,en;q=0.9",
          "User-Agent" => "fetch_util search transport"
        )
        body = +""
        response = within_wall_clock_timeout(seconds) do
          http.request(request) do |incoming|
            incoming.read_body do |chunk|
              ensure_remaining!(deadline)
              body << chunk
              raise ResponseTooLarge if body.bytesize > max_response_bytes
            end
          end
        end
        [response, body]
      end

      def decode(body, encoding, content_type, deadline)
        decoded = within_deadline(deadline) do
          decoded = inflate(body, encoding, deadline)
          charset = charset_from(content_type, decoded)
          begin
            decoded.force_encoding(charset).encode("UTF-8", invalid: :replace, undef: :replace, replace: " ")
          rescue ArgumentError, Encoding::ConverterNotFoundError
            decoded.force_encoding("UTF-8").scrub(" ")
          end
        end
        ensure_remaining!(deadline)
        decoded
      end

      def inflate(body, encoding, deadline)
        return body unless %w[gzip deflate].include?(encoding.to_s.downcase)

        window_bits = encoding.to_s.downcase == "gzip" ? Zlib::MAX_WBITS + 16 : Zlib::MAX_WBITS
        inflater = Zlib::Inflate.new(window_bits)
        decoded = +""
        offset = 0
        while offset < body.bytesize
          ensure_remaining!(deadline)
          chunk = body.byteslice(offset, INFLATE_CHUNK_BYTES)
          append_decoded(decoded, inflater.inflate(chunk))
          offset += chunk.bytesize
        end
        append_decoded(decoded, inflater.finish)
        decoded
      ensure
        inflater&.close
      end

      def append_decoded(decoded, chunk)
        decoded << chunk
        raise ResponseTooLarge if decoded.bytesize > max_response_bytes
      end

      def charset_from(content_type, body)
        header_charset = content_type.to_s[/charset\s*=\s*['"]?([^;'"\s]+)/i, 1]
        return header_charset if header_charset

        body.byteslice(0, 4096).to_s[/<meta\b[^>]*\bcharset\s*=\s*['"]?([^\s'";>]+)/i, 1] || "UTF-8"
      end

      def allowed_uri?(uri, allowed_hosts)
        uri.is_a?(URI::HTTP) && uri.host && allowed_hosts.include?(uri.host.downcase)
      end

      def remaining(deadline)
        deadline - clock.call
      end

      def ensure_remaining!(deadline)
        raise DeadlineExceeded unless remaining(deadline).positive?
      end

      def within_wall_clock_timeout(seconds, &block)
        return block.call unless seconds.finite?

        Timeout.timeout(seconds, DeadlineExceeded, &block)
      end

      def within_deadline(deadline, &block)
        seconds = remaining(deadline)
        raise DeadlineExceeded unless seconds.positive?

        within_wall_clock_timeout(seconds, &block)
      end

      ResponseTooLarge = Class.new(StandardError)
      DeadlineExceeded = Class.new(StandardError)
    end
  end
end
