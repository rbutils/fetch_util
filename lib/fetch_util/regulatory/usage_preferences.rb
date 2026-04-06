# frozen_string_literal: true

module FetchUtil
  class Regulatory
    module UsagePreferences
      def extract_content_signal_signals(value, user_agent: nil)
        parse_yes_no_preferences(value).map do |label, verb|
          usage_preference_signal(label, verb, path: "/*", user_agent: user_agent)
        end
      end

      def extract_content_usage_robot_signals(value, user_agent: nil)
        path, statement = parse_content_usage_rule(value)
        return [] if statement.nil? || statement.empty?

        extract_content_usage_statement_signals(statement, path: normalize_output_path(path || "/*"), user_agent: user_agent)
      end

      def extract_content_usage_statement_signals(value, path:, user_agent: nil)
        parse_structured_usage_preferences(value).map do |label, verb|
          usage_preference_signal(label, verb, path: path, user_agent: user_agent)
        end
      end

      def sort_usage_preference_signals(signals)
        Array(signals).sort_by do |signal|
          [
            -path_specificity(signal["path"]),
            wildcard_signal?(signal) ? 1 : 0,
            signal_noun(signal),
            allow_signal?(signal) ? 1 : 0,
            signal.dig("conditions", "user-agent").to_s
          ]
        end
      end

      private

      def usage_preference_signal(label, verb, path:, user_agent: nil)
        conditions = {}
        user_agent_glob = robot_user_agent_glob(user_agent)
        conditions["user-agent"] = user_agent_glob unless user_agent_glob == "*"
        normalized_noun = usage_preference_noun(label)
        conditions["label"] = label if normalized_noun != label

        build_signal(verb, normalized_noun, path: path, conditions: conditions)
      end

      def usage_preference_noun(label)
        case label
        when "ai-train", "train-ai"
          "ai-training"
        else
          label
        end
      end

      def parse_content_usage_rule(value)
        text = value.to_s.strip
        return [nil, text] unless text.start_with?("/")

        path, statement = text.split(/[ \t]+/, 2)
        [path, statement.to_s.strip]
      end

      def parse_yes_no_preferences(value)
        preferences = {}
        value.to_s.split(",").each do |entry|
          label, raw_value = entry.split("=", 2)
          next unless raw_value

          verb = case raw_value.to_s.strip.downcase
                 when "yes"
                   "allow"
                 when "no"
                   "disallow"
                 end
          next unless verb

          preferences[label.to_s.strip.downcase] = verb
        end
        preferences.to_a
      end

      def parse_structured_usage_preferences(value)
        preferences = {}
        value.to_s.split(",").each do |entry|
          label_part, raw_value = entry.split("=", 2)
          next unless raw_value

          label = label_part.to_s.split(";", 2).first.to_s.strip.downcase
          token = raw_value.to_s.split(";", 2).first.to_s.strip.delete_prefix('"').delete_suffix('"').downcase
          verb = if token == "y"
                   "allow"
                 else
                   (token == "n" ? "disallow" : nil)
                 end
          next unless verb

          preferences[label] = verb
        end
        preferences.to_a
      end
    end
  end
end
