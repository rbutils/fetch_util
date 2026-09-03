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

        def fail_gerrit_file_resource_preparation(page)
          safe_evaluate(page, <<~'JS', default: false)
            (() => {
              const prepared = window.__fetchUtilGerritFileResource;
              if (!prepared || prepared.status !== "loading") return false;
              prepared.status = "failed";
              prepared.reason = "Gerrit file preparation timed out";
              return true;
            })()
          JS
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
