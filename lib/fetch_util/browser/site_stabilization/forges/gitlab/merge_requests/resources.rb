# frozen_string_literal: true

module FetchUtil
  class Browser
    module SiteStabilization
      module GitlabMergeRequestResources
        include GitlabMergeRequestResourceState

        GITLAB_MERGE_REQUEST_RESOURCE_STABILIZATION_PROFILE = {
          host: true,
          path_query: lambda { |uri|
            uri.path.match?(%r{/-/merge_requests/\d+/(?:commits|pipelines|reports(?:/[^/]+)?|diffs)/?\z})
          },
          strategy: :stabilize_gitlab_merge_request_resource,
          fallthrough: true,
          notes: "Wait for host-agnostic GitLab merge-request resource pages.",
          tests: "spec/fetch_util/browser_stabilization_spec.rb"
        }.freeze

        private

        def stabilize_gitlab_merge_request_resource(page, deadline: stabilization_deadline)
          stabilize_gitlab_state(deadline: deadline) { gitlab_merge_request_resource_state(page) }
        end
      end
    end
  end
end
