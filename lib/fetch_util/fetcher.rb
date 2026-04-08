# frozen_string_literal: true

require "uri"

module FetchUtil
  class Fetcher
    def initialize(browser: nil, extractor: nil, **options)
      @timeout = options.fetch(:timeout, 20)
      @browser = browser || Browser.new(**browser_options(options))
      @extractor = extractor || Extractor.new(reader_mode: options.fetch(:reader_mode, true))
      @raw_docs_fallback = options[:raw_docs_fallback] || RawDocsFallback.new(timeout: @timeout)
    end

    # Shut down the underlying browser process. Delegates to +Browser#quit+.
    # Safe to call multiple times.
    def quit
      @browser.quit
    end

    def fetch(url)
      result = @browser.with_page(url) do |page|
        payload = @extractor.extract(page)
        build_result(url, page.current_url, payload)
      end
      fallback = docs_fallback_candidate?(url, result) && poor_docs_result?(result) ? @raw_docs_fallback.fetch(url) : nil
      return build_result(url, *fallback) if fallback

      result
    rescue BrowserError, ExtractionError => e
      fallback = docs_fallback_candidate?(url) ? @raw_docs_fallback.fetch(url) : nil
      return build_result(url, *fallback) if fallback

      raise e
    end

    private

    def build_result(url, final_url, payload)
      final_url = normalized_result_url(final_url)
      canonical_url = normalized_result_url(payload["canonicalUrl"])
      homepage_like = homepage_like?(final_url)
      content_type = resolved_content_type(homepage_like, payload)
      warnings = resolved_warnings(content_type, homepage_like, payload)
      suspect = warnings.any?

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
        warnings: warnings
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
        warnings: warnings
      )
    end

    def resolved_content_type(homepage_like, payload)
      content_type = payload["contentType"] || "article"
      return content_type unless content_type == "article"
      return "list" if homepage_like && homepage_index_markdown?(payload["title"], payload["markdown"])

      content_type
    end

    def resolved_warnings(content_type, homepage_like, payload)
      warnings = Array(payload["warnings"]).dup
      warnings << "homepage_index_page" if content_type == "list" && homepage_like
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
      return false unless snippet.match?(/top stories|breaking news|latest news|headlines/i)

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
