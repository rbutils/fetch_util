# frozen_string_literal: true

module FetchUtil
  class Regulatory
    module Orchestration
      def initialize(client: nil, cache_path: DEFAULT_CACHE_PATH, sources: nil, timeout: 20, user_agent: nil)
        @client = client || HttpClient.new(timeout: timeout, user_agent: user_agent || default_user_agent)
        @cache_path = cache_path || DEFAULT_CACHE_PATH
        @source_tokens = sources
      end

      def call(url)
        requested_uri = parse_http_uri(url)
        origin_query = origin_query?(requested_uri)
        query_target = request_target(requested_uri)
        effective_query_target = query_target
        selected_sources = resolve_sources(@source_tokens)
        result = {}
        policy_refs = []

        if needs_tdmrep_fetch?(selected_sources)
          record = tdmrep_record(requested_uri)
          if selected_sources.include?("tdmrep")
            add_source_payload(result, "tdmrep", scoped_signals(record["signals"], origin_query: origin_query, query_target: query_target))
          end
          policy_refs.concat(record["policies"])
        end

        if selected_sources.include?("trusttxt")
          record = trusttxt_record(requested_uri)
          add_source_payload(result, "trusttxt", scoped_signals(record["signals"], origin_query: origin_query, query_target: query_target))
        end

        if needs_robots_fetch?(selected_sources)
          record = robots_record(requested_uri)
          %w[robotstxt contentsignal contentusagerobots].each do |source|
            next unless selected_sources.include?(source)

            add_source_payload(
              result,
              source,
              scoped_signals(record.dig("signals", source), origin_query: origin_query, query_target: query_target)
            )
          end
        end

        if needs_page_fetch?(selected_sources)
          record = page_record(requested_uri)
          effective_query_target = page_query_target(record, fallback: query_target)
          %w[xrobotstag metarobots tdmheaders tdmmeta contentusageheader human].each do |source|
            next unless selected_sources.include?(source)

            add_source_payload(
              result,
              source,
              scoped_signals(record.dig("signals", source), origin_query: origin_query, query_target: effective_query_target)
            )
          end
          policy_refs.concat(record["policies"])
        end

        if selected_sources.include?("tdmpolicy")
          add_source_payload(
            result,
            "tdmpolicy",
            scoped_signals(expanded_tdm_policy_signals(policy_refs), origin_query: origin_query, query_target: effective_query_target)
          )
        end

        result
      end

      private

      attr_reader :cache_path, :client

      def default_user_agent
        "fetch_util/#{FetchUtil::VERSION}"
      end
    end
  end
end
