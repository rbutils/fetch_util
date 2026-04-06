# frozen_string_literal: true

module FetchUtil
  class Regulatory
    module TdmPage
      def extract_tdm_meta_signals(meta_tags, path:)
        reservation = nil
        policy_url = nil

        meta_tags.each do |attributes|
          name = attributes["name"].to_s.strip.downcase
          reservation ||= attributes["content"] if name == "tdm-reservation"
          policy_url ||= attributes["content"] if name == "tdm-policy"
        end

        extract_tdm_value_signals(reservation: reservation, policy_url: policy_url, path: path)
      end

      def extract_tdm_value_signals(reservation:, policy_url:, path:)
        value = reservation.to_s.strip
        return [[], []] unless %w[0 1].include?(value)

        conditions = {}
        policy = policy_url.to_s.strip
        conditions["policy"] = policy if value == "1" && !policy.empty?
        signals = [
          build_signal(
            value == "1" ? "disallow" : "allow",
            "text-and-data-mining",
            path: path,
            conditions: conditions
          )
        ]
        policies = value == "1" ? [policy_ref(policy, path)] : []
        [signals, dedupe_policy_refs(policies)]
      end
    end
  end
end
