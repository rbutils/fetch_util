# frozen_string_literal: true

module FetchUtil
  class Regulatory
    module TrustTxt
      def trusttxt_record(requested_uri)
        cache_fetch("trusttxt:#{origin_key(requested_uri)}") do
          response = safe_get(trusttxt_uri(requested_uri))
          unless response&.status&.between?(200, 299)
            response = safe_get(trusttxt_well_known_uri(requested_uri))
          end

          signals = []
          if response&.status&.between?(200, 299)
            signals = extract_trusttxt_signals(response.body)
          end

          { "signals" => sort_usage_preference_signals(signals) }
        end
      end

      def extract_trusttxt_signals(body)
        preference = nil

        body.to_s.gsub("\r\n", "\n").gsub("\r", "\n").each_line do |line|
          content = line.sub(/\s*#.*\z/, "").strip
          next if content.empty?

          key, raw_value = content.split("=", 2)
          next unless raw_value
          next unless key.to_s.strip.casecmp?("datatrainingallowed")

          preference = case raw_value.to_s.strip.downcase
                       when "yes"
                         "allow"
                       when "no"
                         "disallow"
                       end
        end

        return [] unless preference

        [
          build_signal(
            preference,
            "ai-training",
            path: "/*",
            conditions: { "label" => "datatrainingallowed" }
          )
        ]
      end
    end
  end
end
