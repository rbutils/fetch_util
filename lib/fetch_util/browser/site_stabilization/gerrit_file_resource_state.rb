# frozen_string_literal: true

module FetchUtil
  class Browser
    module SiteStabilization
      module GerritFileResourceState
        include GerritFileResourceRouteStateScript
        include GerritFileResourceProductStateScript
        include GerritFileResourceFetchStateScript
        include GerritFileResourceValidationStateScript
        include GerritFileResourceRequestStateScript

        private

        def gerrit_file_resource_state(page)
          safe_evaluate(page, gerrit_file_resource_state_script, default: nil)
        end

        def gerrit_file_resource_state_script
          <<~JS
            (() => {
              #{gerrit_file_resource_product_state_script}
              #{gerrit_file_resource_request_state_script}
            })()
          JS
        end
      end
    end
  end
end
