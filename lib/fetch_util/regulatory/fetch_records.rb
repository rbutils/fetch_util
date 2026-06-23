# frozen_string_literal: true

module FetchUtil
  class Regulatory
    module FetchRecords
      private

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

      def first_header_value(headers, name)
        Array(headers[name]).first.to_s.strip
      end

      def header_values(headers, name)
        headers.fetch(name, [])
      end

      def html_content?(headers, body)
        content_type = first_header_value(headers, "content-type")
        return true if content_type.include?("text/html") || content_type.include?("application/xhtml+xml")

        body.to_s.lstrip.start_with?("<!DOCTYPE html", "<html", "<HTML")
      end

      def parse_meta_tags(body)
        body.to_s.scan(/<meta\b[^>]*>/im).map do |tag|
          attributes = {}
          tag.scan(/([A-Za-z_:.-]+)\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s"'=<>`]+))/).each do |name, quoted, single, bare|
            attributes[name.downcase] = CGI.unescapeHTML(quoted || single || bare || "")
          end
          attributes
        end
      end

      def json_like_response?(headers, body)
        content_type = first_header_value(headers, "content-type")
        return true if content_type.include?("application/json") || content_type.include?("application/ld+json")

        stripped = body.to_s.lstrip
        stripped.start_with?("{", "[")
      end
    end
  end
end
