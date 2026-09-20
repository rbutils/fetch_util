# frozen_string_literal: true

module FetchUtil
  class Browser
    module SiteStabilization
      module GitlabMergeRequestResourceState
        include GitlabMergeRequestResourceStateScript

        private

        def gitlab_merge_request_resource_state(page)
          safe_evaluate(page, gitlab_merge_request_resource_state_script, default: nil)
        end
      end
    end
  end
end
