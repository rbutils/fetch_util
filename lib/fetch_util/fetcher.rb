# frozen_string_literal: true

require "uri"

module FetchUtil
  class Fetcher
    HOMEPAGE_INDEX_PATTERN = Regexp.new(
      "top stories|breaking news|latest news|headlines|" \
      "aktuelle nachrichten|schlagzeilen|neueste nachrichten|" \
      "à la une|dernières nouvelles|actualités|últimas noticias|" \
      "noticias principales|notizie principali|ultime notizie|" \
      "najnowsze wiadomości|najważniejsze|ostatnie wiadomości|aktualności|" \
      "actualiteit|laatste nieuws|senaste nyheter|seneste nyheder|" \
      "siste nytt|tuoreimmat uutiset|aktuálně|legfrissebb|" \
      "cele mai noi știri|aktualności|најновије вести|останні новини|" \
      "τελευταία νέα|güncel haberler|son dakika|senaste nyheterna|" \
      "viktigaste nyheterna|aktualitātes|jaunākās ziņas|naujienos|" \
      "svarbiausios naujienos|главные новости|últimas notícias|" \
      "najnovšie správy|najnovije vijesti|derniers articles",
      Regexp::IGNORECASE
    ).freeze
    DOCS_PORTAL_TITLE_PATTERN = /documentation|docs|the ultimate server/i
    INDEX_OR_SEARCH_PATH_PATTERN = %r{
      /(?:search|s|shop|browse|category|categories|collections?|catalog|keyword|wholesale|
      products?|projects?|jobs?|section|sections|topics?|tags?|archive|archives|latest|headlines|news)/?
    }ix
    AUTH_PATH_PATTERN = %r{
      /(?:log(?:in|-in)|sign(?:in|-in)|auth|oauth|sso|session|sessions|
      accounts?/login|users?/sign_in|password|forgot)(?:/|$)
    }ix
    ARTICLE_PATH_PATTERN = %r{
      /(?:20\d{2}|\d{4}/\d{2}/\d{2}|article|articles|blog|blogs|column|columns|
      entry|entries|post|posts|news/[\w-]+|wiki|dictionary|definition|definitions|thesaurus|\d{5,}[\w-]*\.html?)\b
    }ix
    LINKED_MARKDOWN_HEADING_PATTERN = /(?:^|\s)(?:(?:\d+\.|[-*])\s+)?\#{1,4}\s+\[[^\]]{8,220}\]\(/
    LINKED_MARKDOWN_ITEM_PATTERN = /(?:^|\s)(?:\d+\.|[-*])\s+\[[^\]]{8,220}\]\(/
    INDEX_QUERY_PATTERN = /(?:^|[&?])(?:q|query|search|searchtext|keyword|k)=/i
    PDF_PATH_PATTERN = %r{(?:\.pdf\z|/pdf(?:/|\z)|[?&](?:format|download)=pdf\b)}i
    STRIPPED_QUERY_PARAM_PATTERNS = [
      /\A(?:__goaway_|__cf_chl_)/,
      /\A(?:utm_[a-z]+|fbclid|gclid|mc_cid|mc_eid)\z/,
      /\A__gr(?:sc|ts|ua|rn)\z/
    ].freeze
    TITLE_SLUG_STOPWORDS = %w[
      about all and article articles blog book books browse category categories chapter
      collection collections content docs edition editions en for from guide home html
      index latest new news page pages post posts product products search show shop st
      street tag tags the this topic topics unit with work works www your
    ].freeze
    SEARCH_OR_LIST_PATH_SEGMENTS = %w[
      archive archives browse catalog categories category collection collections headlines
      jobs keyword latest news product products projects s search section sections shop
      tag tags topic topics wholesale
    ].freeze
    SECOND_LEVEL_COUNTRY_TLDS = /\A(co|com|org|net|gov|edu|ac)\z/
    GOOGLE_HOST_PATTERN = /\Agoogle\.[a-z.]+\z/

    def initialize(browser: nil, extractor: nil, **options)
      @timeout = options.fetch(:timeout, 20)
      @browser = browser || Browser.new(**browser_options(options))
      @extractor = extractor || Extractor.new(reader_mode: options.fetch(:reader_mode, true))
      @raw_docs_fallback = options[:raw_docs_fallback] || RawDocsFallback.new(timeout: @timeout)
      @request_log = options[:request_log]
    end

    def quit
      @browser.quit
    end

    def fetch(url)
      t0 = monotonic_now
      result = @browser.with_page(url) do |page|
        payload = @extractor.extract(page)
        build_result(url, page.current_url, payload)
      end
      fallback = docs_fallback_candidate?(url, result) && poor_docs_result?(result) ? @raw_docs_fallback.fetch(url) : nil
      fallback ||= article_body_fallback_candidate?(result) ? @raw_docs_fallback.fetch(result.final_url) : nil
      result = fallback_result(url, fallback) if fallback
      log_request(url, t0)
      result
    rescue BrowserError, ExtractionError => e
      fallback = docs_fallback_candidate?(url) ? @raw_docs_fallback.fetch(url) : nil
      if fallback
        result = fallback_result(url, fallback)
        log_request(url, t0)
        return result
      end

      log_request(url, t0)
      raise e
    end

    private

    def build_result(url, final_url, payload)
      final_url = normalized_result_url(final_url)
      canonical_url = normalized_result_url(payload["canonicalUrl"])
      homepage_like = homepage_like?(final_url)
      content_type = resolved_content_type(final_url, homepage_like, payload)
      warnings = resolved_warnings(
        content_type, homepage_like, payload,
        requested_url: url, final_url: final_url, canonical_url: canonical_url
      )
      suspect = warnings.any?
      completeness_ratio = payload["contentCompletenessRatio"]&.to_f || 1.0
      content_format = payload["contentFormat"]
      paywall_state = payload["paywallState"]

      metadata = {
        title: payload["title"],
        byline: payload["byline"],
        excerpt: payload["excerpt"],
        site_name: payload["siteName"],
        published_time: payload["publishedTime"],
        canonical_url: canonical_url,
        language: payload["language"],
        content_url: final_url,
        reader_mode: payload["readerMode"],
        content_type: content_type,
        suspect: suspect,
        warnings: warnings,
        content_completeness_ratio: completeness_ratio,
        content_format: content_format,
        paywall_state: paywall_state
      }.freeze

      Result.new(
        url: url,
        final_url: final_url,
        title: payload["title"],
        byline: payload["byline"],
        excerpt: payload["excerpt"],
        site_name: payload["siteName"],
        published_time: payload["publishedTime"],
        canonical_url: canonical_url,
        language: payload["language"],
        html: payload["html"],
        markdown: payload["markdown"],
        metadata: metadata,
        reader_mode: payload["readerMode"],
        content_type: content_type,
        suspect: suspect,
        warnings: warnings,
        content_completeness_ratio: completeness_ratio,
        content_format: content_format,
        paywall_state: paywall_state
      )
    end

    def resolved_content_type(final_url, homepage_like, payload)
      content_type = payload["contentType"] || "article"
      return content_type unless content_type == "article"
      return content_type if payload["hostAware"]
      return "list" if homepage_like && homepage_index_markdown?(payload["title"], payload["markdown"])
      return "list" if index_list_markdown?(final_url, payload)
      return "list" if thin_index_page?(final_url, payload)

      content_type
    end

    def resolved_warnings(content_type, homepage_like, payload, requested_url: nil, final_url: nil, canonical_url: nil)
      warnings = Array(payload["warnings"]).dup
      if content_type == "list" && homepage_like && !payload["statusPage"] && !substantial_homepage_landing?(payload)
        warnings << "homepage_index_page"
      end
      warnings << "cross_domain_redirect" if cross_domain_redirect?(requested_url, final_url)
      warnings << "aggregator_redirect_url" if aggregator_url?(requested_url)
      warnings << "auth_or_login_interstitial" if auth_redirect_interstitial?(requested_url, final_url, payload)
      warnings << "pdf_document" if pdf_document?(requested_url, final_url, payload)
      if redirected_title_content_mismatch?(content_type, homepage_like, payload, requested_url, final_url, canonical_url)
        warnings << "url_content_mismatch"
      end
      warnings.uniq
    end

    def homepage_like?(url)
      path = URI.parse(url).path
      path.nil? || path.empty? || path == "/"
    rescue URI::InvalidURIError
      false
    end

    def homepage_index_markdown?(title, markdown)
      snippet = [title, markdown].compact.join(" ")
      return false unless snippet.match?(HOMEPAGE_INDEX_PATTERN)

      markdown.to_s.lines.grep(/^\s*(?:\d+\.\s+|[-*]\s+)/).count >= 3
    end

    def substantial_homepage_landing?(payload)
      markdown = payload["markdown"].to_s
      normalized = FetchUtil.normalize_whitespace(markdown)
      return false if normalized.length < 1_200

      context = FetchUtil.normalize_whitespace([payload["title"], payload["siteName"], markdown].join(" ")).downcase
      landing_pattern = /\b(docs?|documentation|api|reference|guide|guides|developer|framework|next\.js|mdx|
        static websites?|components?|themes?|product|platform)\b/x
      return false unless context.match?(landing_pattern)

      prose_lines = markdown.lines.reject { |line| line.match?(/^\s*(?:#|[-*]\s+|\d+\.\s+)/) }
      prose_lines.any? { |line| FetchUtil.normalize_whitespace(line).length >= 120 }
    end

    def index_list_markdown?(url, payload)
      return false unless index_or_search_url?(url)
      return false if article_like_url?(url)

      markdown = payload["markdown"].to_s
      linked_headlines = markdown.scan(LINKED_MARKDOWN_HEADING_PATTERN).count
      linked_items = markdown.scan(LINKED_MARKDOWN_ITEM_PATTERN).count

      linked_headlines + linked_items >= 4
    end

    def thin_index_page?(url, payload)
      return false unless index_or_search_url?(url)
      return false if article_like_url?(url)
      return false if payload["byline"].to_s.strip != "" || payload["publishedTime"].to_s.strip != ""

      markdown = FetchUtil.normalize_whitespace(payload["markdown"].to_s)
      markdown.length < 2400
    end

    def index_or_search_url?(url)
      uri = URI.parse(url)
      path = uri.path.to_s
      return true if path.match?(INDEX_OR_SEARCH_PATH_PATTERN)
      return true if uri.query.to_s.match?(INDEX_QUERY_PATTERN)

      segments = path.split("/").reject(&:empty?)
      segments.length.between?(1, 2) && !segments.last.to_s.include?("-") &&
        !path.match?(/\.(?:html?|php|aspx?|jsp)\z/i)
    rescue URI::InvalidURIError
      false
    end

    def article_like_url?(url)
      URI.parse(url).path.to_s.match?(ARTICLE_PATH_PATTERN)
    rescue URI::InvalidURIError
      false
    end

    def auth_redirect_interstitial?(requested_url, final_url, payload)
      return false if requested_url.nil? || final_url.nil?
      return false unless auth_path?(final_url)
      return false if auth_path?(requested_url)
      return false unless index_or_search_url?(requested_url)

      text = FetchUtil.normalize_whitespace([payload["title"], payload["markdown"], payload["excerpt"]].compact.join(" ")).downcase
      text.match?(/\b(?:log in|login|sign in|sign-in)\b/) &&
        text.match?(/\b(?:github|gitlab|google|oauth|sso|single sign-on|password|account)\b/)
    end

    def auth_path?(url)
      URI.parse(url).path.to_s.match?(AUTH_PATH_PATTERN)
    rescue URI::InvalidURIError
      false
    end

    def pdf_document?(requested_url, final_url, payload)
      return true if payload["contentType"].to_s == "pdf"

      [requested_url, final_url, payload["canonicalUrl"]].compact.any? do |url|
        parsed = URI.parse(url)
        [parsed.path, parsed.query].compact.join("?").match?(PDF_PATH_PATTERN)
      end
    rescue URI::InvalidURIError
      false
    end

    def article_body_fallback_candidate?(result)
      return false unless result.content_type == "list"
      return false if result.byline.to_s.strip.empty? && result.published_time.to_s.strip.empty?
      return false unless article_like_url?(result.final_url) || slug_article_url?(result.final_url)

      markdown = result.markdown.to_s
      markdown.length < 1_500 && markdown.lines.grep(/^\s*[-*]\s+\[/).count >= 4
    end

    def slug_article_url?(url)
      segments = URI.parse(url).path.to_s.split("/").reject(&:empty?)
      segments.length == 1 && segments.first.include?("-")
    rescue URI::InvalidURIError
      false
    end

    def redirected_title_content_mismatch?(content_type, homepage_like, payload, requested_url, final_url, canonical_url)
      return false unless content_type == "article"
      return false if homepage_like || payload["docsLike"]
      return false if requested_url.nil? || final_url.nil?
      return false if [requested_url, final_url, canonical_url].compact.any? { |url| search_or_list_resource_url?(url) }

      resource_url = mismatched_resource_url(requested_url, final_url, canonical_url)
      return false if resource_url.nil?

      requested_keywords = title_slug_keywords(requested_url)
      return false if requested_keywords.length < 2

      resolved_keywords = significant_slug_tokens([resource_url, payload["title"]].compact.join(" "))
      return false if resolved_keywords.empty?

      (requested_keywords & resolved_keywords).empty?
    end

    def mismatched_resource_url(requested_url, final_url, canonical_url)
      requested_path = normalized_path_key(requested_url)
      return nil if requested_path.empty?

      final_path = normalized_path_key(final_url)
      return final_url if !final_path.empty? && final_path != requested_path

      return nil unless same_effective_domain?(final_url, canonical_url)

      canonical_path = normalized_path_key(canonical_url)
      return canonical_url if !canonical_path.empty? && canonical_path != requested_path

      nil
    end

    def same_effective_domain?(left_url, right_url)
      return false if left_url.nil? || right_url.nil?

      left_domain = effective_domain(left_url)
      right_domain = effective_domain(right_url)
      !left_domain.nil? && left_domain == right_domain
    end

    def search_or_list_resource_url?(url)
      uri = URI.parse(url)
      return true if uri.query.to_s.match?(INDEX_QUERY_PATTERN)

      uri.path.to_s.split("/").reject(&:empty?).any? do |segment|
        SEARCH_OR_LIST_PATH_SEGMENTS.include?(segment.downcase)
      end
    rescue URI::InvalidURIError
      false
    end

    def normalized_path_key(url)
      path = URI.parse(url).path.to_s.downcase.gsub(%r{/+}, "/")
      path = path.delete_suffix("/") unless path == "/"
      path
    rescue URI::InvalidURIError
      ""
    end

    def title_slug_keywords(url)
      URI.parse(url).path.to_s.split("/").reject(&:empty?).reverse_each do |segment|
        tokens = significant_slug_tokens(segment)
        return tokens if tokens.length >= 2
      end

      []
    rescue URI::InvalidURIError
      []
    end

    def significant_slug_tokens(text)
      decoded = URI.decode_www_form_component(text.to_s.tr("+", " "))
      decoded.downcase.gsub(/[^a-z0-9]+/, " ").split.select do |token|
        token.length >= 3 && token.match?(/[a-z]/) && !token.match?(/\d/) &&
          !TITLE_SLUG_STOPWORDS.include?(token)
      end.uniq
    rescue ArgumentError
      []
    end

    def fallback_result(url, fallback)
      build_result(url, *fallback)
    end

    def docs_fallback_candidate?(requested_url, result = nil)
      candidates = [requested_url]
      if result
        candidates << result.final_url
        candidates << result.canonical_url
      end

      candidates.compact.any? { |candidate| FetchUtil.docs_like_url?(candidate) }
    end

    def browser_options(options)
      options.slice(:timeout, :wait, :wait_for_idle, :idle_duration, :viewport,
                    :user_agent, :accept_language, :browser_path, :browser_options)
    end

    def log_request(url, t0)
      @request_log&.append(url, duration: monotonic_now - t0)
    end

    def monotonic_now
      Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end

    def poor_docs_result?(result)
      markdown = result.markdown.to_s
      title = result.title.to_s
      text_length = FetchUtil.normalize_whitespace(markdown).length

      return true if result.warnings.include?("not_found_interstitial") || result.warnings.include?("empty_extraction") || result.warnings.include?("short_extraction")
      return true if markdown.include?("Interstitial: requested page is unavailable")
      return true if text_length < 160 && title.match?(DOCS_PORTAL_TITLE_PATTERN)
      return true if title.match?(DOCS_PORTAL_TITLE_PATTERN) && markdown.scan(/^# /).length >= 2

      false
    end

    def effective_domain(url)
      host = FetchUtil.strip_www_host(url)
      parts = host.split(".")
      return host if parts.length <= 2

      if parts.length >= 3 && parts[-2].match?(SECOND_LEVEL_COUNTRY_TLDS) && parts[-1].length == 2
        parts.last(3).join(".")
      else
        parts.last(2).join(".")
      end
    rescue URI::InvalidURIError
      nil
    end

    def cross_domain_redirect?(requested_url, final_url)
      return false if requested_url.nil? || final_url.nil?

      req_domain = effective_domain(requested_url)
      fin_domain = effective_domain(final_url)
      return false if req_domain.nil? || fin_domain.nil?

      req_domain != fin_domain
    end

    def aggregator_url?(url)
      return false if url.nil?

      host = FetchUtil.strip_www_host(url)
      path = URI.parse(url).path.to_s

      return true if host == "news.google.com"

      return true if host == "cdn.ampproject.org" || host.end_with?(".cdn.ampproject.org")

      return true if host.match?(GOOGLE_HOST_PATTERN) && path == "/url"

      false
    rescue URI::InvalidURIError
      false
    end

    def normalized_result_url(url)
      return url if url.nil? || url.empty?

      uri = URI.parse(url)
      params = URI.decode_www_form(uri.query.to_s)
      params.reject! { |key, _value| STRIPPED_QUERY_PARAM_PATTERNS.any? { |pattern| key.match?(pattern) } }
      uri.query = params.empty? ? nil : URI.encode_www_form(params)
      uri.to_s
    rescue URI::InvalidURIError
      url
    end
  end
end
