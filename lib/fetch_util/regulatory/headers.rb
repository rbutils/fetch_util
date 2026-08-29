# frozen_string_literal: true

module FetchUtil
  class Regulatory
    module Headers
      def extract_x_robot_signals(headers, path:)
        header_values(headers, "x-robots-tag").flat_map do |value|
          extract_robot_directive_signals(value, path: path)
        end
      end

      def extract_content_usage_header_signals(headers, path:)
        header_values(headers, "content-usage").flat_map do |value|
          extract_content_usage_statement_signals(value, path: path)
        end
      end

      def extract_meta_robot_signals(meta_tags, path:)
        signals = []

        meta_tags.each do |attributes|
          if attributes["http-equiv"].to_s.casecmp?("x-robots-tag")
            signals.concat(extract_robot_directive_signals(attributes["content"], path: path))
            next
          end

          name = attributes["name"].to_s.strip
          next if name.empty?
          next if name.casecmp?("tdm-reservation") || name.casecmp?("tdm-policy")
          next unless robot_meta_name?(name)

          signals.concat(extract_robot_directive_signals(attributes["content"], path: path, meta_name: name))
        end

        signals
      end

      def robot_meta_name?(name)
        return true if name.casecmp?("robots")
        return false if name.casecmp?("robot")

        name.match?(/\A[a-z0-9][a-z0-9_.-]*bot(?:[-_.][a-z0-9]+)*\z/i)
      end
    end
  end
end
