# frozen_string_literal: true

require "cgi"
require "uri"

module FetchUtil
  class Searcher
    MAX_SNIPPET_LENGTH = 180

    SOURCES = {
      "duckduckgo" => "https://duckduckgo.com/?q=%<query>s&ia=web&kl=us-en",
      "google" => "https://www.google.com/search?hl=en&q=%<query>s",
      "bing" => "https://www.bing.com/search?setlang=en-US&q=%<query>s",
      "ecosia" => "https://www.ecosia.org/search?q=%<query>s",
      "brave" => "https://search.brave.com/search?q=%<query>s"
    }.freeze

    DEFAULT_SOURCES = %w[duckduckgo google].freeze

    autoload :ResultFiltering, "fetch_util/searcher/result_filtering"
    include ResultFiltering
    private_constant :ResultFiltering

    def initialize(fetcher: nil, request_log: RequestLog.new, sources: nil, limit: 10, concurrency: 2, verbose: false, **fetch_options)
      @request_log = request_log
      @sources = Array(sources || DEFAULT_SOURCES).map(&:to_s)
      @limit = limit.to_i
      @verbose = verbose
      @fetcher = fetcher || ParallelFetcher.new(concurrency: concurrency, request_log: request_log, **fetch_options)
    end

    def search(query)
      encoded_query = query.to_s.strip
      raise ArgumentError, "query must not be empty" if encoded_query.empty?

      urls = search_urls(encoded_query)
      @request_log.append(search_request_uri(encoded_query))
      fetched = begin
        @fetcher.fetch(urls.values)
      rescue ParallelFetcher::ParallelFetchError => e
        raise unless e.results&.compact&.any?

        e.results
      end

      {
        query: encoded_query,
        results: formatted_results(aggregate(urls.keys, fetched).first(limit))
      }
    end

    private

    attr_reader :limit

    def search_urls(query)
      urls = {}

      @sources.each do |source|
        template = SOURCES.fetch(source) do
          raise ArgumentError, "unsupported search source: #{source}"
        end
        urls[source] = format(template, query: CGI.escape(query))
      end

      urls
    end

    def search_request_uri(query)
      "search://#{@sources.join(",")}?q=#{CGI.escape(query)}"
    end

    def aggregate(sources, fetched)
      parsed = {}
      max_size = 0

      sources.zip(fetched).each do |source, result|
        items = parse_markdown(result.markdown)
        parsed[source] = items
        max_size = [max_size, items.length].max
      end

      items = []
      seen = {}

      max_size.times do |index|
        sources.each do |source|
          item = parsed.fetch(source)[index]
          next unless item

          item = item.merge(rank: index + 1)

          existing = seen[item[:url]]
          if existing
            merge_result!(existing, source, item)
            next
          end

          result = build_result(source, item)
          seen[item[:url]] = result
          items << result
        end
      end

      items
    end

    def build_result(source, item)
      result = {
        title: item[:title],
        url: item[:url],
        sources: [source],
        ranks: { source => item[:rank] }
      }
      result[:snippet] = item[:snippet] if item[:snippet]
      result
    end

    def merge_result!(result, source, item)
      result[:sources] << source unless result[:sources].include?(source)
      result[:ranks][source] ||= item[:rank]
      return if !item[:snippet] || (result[:snippet] && result[:snippet].length >= item[:snippet].length)

      result[:snippet] = item[:snippet]
    end

    def formatted_results(results)
      results.map do |result|
        item = {
          title: result[:title],
          url: result[:url]
        }
        item[:snippet] = result[:snippet] if result[:snippet]
        if @verbose
          item[:sources] = result[:sources]
          item[:ranks] = result[:ranks]
        end
        item
      end
    end

    def parse_markdown(markdown)
      markdown.to_s.lines.filter_map do |line|
        parsed = parse_markdown_line(line)
        next unless parsed

        normalized_item(parsed[:title], parsed[:url], parsed[:snippet])
      end
    end

    def parse_markdown_line(line)
      stripped = line.to_s.strip
      return nil unless stripped.start_with?("- [")

      title_end = stripped.index("](")
      return nil unless title_end

      url_start = title_end + 2
      url_end = markdown_url_end_index(stripped, url_start)
      return nil unless url_end

      title = stripped[3...title_end]
      url = stripped[url_start...url_end]
      remainder = stripped[(url_end + 1)..].to_s
      snippet = remainder.start_with?(" - ") ? remainder[3..] : nil

      { title: title, url: url, snippet: snippet }
    end

    def markdown_url_end_index(line, url_start)
      depth = 0

      url_start.upto(line.length - 1) do |index|
        char = line[index]
        if char == "("
          depth += 1
        elsif char == ")"
          return index if depth.zero?

          depth -= 1
        end
      end

      nil
    end

    def normalized_item(title, url, snippet)
      normalized_url = normalize_url(url)
      return nil unless normalized_url

      normalized_title = normalize_title(title, normalized_url)
      return nil if normalized_title.empty? || generic_title?(normalized_title, normalized_url)

      normalized_snippet = normalize_snippet(snippet, normalized_title, normalized_url)
      return nil if search_engine_self_link?(normalized_title, normalized_url, normalized_snippet)
      return nil if low_value_result?(normalized_title, normalized_url, normalized_snippet)

      item = {
        title: normalized_title,
        url: normalized_url
      }

      item[:snippet] = normalized_snippet if normalized_snippet
      item
    end

    def compact_text(value)
      FetchUtil.normalize_whitespace(value)
    end

    def normalize_url(url)
      parsed = URI.parse(url.to_s.strip)
      return nil unless parsed.is_a?(URI::HTTP) && parsed.host

      parsed.host = parsed.host.downcase
      parsed.path = "/" if parsed.path.to_s.empty?
      parsed.path = parsed.path.sub(%r{/$}, "") unless parsed.path == "/"
      parsed.fragment = nil unless keep_fragment?(parsed)
      parsed.to_s
    rescue URI::InvalidURIError
      nil
    end

    def host_for(url)
      FetchUtil.strip_www_host(url)
    rescue URI::InvalidURIError
      nil
    end

    def path_for(url)
      URI.parse(url).path.to_s
    rescue URI::InvalidURIError
      ""
    end

    def generic_title?(title, url)
      return true if title.start_with?("More on ")

      host = host_for(url)
      return false if host.nil? || host.empty?

      title.casecmp?(host)
    end

    def normalize_title(title, url)
      text = compact_text(title)
      host = host_for(url)

      if host && !host.empty?
        trimmed = text.sub(/\A#{Regexp.escape(host)}\s+/i, "")
        text = trimmed if trimmed.length >= 8
      end

      text = text.sub(/\A(?:[[:alnum:].-]+\s+[>›]\s+)+/, "")
      text = strip_slug_prefix(text)
      compact_text(text)
    end

    def keep_fragment?(uri)
      fragment = compact_text(uri.fragment)
      return false if fragment.empty?
      return false if noise_fragment?(fragment)

      FetchUtil.docs_like_url?(uri)
    end

    def noise_fragment?(fragment)
      fragment.match?(/\A(?:top|contents?|content|main|main-content|skip(?:-to)?-(?:content|main)|toc)\z/i)
    end

    def strip_slug_prefix(text)
      match = text.match(/\A([a-z0-9-]{4,})\s+(?=[A-Z])/)
      return text unless match

      prefix = match[1].downcase
      return text unless prefix.match?(/[-\d]/) || %w[api blog doc docs guide guides help kb learn manual reference tutorial wiki].include?(prefix)

      text.sub(/\A#{Regexp.escape(match[1])}\s+/, "")
    end

    def normalize_snippet(snippet, title, url)
      text = compact_text(snippet)
      text = text.sub(/\A#{Regexp.escape(title)}\s*/i, "")
      text = text.gsub(%r{https?://\S+}, " ")
      text = text.sub(/\A[[:word:].-]+\s*(?:[>›]\s*[[:word:]_.()%-]+\s*)+/, "")
      text = compact_text(text)
      return nil if text.empty? || text.casecmp?(title)

      host = host_for(url)
      return nil if domain_only?(text, host)
      return nil if breadcrumb_text?(text)
      return nil if metadata_only_snippet?(text)
      return nil if jammed_navigation_text?(text)

      truncate(text, MAX_SNIPPET_LENGTH)
    end

    def truncate(text, max_length)
      return text if text.length <= max_length

      "#{text[0, max_length - 3].rstrip}..."
    end

    def domain_only?(text, host)
      return true if text.match?(/\A[a-z0-9.-]+\.[a-z]{2,}\z/i)
      return false if host.nil? || host.empty?

      text.casecmp?(host)
    end

    def jammed_navigation_text?(text)
      text.length > 20 && !text.include?(" ") && text.scan(/[A-Z]/).length >= 3
    end

    def breadcrumb_text?(text)
      text.include?("›") || text.match?(/(?:\A|\s)>|>\s/)
    end

    def metadata_only_snippet?(text)
      normalized = text.gsub(/([[:alpha:]])(\d)/, '\1 \2').gsub(/(\d)([[:alpha:]])/, '\1 \2')
      site = normalized.match?(/\A(?:Reddit|Stack Overflow|Medium)\b/i)
      counters = normalized.match?(/\b\d+\+?\s*(?:comments?|answers?|likes?)\b/i)
      age = normalized.match?(/\b\d+\s*(?:years?|months?|days?|hours?|minutes?)\s+ago\b/i)

      site && (counters || age)
    end
  end
end
