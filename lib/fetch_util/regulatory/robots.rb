# frozen_string_literal: true

module FetchUtil
  class Regulatory
    module Robots
      ROBOT_DIRECTIVES = %w[
        all
        follow
        index
        indexifembedded
        max-image-preview
        max-snippet
        max-video-preview
        noai
        noarchive
        nocache
        nofollow
        noimageai
        noimageindex
        noindex
        none
        nosnippet
        notranslate
        unavailable_after
      ].freeze
      def robots_record(requested_uri)
        cache_fetch("robotstxt:#{origin_key(requested_uri)}") do
          response = safe_get(robots_uri(requested_uri))
          payload = {
            "robotstxt" => [],
            "contentsignal" => [],
            "contentusagerobots" => []
          }
          if response&.status&.between?(200, 299)
            payload = extract_robots_source_signals(response.body)
          end
          {
            "signals" => {
              "robotstxt" => sort_robot_signals(payload["robotstxt"]),
              "contentsignal" => sort_usage_preference_signals(payload["contentsignal"]),
              "contentusagerobots" => sort_usage_preference_signals(payload["contentusagerobots"])
            }
          }
        end
      end

      def extract_robots_source_signals(body)
        signals = {
          "robotstxt" => [],
          "contentsignal" => [],
          "contentusagerobots" => []
        }
        user_agents = []
        in_rules = false

        body.to_s.gsub("\r\n", "\n").gsub("\r", "\n").each_line do |line|
          content = line.sub(/\s*#.*\z/, "").strip
          next if content.empty?

          field, value = content.split(":", 2)
          next unless value

          field = field.strip.downcase
          value = value.strip

          case field
          when "user-agent"
            user_agents = [] if in_rules
            in_rules = false
            user_agents << value unless value.empty?
          when "allow", "disallow"
            next if user_agents.empty?

            in_rules = true
            user_agents.each do |user_agent|
              signals["robotstxt"] << robot_signal(field, user_agent, value)
            end
          when "content-signal"
            next if user_agents.empty?

            in_rules = true
            user_agents.each do |user_agent|
              signals["contentsignal"].concat(extract_content_signal_signals(value, user_agent: user_agent))
            end
          when "content-usage"
            next if user_agents.empty?

            in_rules = true
            user_agents.each do |user_agent|
              signals["contentusagerobots"].concat(extract_content_usage_robot_signals(value, user_agent: user_agent))
            end
          end
        end

        signals
      end

      private

      def robot_signal(field, user_agent, value)
        verb = value.to_s.strip.empty? ? "allow" : field
        conditions = {}
        user_agent_glob = robot_user_agent_glob(user_agent)
        conditions["user-agent"] = user_agent_glob unless user_agent_glob == "*"

        build_signal(
          verb,
          "*",
          path: normalize_output_path(value),
          conditions: conditions
        )
      end
    end
  end
end
