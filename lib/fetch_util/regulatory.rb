# frozen_string_literal: true

require "cgi"
require "digest"
require "fileutils"
require "json"
require "openssl"
require "time"
require "timeout"
require "uri"

module FetchUtil
  class Regulatory
    CACHE_TTL = 86_400
    CACHE_VERSION = 2
    DEFAULT_CACHE_PATH = File.expand_path("~/.local/state/fetch_util/regulatory-cache")
    MACHINE_SOURCES = %w[
      robotstxt
      contentsignal
      contentusagerobots
      contentusageheader
      trusttxt
      xrobotstag
      metarobots
      tdmrep
      tdmheaders
      tdmmeta
      tdmpolicy
    ].freeze
    HUMAN_SOURCES = %w[human].freeze
    SOURCE_CLASSES = {
      "machine" => MACHINE_SOURCES,
      "human" => HUMAN_SOURCES
    }.freeze

    Response = Struct.new(:url, :status, :headers, :body, :redirects, keyword_init: true)
  end
end

require_relative "regulatory/http_client"
require_relative "regulatory/robots"
require_relative "regulatory/robot_globs"
require_relative "regulatory/headers"
require_relative "regulatory/directives"
require_relative "regulatory/tdm_support"
require_relative "regulatory/tdm_page"
require_relative "regulatory/trust_txt"
require_relative "regulatory/usage_preferences"
require_relative "regulatory/page"
require_relative "regulatory/tdm_rep"
require_relative "regulatory/tdm_policy"
require_relative "regulatory/human"

module FetchUtil
  class Regulatory
    include Robots
    include RobotGlobs
    include Headers
    include Directives
    include TdmSupport
    include TdmPage
    include TrustTxt
    include UsagePreferences
    include Page
    include TdmRep
    include TdmPolicy
    include Human

    def initialize(client: nil, cache_path: DEFAULT_CACHE_PATH, sources: nil, timeout: 20, user_agent: nil)
      @client = client || HttpClient.new(timeout: timeout, user_agent: user_agent || default_user_agent)
      @cache_path = cache_path || DEFAULT_CACHE_PATH
      @source_tokens = sources
    end

    def call(url)
      requested_uri = parse_http_uri(url)
      origin_query = origin_query?(requested_uri)
      query_target = request_target(requested_uri)
      effective_query_target = query_target
      selected_sources = resolve_sources(@source_tokens)
      result = {}
      policy_refs = []

      if needs_tdmrep_fetch?(selected_sources)
        record = tdmrep_record(requested_uri)
        if selected_sources.include?("tdmrep")
          add_source_payload(result, "tdmrep", scoped_signals(record["signals"], origin_query: origin_query, query_target: query_target))
        end
        policy_refs.concat(record["policies"])
      end

      if selected_sources.include?("trusttxt")
        record = trusttxt_record(requested_uri)
        add_source_payload(result, "trusttxt", scoped_signals(record["signals"], origin_query: origin_query, query_target: query_target))
      end

      if needs_robots_fetch?(selected_sources)
        record = robots_record(requested_uri)
        %w[robotstxt contentsignal contentusagerobots].each do |source|
          next unless selected_sources.include?(source)

          add_source_payload(
            result,
            source,
            scoped_signals(record.dig("signals", source), origin_query: origin_query, query_target: query_target)
          )
        end
      end

      if needs_page_fetch?(selected_sources)
        record = page_record(requested_uri)
        effective_query_target = page_query_target(record, fallback: query_target)
        %w[xrobotstag metarobots tdmheaders tdmmeta contentusageheader human].each do |source|
          next unless selected_sources.include?(source)

          add_source_payload(
            result,
            source,
            scoped_signals(record.dig("signals", source), origin_query: origin_query, query_target: effective_query_target)
          )
        end
        policy_refs.concat(record["policies"])
      end

      if selected_sources.include?("tdmpolicy")
        add_source_payload(
          result,
          "tdmpolicy",
          scoped_signals(expanded_tdm_policy_signals(policy_refs), origin_query: origin_query, query_target: effective_query_target)
        )
      end

      result
    end

    private

    attr_reader :cache_path, :client

    def default_user_agent
      "fetch_util/#{FetchUtil::VERSION}"
    end

    def all_sources
      @all_sources ||= (MACHINE_SOURCES + HUMAN_SOURCES).freeze
    end

    def resolve_sources(selection)
      tokens = Array(selection || "machine").flat_map { |value| value.to_s.split(",") }
      tokens = tokens.map(&:strip).reject(&:empty?)
      selected = []

      tokens.each do |token|
        remove = token.start_with?("-")
        name = remove ? token[1..] : token
        expansions = SOURCE_CLASSES.fetch(name, [name])

        expansions.each do |source|
          validate_source!(source)
          if remove
            selected.delete(source)
          else
            selected << source unless selected.include?(source)
          end
        end
      end

      selected
    end

    def validate_source!(source)
      return if all_sources.include?(source)

      raise ArgumentError, "unsupported regulatory source: #{source}"
    end

    def needs_page_fetch?(selected_sources)
      (selected_sources & (HUMAN_SOURCES + %w[xrobotstag metarobots tdmheaders tdmmeta contentusageheader tdmpolicy])).any?
    end

    def needs_tdmrep_fetch?(selected_sources)
      (selected_sources & %w[tdmrep tdmpolicy]).any?
    end

    def needs_robots_fetch?(selected_sources)
      (selected_sources & %w[robotstxt contentsignal contentusagerobots]).any?
    end

    def add_source_payload(result, source, signals)
      return if signals.nil? || signals.empty?

      result[source] = signals
    end

    def scoped_signals(signals, origin_query:, query_target:)
      list = Array(signals).map { |signal| deep_copy(signal) }
      return list if origin_query

      list.filter_map do |signal|
        next unless signal_matches_target?(signal["path"], query_target)

        signal.reject { |key, _value| key == "path" }
      end
    end

    def signal_matches_target?(path, query_target)
      return true if path.nil? || path.empty?

      Regexp.new("\\A#{signal_path_pattern(path)}").match?(query_target)
    end

    def signal_path_pattern(path)
      escaped = Regexp.escape(path.to_s)
      escaped = escaped.gsub("\\*", ".*")
      if escaped.end_with?("\\$")
        "#{escaped[0...-2]}$"
      else
        "#{escaped}.*"
      end
    end

    def sort_specificity_signals(signals)
      Array(signals).sort_by do |signal|
        [
          *signal_sort_prefix(signal),
          signal.dig("conditions", "policy").to_s
        ]
      end
    end

    def signal_sort_prefix(signal)
      [
        -path_specificity(signal["path"]),
        allow_signal?(signal) ? 0 : 1
      ]
    end

    def sort_generic_signals(signals)
      Array(signals).sort_by do |signal|
        [
          allow_signal?(signal) ? 1 : 0,
          wildcard_signal?(signal) ? 1 : 0,
          signal_verb(signal),
          signal_noun(signal)
        ]
      end
    end

    def signal_verb(signal)
      signal.keys.find { |key| %w[allow disallow].include?(key) }.to_s
    end

    def signal_noun(signal)
      signal.values_at("allow", "disallow").compact.first.to_s
    end

    def allow_signal?(signal)
      signal.key?("allow")
    end

    def wildcard_signal?(signal)
      signal.dig("conditions", "user-agent").to_s == "*" || signal.dig("conditions", "user-agent").to_s.empty?
    end

    def path_specificity(path)
      path.to_s.delete("*$").length
    end

    def integer_or_value(value)
      Integer(value, exception: false) || value
    end

    def build_signal(verb, noun, path: nil, conditions: nil)
      signal = { verb => noun }
      signal["path"] = path if path
      signal["conditions"] = conditions if conditions && !conditions.empty?
      signal
    end

    def normalize_output_path(value)
      text = value.to_s.strip
      return "/*" if text.empty? || text == "/"

      text
    end

    def request_target(uri)
      path = uri.path.to_s.empty? ? "/" : uri.path.to_s
      query = uri.query.to_s
      return path if query.empty?

      "#{path}?#{query}"
    end

    def origin_query?(uri)
      uri.path.to_s.empty? && uri.query.to_s.empty?
    end

    def page_query_target(record, fallback:)
      final_url = record["final_url"].to_s
      return fallback if final_url.empty?

      request_target(parse_http_uri(final_url))
    end

    def robots_uri(uri)
      "#{base_origin(uri)}/robots.txt"
    end

    def tdmrep_uri(uri)
      "#{base_origin(uri)}/.well-known/tdmrep.json"
    end

    def trusttxt_uri(uri)
      "#{base_origin(uri)}/trust.txt"
    end

    def trusttxt_well_known_uri(uri)
      "#{base_origin(uri)}/.well-known/trust.txt"
    end

    def base_origin(uri)
      port = if (uri.scheme == "https" && uri.port == 443) || (uri.scheme == "http" && uri.port == 80)
               nil
             else
               ":#{uri.port}"
             end
      "#{uri.scheme}://#{uri.host}#{port}"
    end

    def origin_key(uri)
      base_origin(uri)
    end

    def parse_http_uri(value)
      uri = URI.parse(value.to_s.strip)
      unless uri.is_a?(URI::HTTP) && uri.host
        raise ArgumentError, "unsupported url: #{value}"
      end

      uri
    rescue URI::InvalidURIError
      raise ArgumentError, "unsupported url: #{value}"
    end

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

    def first_header_value(headers, name)
      Array(headers[name]).first.to_s.strip
    end

    def html_content?(headers, body)
      content_type = first_header_value(headers, "content-type")
      return true if content_type.include?("text/html") || content_type.include?("application/xhtml+xml")

      body.to_s.lstrip.start_with?("<!DOCTYPE html", "<html", "<HTML")
    end

    def parse_meta_tags(body)
      body.to_s.scan(/<meta\b[^>]*>/im).map do |tag|
        tag.scan(/([A-Za-z_:.-]+)\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s"'=<>`]+))/).each_with_object({}) do |(name, quoted, single, bare), attributes|
          attributes[name.downcase] = CGI.unescapeHTML(quoted || single || bare || "")
        end
      end
    end

    def json_like_response?(headers, body)
      content_type = first_header_value(headers, "content-type")
      return true if content_type.include?("application/json") || content_type.include?("application/ld+json")

      stripped = body.to_s.lstrip
      stripped.start_with?("{", "[")
    end

    def sort_robot_signals(signals)
      signals.sort_by do |signal|
        prefix = signal_sort_prefix(signal)
        [
          prefix.first,
          wildcard_signal?(signal) ? 1 : 0,
          prefix.last,
          signal.dig("conditions", "user-agent").to_s
        ]
      end
    end
  end
end
