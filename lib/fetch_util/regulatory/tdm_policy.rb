# frozen_string_literal: true

module FetchUtil
  class Regulatory
    module TdmPolicy
      def expanded_tdm_policy_signals(policy_refs)
        dedupe_policy_refs(policy_refs).flat_map do |policy_ref|
          record = tdm_policy_record(policy_ref["url"])
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

      def tdm_policy_record(url)
        cache_fetch("tdmpolicy:#{url}") do
          response = safe_get(url)
          signals = []
          if response&.status&.between?(200, 299) && json_like_response?(response.headers, response.body)
            signals = extract_tdm_policy_signals(response.body)
          end
          { "signals" => sort_specificity_signals(signals) }
        end
      end

      def extract_tdm_policy_signals(body)
        payload = JSON.parse(body.to_s)
        permissions = array_value(payload, "permission")

        permissions.filter_map do |permission|
          next unless permission.is_a?(Hash)
          next unless tdm_policy_action?(permission["action"])

          conditions = {}
          duties = array_value(permission, "duty").filter_map { |item| duty_name(item) }
          conditions["duty"] = duties if duties.any?
          purpose = permission_purpose(permission)
          conditions["purpose"] = purpose if purpose

          signal = build_signal("allow", "text-and-data-mining", conditions: conditions)
          target_path = policy_target_path(permission["target"])
          signal["path"] = target_path if target_path
          signal
        end
      rescue JSON::ParserError
        []
      end
    end
  end
end
