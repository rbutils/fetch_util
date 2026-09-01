# frozen_string_literal: true

module FetchUtil
  class Browser
    module SiteStabilization
      module AzureDevopsPrState
        include AzureDevopsPrProductStateScript
        include AzureDevopsPrRequestStateScript

        private

        def azure_devops_pr_state(page)
          safe_evaluate(page, azure_devops_pr_state_script, default: nil)
        end

        def azure_devops_pr_state_script
          <<~JS
            (() => {
              #{azure_devops_pr_product_state_script}
              #{azure_devops_pr_request_state_script}
            })()
          JS
        end
      end
    end
  end
end
