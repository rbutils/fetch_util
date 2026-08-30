# frozen_string_literal: true

require_relative "../http_redirect_client"

module FetchUtil
  class Regulatory
    class HttpClient
      DEFAULT_ACCEPT = "text/html,application/json,text/plain,*/*"

      def initialize(timeout:, user_agent:, redirect_client: nil)
        @user_agent = user_agent.to_s.strip
        @redirect_client = redirect_client || FetchUtil::HttpRedirectClient.new(timeout: timeout, headers: request_headers)
      end

      def get(url, limit: FetchUtil::HttpRedirectClient::REDIRECT_LIMIT)
        build_response(redirect_client.get(url, limit: limit))
      rescue URI::InvalidURIError
        raise InputError, "unsupported url: #{url}"
      end

      private

      attr_reader :redirect_client, :user_agent

      def build_response(response)
        FetchUtil::Regulatory::Response.new(
          url: response.url,
          status: response.status,
          headers: response.headers,
          body: response.body,
          redirects: response.redirects.map { |redirect| build_response(redirect) }
        )
      end

      def request_headers
        {
          "Accept" => DEFAULT_ACCEPT,
          "User-Agent" => user_agent
        }
      end
    end
  end
end
