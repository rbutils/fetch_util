# frozen_string_literal: true

module FetchUtil
  class Regulatory
    module Signals
      private

      def scoped_signals(signals, origin_query:, query_target:)
        list = Array(signals).map { |signal| deep_copy(signal) }
        return list if origin_query

        list.filter_map do |signal|
          next unless signal_matches_target?(signal["path"], query_target)

          signal.reject { |key, _value| key == "path" }
        end
      end

      def signal_matches_target?(path, query_target)
        return true if path.nil? || path.empty?

        Regexp.new("\\A#{signal_path_pattern(path)}").match?(query_target)
      end

      def signal_path_pattern(path)
        escaped = Regexp.escape(path.to_s)
        escaped = escaped.gsub("\\*", ".*")
        if escaped.end_with?("\\$")
          "#{escaped[0...-2]}$"
        else
          "#{escaped}.*"
        end
      end

      def sort_specificity_signals(signals)
        Array(signals).sort_by do |signal|
          [
            *signal_sort_prefix(signal),
            signal.dig("conditions", "policy").to_s
          ]
        end
      end

      def signal_sort_prefix(signal)
        [
          -path_specificity(signal["path"]),
          allow_signal?(signal) ? 0 : 1
        ]
      end

      def sort_generic_signals(signals)
        Array(signals).sort_by do |signal|
          [
            allow_signal?(signal) ? 1 : 0,
            wildcard_signal?(signal) ? 1 : 0,
            signal_verb(signal),
            signal_noun(signal)
          ]
        end
      end

      def signal_verb(signal)
        signal.keys.find { |key| %w[allow disallow].include?(key) }.to_s
      end

      def signal_noun(signal)
        signal.values_at("allow", "disallow").compact.first.to_s
      end

      def allow_signal?(signal)
        signal.key?("allow")
      end

      def wildcard_signal?(signal)
        signal.dig("conditions", "user-agent").to_s == "*" || signal.dig("conditions", "user-agent").to_s.empty?
      end

      def path_specificity(path)
        path.to_s.delete("*$").length
      end

      def integer_or_value(value)
        Integer(value, exception: false) || value
      end

      def build_signal(verb, noun, path: nil, conditions: nil)
        signal = { verb => noun }
        signal["path"] = path if path
        signal["conditions"] = conditions if conditions && !conditions.empty?
        signal
      end

      def sort_robot_signals(signals)
        signals.sort_by do |signal|
          prefix = signal_sort_prefix(signal)
          [
            prefix.first,
            wildcard_signal?(signal) ? 1 : 0,
            prefix.last,
            signal.dig("conditions", "user-agent").to_s
          ]
        end
      end
    end
  end
end
