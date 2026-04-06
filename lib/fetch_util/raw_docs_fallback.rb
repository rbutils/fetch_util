# frozen_string_literal: true

require "cgi"
require "net/http"
require "nokogiri"
require "uri"

module FetchUtil
  class RawDocsFallback
    DEFAULT_HEADERS = {
      "User-Agent" => Browser::DEFAULT_USER_AGENT,
      "Accept-Language" => Browser::DEFAULT_ACCEPT_LANGUAGE
    }.freeze

    BLOCK_ELEMENTS = %w[h1 h2 h3 h4 h5 h6 p pre ul ol li table tr].freeze
    DROP_SELECTORS = [
      "script",
      "style",
      "nav",
      "aside",
      "footer",
      ".toc",
      ".sidebar",
      ".breadcrumbs",
      "[aria-label*='breadcrumb']",
      ".headerlink",
      ".copybutton",
      "button"
    ].freeze

    def initialize(timeout: 20)
      @timeout = timeout.to_i
    end

    def fetch(url)
      final_url, html = fetch_html(url)
      payload = payload_from_html(html, requested_url: url, final_url: final_url)
      return nil unless payload

      [final_url, payload]
    rescue Error, SocketError, SystemCallError, Timeout::Error, URI::InvalidURIError
      nil
    end

    def payload_from_html(html, requested_url:, final_url: requested_url)
      document = Nokogiri::HTML(html)
      root = fragment_root(document, final_url) || docs_root(document)
      return nil unless root

      prune!(root)
      title = clean_text(fragment_title(document, final_url) || first_heading(root) || meta_title(document) || document.title)
      markdown = markdown_from_root(root, title)
      return nil if clean_text(markdown).length < 40

      {
        "title" => title,
        "byline" => meta_value(document, "author"),
        "excerpt" => first_paragraph(root),
        "siteName" => meta_value(document, "og:site_name", attr: "property") || safe_host(final_url),
        "publishedTime" => meta_value(document, "article:published_time", attr: "property") || meta_value(document, "publish-date"),
        "canonicalUrl" => canonical_url(document, final_url),
        "language" => document.at_css("html")&.[]("lang") || "en",
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
      href = document.at_css('link[rel="canonical"]')&.[]("href")
      return strip_fragment(final_url) unless href && !href.empty?

      URI.join(final_url, href).to_s
    rescue URI::InvalidURIError
      strip_fragment(final_url)
    end

    def fragment_id(url)
      fragment = URI.parse(url).fragment.to_s
      CGI.unescape(fragment)
    rescue URI::InvalidURIError
      ""
    end

    def fragment_root(document, url)
      id = fragment_id(url)
      return nil if id.empty?

      node = fragment_node(document, id)
      return nil unless node

      if node.name == "a" && node["name"] == id
        container = Nokogiri::XML::Node.new("div", document)
        sibling = node.next_sibling
        while sibling
          break if sibling.element? && sibling.name == "a" && sibling["name"]

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

    def fragment_title(document, url)
      id = fragment_id(url)
      return nil if id.empty?

      node = fragment_node(document, id)
      return nil unless node

      heading = if node.name.match?(/h[1-6]/)
                  node
                elsif node.name == "a" && node["name"] == id
                  node.at_xpath("following-sibling::*[1][self::h1 or self::h2 or self::h3 or self::h4 or self::h5 or self::h6]") ||
                    node.at_xpath("following-sibling::*[1]//strong[1]")
                else
                  node.at_css("h1, h2, h3, h4, h5, h6")
                end
      clean_text(heading&.text)
    end

    def docs_root(document)
      selectors = [
        "main article",
        "main",
        "article",
        "[role='main']",
        ".content",
        ".resource-container"
      ]

      selectors.each do |selector|
        node = document.at_css(selector)
        return node.dup if node && clean_text(node.text).length >= 120
      end

      body = document.at_css("body")
      body&.dup
    end

    def prune!(root)
      DROP_SELECTORS.each { |selector| root.css(selector).remove }
      root.css("*").each do |node|
        text = clean_text(node.text)
        node.remove if text.match?(/\A(?:on this page|table of contents|edit this page|copy page|copy item path|search|settings|help|expand description)\z/i)
      end
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
      root.css(BLOCK_ELEMENTS.join(", ")).each do |node|
        text = clean_text(node.text)
        next if text.empty?

        case node.name
        when /h([1-6])/
          level = Regexp.last_match(1).to_i
          sections << "#{"#" * level} #{text}"
        when "p"
          sections << text
        when "pre"
          sections << ["```", node.text.rstrip, "```"].join("\n")
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
      FetchUtil.normalize_whitespace(text)
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

    def xpath_literal(value)
      return %('#{value}') unless value.include?("'")
      return %("#{value}") unless value.include?('"')

      parts = value.split("'").map { |part| %('#{part}') }
      %(concat(#{parts.join(%q(, "'", ))}))
    end

    def fetch_html(url, limit: 5)
      raise URI::InvalidURIError, "too many redirects" if limit <= 0

      uri = URI.parse(url)
      request = Net::HTTP::Get.new(uri)
      DEFAULT_HEADERS.each { |key, value| request[key] = value }

      response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", open_timeout: @timeout, read_timeout: @timeout) do |http|
        http.request(request)
      end

      case response
      when Net::HTTPSuccess
        [uri.to_s, response.body]
      when Net::HTTPRedirection
        location = URI.join(uri, response["location"]).to_s
        fetch_html(location, limit: limit - 1)
      else
        raise Error, "HTTP #{response.code}"
      end
    end
  end
end
