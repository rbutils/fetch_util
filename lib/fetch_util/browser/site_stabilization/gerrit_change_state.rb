# frozen_string_literal: true

module FetchUtil
  class Browser
    module SiteStabilization
      module GerritChangeState
        include GerritChangeProductStateScript
        include GerritChangeRequestStateScript

        private

        def gerrit_change_state(page)
          safe_evaluate(page, gerrit_change_state_script, default: nil)
        end

        def fail_gerrit_change_preparation(page)
          safe_evaluate(page, <<~'JS', default: false)
            (() => {
              const prepared = window.__fetchUtilGerritChange;
              if (!prepared || prepared.status !== "loading") return false;
              prepared.status = "failed";
              prepared.reason = "Gerrit preparation timed out";
              return true;
            })()
          JS
        end

        def gerrit_change_state_script
          <<~JS
            (() => {
              #{gerrit_change_product_state_script}
              #{gerrit_change_request_state_script}
            })()
          JS
        end
      end
    end
  end
end
