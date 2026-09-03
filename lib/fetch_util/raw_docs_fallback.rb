# frozen_string_literal: true

require "nokogiri"
require "openssl"
require "uri"

require_relative "http_redirect_client"

module FetchUtil
  class RawDocsFallback
    DEFAULT_HEADERS = {
      "User-Agent" => Browser::DEFAULT_USER_AGENT,
      "Accept-Language" => Browser::DEFAULT_ACCEPT_LANGUAGE
    }.freeze

    BLOCK_ELEMENTS = %w[h1 h2 h3 h4 h5 h6 p pre ul ol li table tr].freeze
    BLOCK_SELECTOR = BLOCK_ELEMENTS.join(", ").freeze
    URL_ATTRIBUTES = %w[action background cite classid codebase data data-lazy data-lazy-src data-original data-src formaction
                        href itemid longdesc manifest poster profile src usemap xlink:href].freeze
    SRCSET_ATTRIBUTES = %w[imagesrcset srcset].freeze
    DROP_ATTRIBUTES = %w[archive ping srcdoc style].freeze
    DROP_SELECTORS = [
      "script",
      "style",
      "nav",
      "aside",
      "footer",
      ".discord",
      ".toc",
      ".sidebar",
      ".breadcrumbs",
      "[aria-label*='breadcrumb']",
      ".headerlink",
      ".copybutton",
      "button"
    ].freeze
    DOCS_ROOT_SELECTORS = [
      "main .sl-markdown-content",
      "main [data-pagefind-body]",
      ".sl-markdown-content",
      "[data-pagefind-body]",
      "main article",
      "main",
      "article",
      "[role='main']",
      "[class*='content']",
      "[id*='content']",
      "[class*='article']",
      "[id*='article']",
      ".content",
      ".resource-container"
    ].freeze
    PRUNED_TEXT_PATTERN = /\A(?:on this page|table of contents|edit this page|copy page|copy item path|search|settings|help|expand description)\z/i

    def initialize(timeout: 20, http_client: nil)
      @timeout = timeout.to_f
      @http_client = http_client || FetchUtil::HttpRedirectClient.new(timeout: @timeout, headers: DEFAULT_HEADERS)
    end

    def fetch(url)
      final_url, html = fetch_html(url)
      payload = payload_from_html(html, requested_url: url, final_url: final_url)
      return nil unless payload

      [final_url, payload]
    rescue Error, IOError, SocketError, SystemCallError, Timeout::Error, OpenSSL::SSL::SSLError, URI::InvalidURIError
      nil
    end

    def payload_from_html(html, requested_url:, final_url: requested_url)
      document = Nokogiri::HTML(html)
      root = fragment_root(document, final_url) || docs_root(document)
      return nil unless root

      prune!(root)
      prune_credential_urls!(root, final_url)
      title = [fragment_title(document, final_url), first_heading(root), meta_title(document), document.title]
              .map { |candidate| clean_text(candidate) }
              .find { |candidate| !candidate.empty? }
      markdown = markdown_from_root(root, title)
      return nil if clean_text(markdown).length < 40

      language = clean_optional_text(document.at_css("html")&.[]("lang"))

      {
        "title" => title,
        "byline" => clean_optional_text(meta_value(document, "author")),
        "excerpt" => first_paragraph(root),
        "siteName" => clean_optional_text(meta_value(document, "og:site_name", attr: "property")) || safe_host(final_url),
        "publishedTime" => clean_optional_text(meta_value(document, "article:published_time", attr: "property") ||
                                                meta_value(document, "publish-date")),
        "canonicalUrl" => canonical_url(document, final_url),
        "language" => language,
        "html" => root.to_html,
        "markdown" => markdown,
        "readerMode" => false,
        "contentType" => "article",
        "suspect" => false,
        "warnings" => []
      }
    end

    private

    def meta_value(document, name, attr: "name")
      document.at_css(%(meta[#{attr}="#{name}"]))&.[]("content")
    end

    def canonical_url(document, final_url)
      fallback_url = http_url(strip_fragment(final_url))
      document.css('link[rel="canonical"]').each do |node|
        href = node["href"]
        next unless href && !href.empty?

        url = http_url(URI.join(final_url, href).to_s)
        return url if url
      rescue URI::InvalidURIError
        next
      end
      fallback_url
    end

    def http_url(value)
      uri = URI.parse(value.to_s)
      uri.to_s if uri.is_a?(URI::HTTP) && !uri.host.to_s.empty? && uri.userinfo.nil?
    rescue URI::InvalidURIError
      nil
    end

    def prune_credential_urls!(root, base_url)
      ([root] + root.css("*").to_a).each do |node|
        DROP_ATTRIBUTES.each { |attribute| node.remove_attribute(attribute) }
        URL_ATTRIBUTES.each do |attribute|
          value = node[attribute]
          next unless value

          node.remove_attribute(attribute) if credential_url?(value, base_url)
        end
        SRCSET_ATTRIBUTES.each do |attribute|
          value = node[attribute]
          next unless value

          entries = value.split(",").map(&:strip).reject do |entry|
            reference = entry.split(/\s+/, 2).first
            credential_url?(reference, base_url)
          end
          entries.empty? ? node.remove_attribute(attribute) : node[attribute] = entries.join(", ")
        end
      end
      root.xpath(".//text() | self::text()").each do |node|
        sanitized = credential_free_text(node.text)
        node.content = sanitized unless sanitized == node.text
      end
    end

    def credential_url?(value, base_url)
      return true if value.to_s.match?(%r{\A\s*(?:https?:)?[\\/]{2}[^\\/\s?#@]+@}i)

      uri = URI.join(base_url, value.to_s)
      uri.is_a?(URI::HTTP) && !uri.userinfo.nil?
    rescue URI::InvalidURIError
      false
    end

    def fragment_id(url)
      fragment = URI.parse(url).fragment.to_s
      URI::DEFAULT_PARSER.unescape(fragment)
    rescue URI::InvalidURIError
      ""
    end

    def fragment_root(document, url)
      id = fragment_id(url)
      return nil if id.empty?

      node = fragment_node(document, id)
      return nil unless node

      return fragment_heading_root(document, node) if fragment_heading_level(node)

      if fragment_anchor?(node, id)
        container = Nokogiri::XML::Node.new("div", document)
        sibling = node.next_sibling
        while sibling
          break if sibling.element? && fragment_anchor?(sibling)

          container.add_child(sibling.dup)
          sibling = sibling.next_sibling
        end
        return container if clean_text(container.text).length >= 40
      end

      candidate = node
      while candidate&.element?
        text = clean_text(candidate.text)
        return candidate.dup if text.length >= 80 || candidate["id"] == id
        candidate = candidate.parent
      end

      node.dup
    end

    def fragment_heading_root(document, heading)
      level = fragment_heading_level(heading)
      container = Nokogiri::XML::Node.new("div", document)
      sibling = heading

      while sibling
        if sibling != heading && sibling.element?
          sibling_level = fragment_heading_level(sibling)
          break if empty_fragment_anchor?(sibling) || (sibling_level && sibling_level <= level)
        end

        container.add_child(sibling.dup)
        sibling = sibling.next_sibling
      end

      container
    end

    def fragment_heading_level(node)
      match = node&.name&.match(/\Ah([1-6])\z/)
      match && Integer(match[1], 10)
    end

    def fragment_title(document, url)
      id = fragment_id(url)
      return nil if id.empty?

      node = fragment_node(document, id)
      return nil unless node

      heading = if node.name.match?(/h[1-6]/)
                  node
                elsif fragment_anchor?(node, id)
                  node.at_xpath("following-sibling::*[1][self::h1 or self::h2 or self::h3 or self::h4 or self::h5 or self::h6]") ||
                    node.at_xpath("following-sibling::*[1]//strong[1]")
                else
                  node.at_css("h1, h2, h3, h4, h5, h6")
                end
      clean_text(heading&.text)
    end

    def docs_root(document)
      candidates = []
      DOCS_ROOT_SELECTORS.each do |selector|
        document.css(selector).each do |node|
          text = clean_text(node.text)
          next if text.length < 120

          candidates << [node, text.length + (node.css("p").length * 200)]
        end
      end

      best = candidates.max_by { |_node, score| score }
      return best.first.dup if best

      body = document.at_css("body")
      body&.dup
    end

    def prune!(root)
      DROP_SELECTORS.each { |selector| root.css(selector).remove }
      prune_leading_promo_cards!(root)
      root.css("*").each do |node|
        text = clean_text(node.text)
        node.remove if text.match?(PRUNED_TEXT_PATTERN)
      end
    end

    def prune_leading_promo_cards!(root)
      return unless root.at_css("h1, h2")

      root.css("article.card, .card").each do |node|
        text = clean_text(node.text)
        next if node.ancestors.any? { |ancestor| class_list(ancestor).any? { |klass| %w[landing-card card--fullwidth].include?(klass) } }
        next if node.at_css(".title, .body")
        next if text.empty? || text.length > 600 || node.at_css("h1, h2, h3, h4, h5, h6")

        node.remove
      end
    end

    def class_list(node)
      node["class"].to_s.split
    end

    def meta_title(document)
      meta_value(document, "og:title", attr: "property") || document.title
    end

    def first_heading(root)
      clean_text(root.at_css("h1, h2, h3")&.text)
    end

    def first_paragraph(root)
      root.css("p").map { |node| clean_text(node.text) }.find { |text| text.length >= 30 }
    end

    def markdown_from_root(root, title)
      sections = []
      root.css(BLOCK_SELECTOR).each do |node|
        text = clean_text(node.text)
        next if text.empty?

        case node.name
        when /h([1-6])/
          level = Regexp.last_match(1).to_i
          sections << "#{"#" * level} #{text}"
        when "p"
          sections << text
        when "pre"
          code = node.text.rstrip
          fence_length = [3, code.scan(/`+/).map(&:length).max.to_i + 1].max
          fence = "`" * fence_length
          sections << [fence, code, fence].join("\n")
        when "li"
          sections << "- #{text}"
        when "tr"
          cells = node.css("th, td").map { |cell| clean_text(cell.text) }.reject(&:empty?)
          sections << "- #{cells.join(": ")}" unless cells.empty?
        end
      end

      markdown = sections.join("\n\n").gsub(/\n{3,}/, "\n\n").strip
      markdown = "# #{title}\n\n#{markdown}" if title && !markdown.start_with?("# #{title}")
      markdown
    end

    def clean_text(text)
      FetchUtil.normalize_whitespace(credential_free_text(text))
    end

    def clean_optional_text(text)
      value = clean_text(text)
      value unless value.empty?
    end

    def credential_free_text(text)
      text.to_s.gsub(%r{(https?:[\\/]{2})[^\\/\s?#@]+@}i, "\\1")
    end

    def strip_fragment(url)
      uri = URI.parse(url)
      uri.fragment = nil
      uri.to_s
    rescue URI::InvalidURIError
      url
    end

    def safe_host(url)
      URI.parse(url).host
    rescue URI::InvalidURIError
      nil
    end

    def fragment_node(document, id)
      document.at_xpath(%(//*[@id=#{xpath_literal(id)}])) || document.at_xpath(%(//a[@name=#{xpath_literal(id)}]))
    end

    def fragment_anchor?(node, id = nil)
      return false unless node.name == "a"

      anchor_id = node["name"]
      anchor_id ||= node["id"] if node.element_children.empty? && clean_text(node.text).empty?
      id ? anchor_id == id : !anchor_id.to_s.empty?
    end

    def empty_fragment_anchor?(node)
      node.name == "a" && node.element_children.empty? && clean_text(node.text).empty? &&
        ![node["name"], node["id"]].compact.empty?
    end

    def xpath_literal(value)
      return %('#{value}') unless value.include?("'")
      return %("#{value}") unless value.include?('"')

      parts = value.split("'").map { |part| %('#{part}') }
      %(concat(#{parts.join(%q(, "'", ))}))
    end

    def fetch_html(url)
      response = @http_client.get(url)
      raise Error, "HTTP #{response.status}" unless response.status.between?(200, 299)

      [response.url, response.body]
    end
  end
end
