# frozen_string_literal: true

module FetchUtil
  class Regulatory
    module Directives
      private

      def extract_robot_directive_signals(value, path:, meta_name: nil)
        current_user_agent = nil
        tokenize_robot_directives(value).flat_map do |token|
          prefix, directive = robot_directive_prefix(token)
          if prefix
            current_user_agent = prefix
            directive_signals(directive, path: path, user_agent: prefix)
          else
            directive_signals(token, path: path, user_agent: meta_name && !meta_name.casecmp?("robots") ? meta_name : current_user_agent)
          end
        end
      end

      def tokenize_robot_directives(value)
        protected = value.to_s.gsub(
          /(unavailable_after\s*:\s*[A-Za-z]{3}),\s*(\d{1,2}\s+[A-Za-z]{3}\s+\d{4}\s+\d{2}:\d{2}:\d{2}\s+[A-Za-z+-]+)/i,
          '\\1__FETCH_UTIL_COMMA__\\2'
        )

        protected.split(",").map { |token| token.gsub("__FETCH_UTIL_COMMA__", ",").strip }.reject(&:empty?)
      end

      def robot_directive_prefix(token)
        match = token.to_s.match(/\A([A-Za-z0-9*_.-]+)\s*:\s*(.+)\z/)
        return [nil, nil] unless match

        prefix = match[1]
        directive = match[2]
        return [nil, nil] if FetchUtil::Regulatory::Robots::ROBOT_DIRECTIVES.include?(prefix.downcase)

        [prefix, directive]
      end

      def directive_signals(directive, path:, user_agent: nil)
        name, raw_value = directive.to_s.split(":", 2)
        name = name.to_s.strip.downcase
        value = raw_value.to_s.strip
        conditions = directive_conditions(user_agent)

        case name
        when "all"
          [
            build_signal("allow", "index", path: path, conditions: conditions),
            build_signal("allow", "follow", path: path, conditions: conditions)
          ]
        when "follow"
          [build_signal("allow", "follow", path: path, conditions: conditions)]
        when "index"
          [build_signal("allow", "index", path: path, conditions: conditions)]
        when "indexifembedded"
          [build_signal("allow", "index", path: path, conditions: conditions.merge("if-embedded" => true))]
        when "max-image-preview"
          max_image_preview_signal(path: path, conditions: conditions, value: value)
        when "max-snippet"
          [build_signal("allow", "snippet", path: path, conditions: conditions.merge("max-chars" => integer_or_value(value)))]
        when "max-video-preview"
          [build_signal("allow", "video-preview", path: path, conditions: conditions.merge("max-seconds" => integer_or_value(value)))]
        when "noai"
          [build_signal("disallow", "ai-training", path: path, conditions: conditions)]
        when "noarchive", "nocache"
          [build_signal("disallow", "archive", path: path, conditions: conditions)]
        when "nofollow"
          [build_signal("disallow", "follow", path: path, conditions: conditions)]
        when "noimageai"
          [build_signal("disallow", "image-ai-training", path: path, conditions: conditions)]
        when "noimageindex"
          [build_signal("disallow", "image-index", path: path, conditions: conditions)]
        when "noindex"
          [build_signal("disallow", "index", path: path, conditions: conditions)]
        when "none"
          [
            build_signal("disallow", "index", path: path, conditions: conditions),
            build_signal("disallow", "follow", path: path, conditions: conditions)
          ]
        when "nosnippet"
          [build_signal("disallow", "snippet", path: path, conditions: conditions)]
        when "notranslate"
          [build_signal("disallow", "translate", path: path, conditions: conditions)]
        when "unavailable_after"
          [build_signal("disallow", "index", path: path, conditions: conditions.merge("after" => value))]
        else
          []
        end
      end

      def max_image_preview_signal(path:, conditions:, value:)
        return [build_signal("disallow", "image-preview", path: path, conditions: conditions)] if value.casecmp?("none")

        [build_signal("allow", "image-preview", path: path, conditions: conditions.merge("max" => value))]
      end

      def directive_conditions(user_agent)
        return {} if user_agent.to_s.strip.empty?

        { "user-agent" => robot_user_agent_glob(user_agent) }
      end
    end
  end
end
