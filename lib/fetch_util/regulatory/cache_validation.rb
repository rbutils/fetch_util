# frozen_string_literal: true

module FetchUtil
  class Regulatory
    module CacheValidation
      private

      def cache_payload_matches?(payload, shape)
        case shape
        when Hash
          payload.is_a?(Hash) && shape.all? do |key, value_shape|
            payload.key?(key) && cache_payload_matches?(payload[key], value_shape)
          end
        when Array
          payload.is_a?(Array)
        when nil
          payload.nil? || payload.is_a?(String)
        else
          payload.is_a?(shape.class)
        end
      end
    end
  end
end
