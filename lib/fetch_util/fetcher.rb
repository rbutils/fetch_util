# frozen_string_literal: true

require "uri"

module FetchUtil
  class Fetcher
    def initialize(browser: nil, extractor: nil, **options)
      @timeout = options.fetch(:timeout, 20)
      @browser = browser || Browser.new(**browser_options(options))
      @extractor = extractor || Extractor.new(reader_mode: options.fetch(:reader_mode, true))
      @raw_docs_fallback = options[:raw_docs_fallback] || RawDocsFallback.new(timeout: @timeout)
      @request_log = options[:request_log]
    end

    # Shut down the underlying browser process. Delegates to +Browser#quit+.
    # Safe to call multiple times.
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
      result = build_result(url, *fallback) if fallback
      log_request(url, t0)
      result
    rescue BrowserError, ExtractionError => e
      fallback = docs_fallback_candidate?(url) ? @raw_docs_fallback.fetch(url) : nil
      if fallback
        result = build_result(url, *fallback)
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
      content_type = resolved_content_type(homepage_like, payload)
      warnings = resolved_warnings(content_type, homepage_like, payload, requested_url: url, final_url: final_url)
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

    def resolved_content_type(homepage_like, payload)
      content_type = payload["contentType"] || "article"
      return content_type unless content_type == "article"
      return "list" if homepage_like && homepage_index_markdown?(payload["title"], payload["markdown"])

      content_type
    end

    def resolved_warnings(content_type, homepage_like, payload, requested_url: nil, final_url: nil)
      warnings = Array(payload["warnings"]).dup
      warnings << "homepage_index_page" if content_type == "list" && homepage_like
      warnings << "cross_domain_redirect" if cross_domain_redirect?(requested_url, final_url)
      warnings << "aggregator_redirect_url" if aggregator_url?(requested_url)
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
      # Multilingual homepage indicator phrases
      return false unless snippet.match?(
        Regexp.new(
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
        )
      )

      markdown.to_s.lines.grep(/^\s*(?:\d+\.\s+|[-*]\s+)/).count >= 3
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
      return true if text_length < 160 && title.match?(/documentation|docs|the ultimate server/i)
      return true if title.match?(/documentation|docs|the ultimate server/i) && markdown.scan(/^# /).length >= 2

      false
    end

    # Extract the registrable domain (eTLD+1 approximation) from a URL.
    # Strips www. prefix and returns the last two dot-separated labels
    # (or three when the second-level label is a known country ccTLD part like co.uk).
    def effective_domain(url)
      host = FetchUtil.strip_www_host(url)
      parts = host.split(".")
      return host if parts.length <= 2

      # Handle common two-part TLDs: co.uk, com.au, co.jp, com.br, etc.
      if parts.length >= 3 && parts[-2].match?(/\A(co|com|org|net|gov|edu|ac)\z/) && parts[-1].length == 2
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

    # Detect URLs that point to news aggregators or redirect services rather than
    # direct article pages. These URLs typically redirect to the actual publisher
    # and are unreliable as stable source references.
    def aggregator_url?(url)
      return false if url.nil?

      host = FetchUtil.strip_www_host(url)
      path = URI.parse(url).path.to_s

      # Google News: news.google.com (RSS feeds, redirect links)
      return true if host == "news.google.com"

      # Google AMP cache: serves cached AMP versions, not canonical URLs
      return true if host == "cdn.ampproject.org" || host.end_with?(".cdn.ampproject.org")

      # Google redirect URLs (e.g. google.com/url?...)
      return true if host.match?(/\Agoogle\.[a-z.]+\z/) && path == "/url"

      false
    rescue URI::InvalidURIError
      false
    end

    def normalized_result_url(url)
      return url if url.nil? || url.empty?

      uri = URI.parse(url)
      params = URI.decode_www_form(uri.query.to_s)
      params.reject! do |key, _value|
        key.match?(/\A(?:__goaway_|__cf_chl_)/) ||
          key.match?(/\A(?:utm_[a-z]+|fbclid|gclid|mc_cid|mc_eid)\z/) ||
          key.match?(/\A__gr(?:sc|ts|ua|rn)\z/)
      end
      uri.query = params.empty? ? nil : URI.encode_www_form(params)
      uri.to_s
    rescue URI::InvalidURIError
      url
    end
  end
end
