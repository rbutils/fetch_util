# frozen_string_literal: true

module FetchUtil
  class Regulatory
    module TdmRep
      def tdmrep_record(requested_uri)
        fetch_record(
          "tdmrep:#{origin_key(requested_uri)}",
          tdmrep_uri(requested_uri),
          fallback: { "signals" => [], "policies" => [] }
        ) do |body|
          signals, policies = extract_tdmrep_signals(body)
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

          rule_signals, rule_policies = extract_tdm_value_signals(
            reservation: reservation,
            policy_url: policy_url,
            path: normalize_output_path(location)
          )
          signals.concat(rule_signals)
          policies.concat(rule_policies)
        end

        [signals, dedupe_policy_refs(policies)]
      rescue JSON::ParserError
        [[], []]
      end
    end
  end
end
