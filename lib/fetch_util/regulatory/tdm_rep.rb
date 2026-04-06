# frozen_string_literal: true

module FetchUtil
  class Regulatory
    module TdmRep
      def tdmrep_record(requested_uri)
        cache_fetch("tdmrep:#{origin_key(requested_uri)}") do
          response = safe_get(tdmrep_uri(requested_uri))
          signals = []
          policies = []
          if response&.status&.between?(200, 299)
            signals, policies = extract_tdmrep_signals(response.body)
          end
          {
            "signals" => sort_specificity_signals(signals),
            "policies" => policies
          }
        end
      end

      def extract_tdmrep_signals(body)
        payload = JSON.parse(body.to_s)
        return [[], []] unless payload.is_a?(Array)

        signals = []
        policies = []
        payload.each do |rule|
          next unless rule.is_a?(Hash)

          location = string_value(rule, "location")
          reservation = string_value(rule, "tdm-reservation")
          policy_url = string_value(rule, "tdm-policy")
          next if location.empty?
          next unless %w[0 1].include?(reservation)

          conditions = {}
          conditions["policy"] = policy_url if !policy_url.empty? && reservation == "1"
          signals << build_signal(
            reservation == "1" ? "disallow" : "allow",
            "text-and-data-mining",
            path: normalize_output_path(location),
            conditions: conditions
          )
          policies << policy_ref(policy_url, normalize_output_path(location)) if reservation == "1"
        end

        [signals, dedupe_policy_refs(policies)]
      rescue JSON::ParserError
        [[], []]
      end
    end
  end
end
