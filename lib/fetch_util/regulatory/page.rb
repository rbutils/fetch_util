# frozen_string_literal: true

module FetchUtil
  class Regulatory
    module Page
      def page_record(requested_uri)
        fetch_record("page:#{requested_uri}", requested_uri.to_s, fallback: empty_page_record, require_success: false) do |_body, response|
          final_uri = parse_http_uri(response.url)
          final_path = request_target(final_uri)
          xrobotstag = []
          contentusageheader = []
          tdmheaders = []
          header_policies = []

          response_chain(response).each do |step|
            path = request_target(parse_http_uri(step.url))
            xrobotstag.concat(extract_x_robot_signals(step.headers, path: path))
            contentusageheader.concat(extract_content_usage_header_signals(step.headers, path: path))
            step_tdmheaders, step_policies = extract_tdm_value_signals(
              reservation: first_header_value(step.headers, "tdm-reservation"),
              policy_url: first_header_value(step.headers, "tdm-policy"),
              path: path
            )
            tdmheaders.concat(step_tdmheaders)
            header_policies.concat(step_policies)
          end

          metarobots = []
          tdmmeta = []
          meta_policies = []
          human = []
          if html_content?(response.headers, response.body)
            meta_tags = parse_meta_tags(response.body)
            metarobots = sort_generic_signals(extract_meta_robot_signals(meta_tags, path: final_path))
            tdmmeta, meta_policies = extract_tdm_meta_signals(meta_tags, path: final_path)
            human = sort_generic_signals(extract_human_signals(response.body, path: final_path))
          end

          {
            "final_url" => final_uri.to_s,
            "signals" => {
              "xrobotstag" => sort_generic_signals(xrobotstag),
              "metarobots" => metarobots,
              "tdmheaders" => sort_generic_signals(tdmheaders),
              "tdmmeta" => sort_generic_signals(tdmmeta),
              "contentusageheader" => sort_usage_preference_signals(contentusageheader),
              "human" => human
            },
            "policies" => dedupe_policy_refs(header_policies + meta_policies)
          }
        end
      end

      def empty_page_record
        {
          "final_url" => nil,
          "signals" => {
            "xrobotstag" => [],
            "metarobots" => [],
            "tdmheaders" => [],
            "tdmmeta" => [],
            "contentusageheader" => [],
            "human" => []
          },
          "policies" => []
        }
      end
    end
  end
end
