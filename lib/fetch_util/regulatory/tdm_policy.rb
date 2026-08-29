# frozen_string_literal: true

module FetchUtil
  class Regulatory
    module TdmPolicy
      def expanded_tdm_policy_signals(policy_refs, target_origin:)
        dedupe_policy_refs(policy_refs).flat_map do |policy_ref|
          record = tdm_policy_record(policy_ref["url"], target_origin: target_origin)
          Array(record["signals"]).map do |template|
            signal = deep_copy(template)
            signal["path"] ||= policy_ref["path"]
            conditions = signal["conditions"] || {}
            conditions["policy"] = policy_ref["url"]
            signal["conditions"] = conditions
            signal
          end
        end
      end

      def tdm_policy_record(url, target_origin:)
        cache_fetch("tdmpolicy:#{origin_key(target_origin)}:#{url}") do
          response, cacheable = safe_get(url)
          signals = []
          if response&.status&.between?(200, 299) && json_like_response?(response.headers, response.body)
            signals = extract_tdm_policy_signals(response.body, target_origin: target_origin)
          end
          [{ "signals" => sort_specificity_signals(signals) }, cacheable]
        end
      end

      def extract_tdm_policy_signals(body, target_origin: nil)
        payload = JSON.parse(body.to_s)
        return [] unless payload.is_a?(Hash)

        permissions = array_value(payload, "permission")

        permissions.filter_map do |permission|
          next unless permission.is_a?(Hash)
          next unless tdm_policy_action?(permission["action"])

          target = permission["target"]
          target_path = policy_target_path(target, target_origin: target_origin)
          next if !target.to_s.strip.empty? && target_path.nil?

          conditions = {}
          duties = array_value(permission, "duty").filter_map { |item| duty_name(item) }
          conditions["duty"] = duties if duties.any?
          purpose = permission_purpose(permission)
          conditions["purpose"] = purpose if purpose

          signal = build_signal("allow", "text-and-data-mining", conditions: conditions)
          signal["path"] = target_path if target_path
          signal
        end
      rescue JSON::ParserError
        []
      end
    end
  end
end
