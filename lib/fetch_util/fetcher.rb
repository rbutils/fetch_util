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
    LEGAL_STATUTE_TITLE_PATTERN = Regexp.new(
      "constitution|constitutional|constitui[cç]?[aã]o|c[oó]digo|codigo|code|statute|act|law|" \
      "regulation|ordinance|decree|treaty|convention",
      Regexp::IGNORECASE
    ).freeze
    LEGAL_PROVISION_MARKER_PATTERN = /(?:^|\s)(?:Art\.?|Article|Section|Sec\.?|§)\s*(?:\d+[ºª]?|[IVXLCDM]+)/i
    LEGAL_PROVISION_STRUCTURAL_PATTERN = /\b(?:title|chapter|part|book|t[ií]tulo|cap[ií]tulo|se[cç][aã]o)\s+(?:[IVXLCDM]+|\d+)/i
    LEGAL_PROVISION_TERMS_PATTERN = Regexp.new(
      "federal republic|rep[úu]blica federativa|republica federativa|civil rights|fundamental rights|" \
      "legal provisions?|official gazette|promulgat|enacted|amended|paragraph|par[áa]grafo|paragrafo|" \
      "inciso|subsection",
      Regexp::IGNORECASE
    ).freeze
    TRACKING_QUERY_PARAM_PATTERNS = [
      /\A(?:__goaway_|__cf_chl_)/,
      /\A(?:utm_[a-z]+|fbclid|gclid|lp|mc_cid|mc_eid|ref|source)\z/i,
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
    CONTENT_ROUTE_SEGMENTS = %w[article articles content paper papers preprint preprints].freeze
    SECOND_LEVEL_COUNTRY_TLDS = /\A(co|com|org|net|gov|edu|ac)\z/
    GOOGLE_HOST_PATTERN = /\Agoogle\.[a-z.]+\z/
    NETWORK_ERROR_PATTERN = Regexp.new(
      "\\b(?:net::ERR_|ERR_NAME_NOT_RESOLVED|DNS|resolve|resolution|ENOTFOUND|" \
      "EAI_AGAIN|ECONNREFUSED|ECONNRESET|ETIMEDOUT|timed out|timeout|" \
      "connection (?:refused|reset|closed)|disconnected|network)\\b",
      Regexp::IGNORECASE
    ).freeze

    class PayloadSnapshot
      attr_reader :payload, :requested_url, :final_url, :canonical_url, :raw_final_url, :raw_canonical_url,
                  :markdown, :normalized_markdown, :content_downcase, :context, :context_downcase,
                  :context_with_excerpt_downcase, :first_20_context,
                  :first_80_context, :plain_list_item_count, :linked_heading_count, :linked_item_count,
                  :markdown_link_count, :prose_lines, :long_prose_line_count_one_hundred,
                  :long_prose_line_count_one_twenty, :long_prose_line_count_one_forty, :list_link_count,
                  :table_row_count, :heading_count, :common_tokens, :resource_urls, :raw_resource_urls,
                  :resource_url_facets

      def initialize(payload:, requested_url:, final_url:, canonical_url:, raw_final_url:, raw_canonical_url:)
        @payload = payload
        @requested_url = requested_url
        @final_url = final_url
        @canonical_url = canonical_url
        @raw_final_url = raw_final_url
        @raw_canonical_url = raw_canonical_url
        @markdown = payload["markdown"].to_s
        @normalized_markdown = FetchUtil.normalize_whitespace(@markdown)
        @content_downcase = FetchUtil.normalize_whitespace([payload["title"], @markdown].compact.join(" ")).downcase
        @context = FetchUtil.normalize_whitespace([payload["title"], payload["siteName"], @markdown].join(" "))
        @context_downcase = @context.downcase
        @context_with_excerpt_downcase = FetchUtil.normalize_whitespace(
          [payload["title"], @markdown, payload["excerpt"]].compact.join(" ")
        ).downcase
        @first_20_context = first_lines_context(20)
        @first_80_context = first_lines_context(80)
        @plain_list_item_count = @markdown.lines.grep(/^\s*(?:\d+\.\s+|[-*]\s+)/).count
        @linked_heading_count = @markdown.scan(Fetcher::LINKED_MARKDOWN_HEADING_PATTERN).count
        @linked_item_count = @markdown.scan(Fetcher::LINKED_MARKDOWN_ITEM_PATTERN).count
        @markdown_link_count = @markdown.scan(%r{\]\(https?://}).count
        @prose_lines = @markdown.lines.reject { |line| line.match?(/^\s*(?:#|[-*]\s+|\d+\.\s+)/) }
        @long_prose_line_count_one_hundred = long_prose_line_count(100)
        @long_prose_line_count_one_twenty = long_prose_line_count(120)
        @long_prose_line_count_one_forty = long_prose_line_count(140)
        @list_link_count = @markdown.lines.grep(/^\s*- \[/).count
        @table_row_count = @markdown.lines.grep(/^\|/).count
        @heading_count = @markdown.lines.grep(/^(?:#){1,3}\s+/).count
        @common_tokens = @context_downcase.scan(/[a-z0-9]{3,}/).uniq
        @resource_urls = [requested_url, final_url, canonical_url].compact
        @raw_resource_urls = [requested_url, raw_final_url, raw_canonical_url].compact
        @resource_url_facets = @resource_urls.to_h { |url| [url, url_facets(url)] }
      end

      def search_or_list_resource_url?(url)
        facet = resource_url_facets.fetch(url) { url_facets(url) }
        facet[:index_query] || facet[:search_or_list_path]
      end

      def path_key(url)
        resource_url_facets.fetch(url) { url_facets(url) }[:path_key]
      end

      private

      def first_lines_context(count)
        FetchUtil.normalize_whitespace([payload["title"], payload["siteName"], markdown.lines.first(count).join(" ")].join(" "))
      end

      def long_prose_line_count(length)
        prose_lines.count { |line| FetchUtil.normalize_whitespace(line).length >= length }
      end

      def url_facets(url)
        uri = URI.parse(url)
        path = uri.path.to_s
        segments = path.split("/").reject(&:empty?)
        {
          path_key: path.downcase.gsub(%r{/+}, "/").then { |value| value == "/" ? value : value.delete_suffix("/") },
          index_query: uri.query.to_s.match?(Fetcher::INDEX_QUERY_PATTERN),
          search_or_list_path: segments.any? { |segment| Fetcher::SEARCH_OR_LIST_PATH_SEGMENTS.include?(segment.downcase) }
        }
      rescue URI::InvalidURIError
        { path_key: "", index_query: false, search_or_list_path: false }
      end
    end

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
      fallback = seznam_cmp_redirect_fallback_candidate?(url, result) ? @raw_docs_fallback.fetch(url) : nil
      fallback ||= docs_fallback_candidate?(url, result) && poor_docs_result?(result) ? @raw_docs_fallback.fetch(url) : nil
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
      return network_error_result(url, e) if e.is_a?(BrowserError) && network_error?(e)

      raise e
    end

    private

    def build_result(url, final_url, payload)
      raw_final_url = final_url
      raw_canonical_url = payload["canonicalUrl"]
      final_url = normalized_result_url(final_url)
      canonical_url = normalized_result_url(raw_canonical_url)
      snapshot = PayloadSnapshot.new(
        payload: payload, requested_url: url, final_url: final_url, canonical_url: canonical_url,
        raw_final_url: raw_final_url, raw_canonical_url: raw_canonical_url
      )
      homepage_like = homepage_like?(final_url)
      content_type = resolved_content_type(homepage_like, snapshot)
      warnings = resolved_warnings(
        content_type, homepage_like, snapshot
      )
      suspect = warnings.any?

      Result.from_payload(
        url: url,
        final_url: final_url,
        payload: payload,
        canonical_url: canonical_url,
        content_type: content_type,
        suspect: suspect,
        warnings: warnings
      )
    end

    def resolved_content_type(homepage_like, snapshot)
      payload = snapshot.payload
      final_url = snapshot.final_url
      content_type = payload["contentType"] || "article"
      return "article" if content_type == "list" && scholarly_article_markdown?(final_url, snapshot)

      return content_type unless content_type == "article"
      return content_type if payload["legalProvision"]
      return content_type if payload["hostAware"]
      return "list" if institutional_case_record_list?(final_url, snapshot)
      return content_type if legal_judgment_markdown?(snapshot) || legal_statute_markdown?(snapshot)
      return content_type if scholarly_article_markdown?(final_url, snapshot)
      return content_type if reference_table_article_markdown?(snapshot)
      return "list" if government_service_portal?(final_url, snapshot)
      return "list" if homepage_like && homepage_index_markdown?(snapshot)
      return "list" if index_list_markdown?(final_url, snapshot)
      return "list" if thin_index_page?(final_url, snapshot)

      content_type
    end

    def resolved_warnings(content_type, homepage_like, snapshot)
      payload = snapshot.payload
      requested_url = snapshot.requested_url
      final_url = snapshot.final_url
      canonical_url = snapshot.canonical_url
      trusted_same_organization_redirect = trusted_same_organization_redirect?(
        content_type, snapshot
      )
      trusted_cross_domain_redirect = trusted_publisher_doi_redirect?(content_type, snapshot)
      warnings = Array(payload["warnings"]).dup
      warnings.delete("url_content_mismatch") if trusted_same_organization_redirect
      if stripped_query_only_url_mismatch?(requested_url, final_url, canonical_url, snapshot.raw_final_url,
                                           snapshot.raw_canonical_url)
        warnings.delete("url_content_mismatch")
      end
      if content_type == "list" && homepage_like && !payload["statusPage"] &&
         !substantial_homepage_landing?(snapshot) && !government_service_portal?(final_url, snapshot) &&
         !research_database_landing?(snapshot)
        warnings << "homepage_index_page"
      end
      warnings << "cross_domain_redirect" if cross_domain_redirect?(requested_url, final_url) && !trusted_cross_domain_redirect
      warnings << "aggregator_redirect_url" if aggregator_url?(requested_url)
      warnings << "auth_or_login_interstitial" if auth_redirect_interstitial?(snapshot)
      warnings << "pdf_document" if pdf_document?(requested_url, final_url, payload)
      warnings << "not_found_interstitial" if generic_redirect_not_found?(snapshot)
      if !trusted_same_organization_redirect &&
         redirected_title_content_mismatch?(content_type, homepage_like, snapshot)
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

    def homepage_index_markdown?(snapshot)
      return false unless snapshot.context.match?(HOMEPAGE_INDEX_PATTERN)

      snapshot.plain_list_item_count >= 3
    end

    def government_service_portal?(url, snapshot)
      normalized = snapshot.normalized_markdown
      return false if normalized.length < 250
      return false unless government_domain?(url) || government_service_language?(snapshot)

      context = snapshot.context_downcase
      service_pattern = /\b(?:service|services|servi[cç]os?|servicio|servicios|service category|categories|
        categorias?|citizens?|business(?:es)?|benefits?|permits?|licen[cs]es?)\b/ix
      service_terms = context.scan(service_pattern).length
      linked_items = snapshot.linked_heading_count + snapshot.linked_item_count
      plain_items = snapshot.plain_list_item_count

      service_terms >= 3 && (linked_items >= 4 || plain_items >= 4 || snapshot.markdown_link_count >= 6)
    end

    def government_domain?(url)
      host = FetchUtil.strip_www_host(url)
      labels = host.split(".")

      host.end_with?(".gov") || labels.include?("gov")
    rescue URI::InvalidURIError
      false
    end

    def government_service_language?(snapshot)
      snapshot.context_downcase.match?(/\b(?:government|governance|public services?|servi[cç]os? p[úu]blicos?|national portal|citizen services?)\b/i)
    end

    def institutional_case_record_list?(url, snapshot)
      normalized = snapshot.normalized_markdown
      return false if normalized.length < 500

      path = URI.parse(url).path.to_s.downcase
      context = snapshot.first_20_context
      return false unless path.match?(%r{/(?:cases?|defendants?|records?|dockets?|matters?)/?\z}) ||
                          context.match?(/\b\d{1,4}\s+(?:cases?|defendants?|records?|matters?)\b/i)

      linked_case_headings = snapshot.markdown.scan(
        %r{^\s*\#{1,6}\s+\[[^\]]{3,180}\]\([^)]*/(?:cases?|defendants?|situations?|darfur|mali|kenya|libya|uganda|congo|afghanistan|ukraine|records?|dockets?)[^)]*\)}i
      ).count
      case_terms = normalized.scan(
        /\b(?:prosecutor|trial chamber|pre-trial chamber|charges?|warrant|summons|custody|convicted|acquitted|case closed|at large|defence|reparations|court record)\b/i
      ).count

      linked_case_headings >= 4 && case_terms >= 6
    rescue URI::InvalidURIError
      false
    end

    def substantial_homepage_landing?(snapshot)
      normalized = snapshot.normalized_markdown
      return false if normalized.length < 1_200

      context = snapshot.context_downcase
      landing_pattern = /\b(docs?|documentation|api|reference|guide|guides|developer|framework|next\.js|mdx|
        static websites?|components?|themes?|product|platform)\b/x
      return false unless context.match?(landing_pattern)

      snapshot.long_prose_line_count_one_twenty.positive?
    end

    def research_database_landing?(snapshot)
      normalized = snapshot.normalized_markdown
      return false if normalized.length < 250

      context = snapshot.context_downcase
      research_terms = /\b(?:database|data resource|repository|multi-omics|proteomics|transcriptomics|
        phenomics|genomics|metabolomics|life science research|scientific resource)\b/ix
      return false unless context.match?(research_terms)
      return false if context.match?(HOMEPAGE_INDEX_PATTERN)

      snapshot.long_prose_line_count_one_hundred.positive?
    end

    def index_list_markdown?(url, snapshot)
      return false unless index_or_search_url?(url)
      return false if article_like_url?(url)

      return false if legal_judgment_markdown?(snapshot) || legal_statute_markdown?(snapshot)

      linked_headlines = snapshot.linked_heading_count
      linked_items = snapshot.linked_item_count

      linked_headlines + linked_items >= 4
    end

    def scholarly_article_markdown?(url, snapshot)
      payload = snapshot.payload
      normalized = snapshot.normalized_markdown
      return false if normalized.length < 5_000
      return false unless article_like_url?(url) || doi_article_url?(url) || doi_article_url?(payload["canonicalUrl"])
      return false if payload["byline"].to_s.strip.empty? && payload["publishedTime"].to_s.strip.empty?

      context = snapshot.first_80_context
      scholarly_context = context.match?(/\b(?:abstract|introduction|methods?|results?|discussion|references|doi|open access|peer[- ]reviewed|journal|article)\b/i)
      section_headings = snapshot.markdown.scan(
        /^\s*\#{1,4}\s+(?:Abstract|Introduction|Methods?|Materials and methods|Results?|Discussion|Conclusion|References)\b/i
      ).count
      long_prose_lines = snapshot.long_prose_line_count_one_forty

      return true if scholarly_context && section_headings >= 3 && long_prose_lines >= 5

      doi_article_url?(url) && scholarly_context && normalized.length >= 8_000 && long_prose_lines >= 8
    end

    def doi_article_url?(url)
      return false if url.nil? || url.empty?

      URI.parse(url).path.to_s.match?(%r{/(?:articles?/)?10\.\d{4,9}/}i)
    rescue URI::InvalidURIError
      false
    end

    def thin_index_page?(url, snapshot)
      payload = snapshot.payload
      return false unless index_or_search_url?(url)
      return false if article_like_url?(url)
      return false if payload["byline"].to_s.strip != "" || payload["publishedTime"].to_s.strip != ""

      markdown = snapshot.normalized_markdown
      return false if legal_judgment_markdown?(snapshot) || legal_statute_markdown?(snapshot)
      return false if reference_table_article_markdown?(snapshot)

      markdown.length < 2400
    end

    def reference_table_article_markdown?(snapshot)
      raw = snapshot.markdown
      text = snapshot.normalized_markdown
      return false if text.length < 700
      return false unless raw.match?(/^\|\s*[-: ]+\|/)
      return false if snapshot.list_link_count >= 3

      prose_blocks = raw.split(/\n{2,}/).count do |block|
        stripped = block.strip
        normalized = FetchUtil.normalize_whitespace(stripped)
        !stripped.empty? && !stripped.start_with?("|", "#") && normalized.length >= 80 && normalized.match?(/[.!?)]\z/)
      end
      table_rows = snapshot.table_row_count
      headings = snapshot.heading_count

      headings >= 1 && prose_blocks >= 2 && table_rows.between?(4, 40)
    end

    def legal_judgment_markdown?(snapshot)
      text = snapshot.normalized_markdown
      return false if text.length < 5_000
      return false if text.match?(/\bresults?\s+\d+\s*[-–]\s*\d+\s+(?:of|sur|von|de)\s+\d+\b/i)

      signals = 0
      signals += 1 if text.match?(/\b(?:high court|supreme court|court of appeal|federal court|district court|tribunal)\b/i)
      signals += 1 if text.match?(/\b(?:judg(?:e)?ment|opinion of the court|reasons for judgment|delivered by)\b/i)
      signals += 1 if text.match?(/\b(?:appellant|respondent|plaintiff|defendant|petitioner|counsel|solicitor|certiorari)\b/i)
      signals += 1 if text.match?(/\b[A-Z][A-Za-z'.-]+\s+v\.?\s+[A-Z][A-Za-z'.-]+\b/)
      signals += 1 if text.match?(/\[[12][0-9]{3}\]\s+[A-Z][A-Z0-9.]{1,12}\s+\d+|\([12][0-9]{3}\)\s+\d+\s+[A-Z][A-Z0-9.]{1,12}\s+\d+/i)
      return false if signals < 3

      snapshot.long_prose_line_count_one_twenty >= 5 || text.length >= 20_000
    end

    def legal_statute_markdown?(snapshot)
      text = snapshot.normalized_markdown
      return false if text.length < 5_000
      return false if text.match?(/\bresults?\s+\d+\s*[-–]\s*\d+\s+(?:of|sur|von|de)\s+\d+\b/i)

      context = text[0, 4_000]
      legal_title = context.match?(LEGAL_STATUTE_TITLE_PATTERN)
      provision_markers = text.scan(LEGAL_PROVISION_MARKER_PATTERN).count
      structural_markers = text.scan(LEGAL_PROVISION_STRUCTURAL_PATTERN).count
      legal_terms = text.match?(LEGAL_PROVISION_TERMS_PATTERN)

      legal_title && provision_markers >= 8 && (structural_markers >= 3 || legal_terms || text.length >= 20_000)
    end

    def index_or_search_url?(url)
      uri = URI.parse(url)
      path = uri.path.to_s
      return true if path.match?(INDEX_OR_SEARCH_PATH_PATTERN)
      return true if uri.query.to_s.match?(INDEX_QUERY_PATTERN)

      segments = path.split("/").reject(&:empty?)
      segments.length.between?(1, 2) && !opaque_detail_path_segments?(segments) && !segments.last.to_s.include?("-") &&
        !path.match?(/\.(?:html?|php|aspx?|jsp)\z/i)
    rescue URI::InvalidURIError
      false
    end

    def opaque_detail_path_segments?(segments)
      return false unless segments.length == 2
      return false if SEARCH_OR_LIST_PATH_SEGMENTS.include?(segments.first.to_s.downcase)

      last = segments.last.to_s
      last.length >= 6 && last.match?(/[[:alpha:]]/) && last.match?(/\d/) && last.match?(/\A[a-z0-9_-]+\z/i)
    end

    def article_like_url?(url)
      URI.parse(url).path.to_s.match?(ARTICLE_PATH_PATTERN)
    rescue URI::InvalidURIError
      false
    end

    def auth_redirect_interstitial?(snapshot)
      requested_url = snapshot.requested_url
      final_url = snapshot.final_url
      return false if requested_url.nil? || final_url.nil?
      return false unless auth_path?(final_url)
      return false if auth_path?(requested_url)
      return false unless index_or_search_url?(requested_url)

      text = snapshot.context_with_excerpt_downcase
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

    def generic_redirect_not_found?(snapshot)
      requested_url = snapshot.requested_url
      final_url = snapshot.final_url
      return false if requested_url.nil? || final_url.nil?
      return false unless same_effective_domain?(requested_url, final_url)

      requested_path = snapshot.path_key(requested_url)
      final_path = snapshot.path_key(final_url)
      return false if requested_path.empty? || requested_path == final_path
      return false unless specific_content_path?(requested_path)
      return false unless generic_redirect_path?(final_path)
      return false if redirected_payload_matches_requested_path?(requested_path, snapshot.payload)

      true
    end

    def specific_content_path?(path)
      return true if path.match?(%r{/10\.\d{4,9}/}i)
      return true if path.match?(%r{/(?:content|article|articles|preprint|papers?)/.+[a-z0-9]}i)

      false
    end

    def generic_redirect_path?(path)
      path.empty? || path.match?(%r{\A/(?:node|index(?:\.html?)?|home)?\z}i)
    end

    def redirected_payload_matches_requested_path?(requested_path, payload)
      requested_path.split(%r{[/._-]+}).select { |token| token.length >= 6 }.any? do |token|
        next false if CONTENT_ROUTE_SEGMENTS.include?(token.downcase)

        FetchUtil.normalize_whitespace([payload["title"], payload["markdown"], payload["canonicalUrl"]].compact.join(" "))
                 .downcase.include?(token.downcase)
      end
    end

    def article_body_fallback_candidate?(result)
      return false unless result.content_type == "list"
      return false if result.byline.to_s.strip.empty? && result.published_time.to_s.strip.empty?
      return false unless article_like_url?(result.final_url) || slug_article_url?(result.final_url)

      markdown = result.markdown.to_s
      markdown.length < 1_500 && markdown.lines.grep(/^\s*[-*]\s+\[/).count >= 4
    end

    def seznam_cmp_redirect_fallback_candidate?(requested_url, result)
      requested_host = FetchUtil.strip_www_host(requested_url)
      return false unless requested_host == "novinky.cz"

      final_uri = URI.parse(result.final_url)
      return false unless final_uri.host == "cmp.seznam.cz" && final_uri.path.start_with?("/nastaveni-souhlasu")

      consent_text = FetchUtil.normalize_whitespace([result.title, result.markdown].compact.join(" "))
      consent_text.match?(/nastavení souhlasu|souhlas s personalizací|unable to load/i)
    rescue URI::InvalidURIError
      false
    end

    def slug_article_url?(url)
      segments = URI.parse(url).path.to_s.split("/").reject(&:empty?)
      segments.length == 1 && segments.first.include?("-")
    rescue URI::InvalidURIError
      false
    end

    def redirected_title_content_mismatch?(content_type, homepage_like, snapshot)
      payload = snapshot.payload
      requested_url = snapshot.requested_url
      final_url = snapshot.final_url
      return false unless content_type == "article"
      return false if homepage_like || payload["docsLike"]
      return false if requested_url.nil? || final_url.nil?
      return false if snapshot.resource_urls.any? { |url| snapshot.search_or_list_resource_url?(url) }

      resource_url = mismatched_resource_url(snapshot)
      return false if resource_url.nil?

      requested_keywords = title_slug_keywords(requested_url)
      return false if requested_keywords.length < 2

      resolved_keywords = significant_slug_tokens([resource_url, payload["title"]].compact.join(" "))
      return false if resolved_keywords.empty?

      (requested_keywords & resolved_keywords).empty?
    end

    def trusted_same_organization_redirect?(content_type, snapshot)
      payload = snapshot.payload
      requested_url = snapshot.requested_url
      final_url = snapshot.final_url
      return false unless content_type == "article"
      return false if requested_url.nil? || final_url.nil?
      return false unless same_effective_domain?(requested_url, final_url)
      return false if FetchUtil.strip_www_host(requested_url) == FetchUtil.strip_www_host(final_url)
      return false if snapshot.resource_urls.any? { |url| snapshot.search_or_list_resource_url?(url) }
      return true if matching_apex_instrument_redirect?(payload, requested_url, final_url)

      tokens = requested_identifier_tokens(requested_url)
      return false if tokens.empty?

      content = snapshot.content_downcase
      matches = tokens.select { |token| content.include?(token) }

      matches.any? { |token| code_like_identifier?(token) } || matches.length >= 2
    rescue URI::InvalidURIError
      false
    end

    def trusted_publisher_doi_redirect?(content_type, snapshot)
      requested_url = snapshot.requested_url
      final_url = snapshot.final_url
      return false unless content_type == "article"
      return false unless cross_domain_redirect?(requested_url, final_url)
      return false unless scholarly_article_markdown?(final_url, snapshot)

      dois = snapshot.resource_urls.filter_map { |url| doi_from_url(url) }.uniq
      dois.length == 1
    end

    def doi_from_url(url)
      return nil if url.nil? || url.empty?

      path = URI.parse(url).path.to_s
      match = path.match(%r{/(10\.\d{4,9}/[^?#/\s]+(?:/[^?#\s]+)*)}i)
      match && match[1].downcase.delete_suffix("/")
    rescue URI::InvalidURIError
      nil
    end

    def requested_identifier_tokens(url)
      uri = URI.parse(url)
      raw = [uri.path, uri.query].compact.join(" ")
      URI.decode_www_form_component(raw.tr("+", " ")).downcase
         .gsub(/[^a-z0-9]+/, " ").split.select do |token|
        token.length >= 3 && token.match?(/[a-z]/) && !TITLE_SLUG_STOPWORDS.include?(token) &&
          !CONTENT_ROUTE_SEGMENTS.include?(token) && token != "www"
      end.uniq
    rescue ArgumentError, URI::InvalidURIError
      []
    end

    def matching_apex_instrument_redirect?(payload, requested_url, final_url)
      requested_instrument = apex_instrument_id(requested_url)
      final_instrument = apex_instrument_id(final_url)
      return false if requested_instrument.nil? || final_instrument.nil?
      return false unless requested_instrument == final_instrument

      content = FetchUtil.normalize_whitespace([payload["title"], payload["markdown"]].compact.join(" "))
      content.match?(/\b(?:Convention|Recommendation|Protocol)\s+[A-Z]\d{2,4}\b/i) &&
        content.match?(/\b(?:International Labour|Labou?r Organisation|General Conference|Article\s+1)\b/i)
    end

    def apex_instrument_id(url)
      query = URI.parse(url).query.to_s
      decoded = URI.decode_www_form_component(query.tr("+", " "))
      decoded[/\bP\d+_INSTRUMENT_ID[:=](\d+)\b/i, 1]
    rescue ArgumentError, URI::InvalidURIError
      nil
    end

    def code_like_identifier?(token)
      token.match?(/\A(?=.*[a-z])(?=.*\d)[a-z0-9]{3,16}\z/)
    end

    def mismatched_resource_url(snapshot)
      requested_url = snapshot.requested_url
      final_url = snapshot.final_url
      canonical_url = snapshot.canonical_url
      requested_path = snapshot.path_key(requested_url)
      return nil if requested_path.empty?

      final_path = snapshot.path_key(final_url)
      return final_url if !final_path.empty? && final_path != requested_path

      return nil unless same_effective_domain?(final_url, canonical_url)

      canonical_path = snapshot.path_key(canonical_url)
      return canonical_url if !canonical_path.empty? && canonical_path != requested_path

      nil
    end

    def same_effective_domain?(left_url, right_url)
      return false if left_url.nil? || right_url.nil?

      left_domain = effective_domain(left_url)
      right_domain = effective_domain(right_url)
      !left_domain.nil? && left_domain == right_domain
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

    def network_error_result(url, error)
      message = error.message.to_s.strip
      warning = dns_resolution_error?(message) ? "dns_resolution_failed" : "network_error"
      Result.error(url: url, warning: warning, message: message)
    end

    def network_error?(error)
      error.message.to_s.match?(NETWORK_ERROR_PATTERN)
    end

    def dns_resolution_error?(message)
      message.match?(/ERR_NAME_NOT_RESOLVED|DNS|resolve|resolution|ENOTFOUND|EAI_AGAIN/i)
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
      strip_tracking_params(url)
    end

    def strip_tracking_params(url)
      return url if url.nil? || url.empty?

      uri = URI.parse(url)
      params = URI.decode_www_form(uri.query.to_s)
      params.reject! { |key, _value| tracking_query_param?(key) }
      uri.query = params.empty? ? nil : URI.encode_www_form(params)
      uri.to_s
    rescue URI::InvalidURIError
      url
    end

    def tracking_query_param?(key)
      TRACKING_QUERY_PARAM_PATTERNS.any? { |pattern| key.match?(pattern) }
    end

    def stripped_query_only_url_mismatch?(requested_url, final_url, canonical_url, raw_final_url, raw_canonical_url)
      normalized_requested_url = normalized_result_url(requested_url)
      return false if normalized_requested_url.nil? || final_url.nil?
      return false unless normalized_requested_url == final_url
      return false if canonical_url && canonical_url != normalized_requested_url

      [raw_final_url, raw_canonical_url].compact.any? { |url| normalized_result_url(url) != url }
    end
  end
end
