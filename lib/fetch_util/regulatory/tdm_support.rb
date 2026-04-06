# frozen_string_literal: true

module FetchUtil
  class Regulatory
    module TdmSupport
      private

      def tdm_policy_action?(value)
        odrl_token(value) == "mine"
      end

      def duty_name(value)
        action = value.is_a?(Hash) ? value["action"].to_s : value.to_s
        return nil if action.empty?

        normalized = odrl_token(action)
        case normalized.downcase
        when "obtainconsent"
          "obtain-consent"
        when "compensate"
          "compensate"
        else
          normalized.downcase.gsub(/[^a-z0-9]+/, "-").sub(/\A-+|-+\z/, "")
        end
      end

      def permission_purpose(permission)
        array_value(permission, "constraint").each do |constraint|
          next unless constraint.is_a?(Hash)
          next unless odrl_token(constraint["leftOperand"]) == "purpose"
          next unless odrl_token(constraint["operator"]) == "eq"

          right_operand = odrl_token(constraint["rightOperand"])
          return "research" if right_operand == "research"
          return "non-research" if right_operand == "non-research"
        end

        nil
      end

      def policy_target_path(value)
        target = value.to_s.strip
        return nil if target.empty?

        uri = URI.parse(target)
        return normalize_output_path(request_target(uri)) if uri.is_a?(URI::HTTP)
        return normalize_output_path(target) if target.start_with?("/")

        nil
      rescue URI::InvalidURIError
        nil
      end

      def string_value(hash, key)
        hash[key].to_s.strip
      end

      def array_value(hash, key)
        value = hash[key]
        return value if value.is_a?(Array)
        return [] if value.nil?

        [value]
      end

      def policy_ref(url, path)
        candidate = url.to_s.strip
        return nil if candidate.empty?

        parse_http_uri(candidate)
        { "url" => candidate, "path" => path }
      rescue ArgumentError
        nil
      end

      def dedupe_policy_refs(policy_refs)
        seen = {}
        Array(policy_refs).compact.each_with_object([]) do |policy_ref, list|
          key = [policy_ref["url"], policy_ref["path"]]
          next if seen[key]

          seen[key] = true
          list << policy_ref
        end
      end

      def odrl_token(value)
        value.to_s.strip.downcase.split(/[#:]/).last.to_s
      end
    end
  end
end
