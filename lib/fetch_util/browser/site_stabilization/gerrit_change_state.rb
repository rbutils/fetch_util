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
