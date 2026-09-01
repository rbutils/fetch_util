# frozen_string_literal: true

module FetchUtil
  class Browser
    module SiteStabilization
      module AzureDevopsPrStabilization
        AZURE_DEVOPS_PR_STABILIZATION_PROFILE = {
          host: true,
          path_query: ->(uri) { uri.path.match?(%r{/_git/[^/]+/pullrequest/\d+/?\z}i) },
          strategy: :stabilize_azure_devops_pr,
          fallthrough: true,
          notes: "Prepare product-matched public Azure DevOps pull request REST resources.",
          tests: "spec/fetch_util/browser_stabilization_spec.rb"
        }.freeze

        private

        def stabilize_azure_devops_pr(page)
          state = nil
          ready = retry_until_timeout(capped_timeout(12.0), interval: 0.1) do
            state = azure_devops_pr_state(page)
            return false if state.is_a?(Hash) && (state["product"] == false || state["status"] == "failed")

            state.is_a?(Hash) && state["status"] == "ready"
          end
          settle_after_stabilization(0.25) if ready
          fail_azure_devops_pr_preparation(page) if !ready && state.is_a?(Hash) && state["status"] == "loading"
          ready
        end

        def fail_azure_devops_pr_preparation(page)
          safe_evaluate(page, <<~JS, default: nil)
            (() => {
              const state = window.__fetchUtilAzureDevopsPullRequest;
              if (!state || state.status !== "loading") return state;
              const controller = window.__fetchUtilAzureDevopsPullRequestAbortController;
              if (controller && typeof controller.abort === "function") controller.abort();
              delete window.__fetchUtilAzureDevopsPullRequestAbortController;
              window.__fetchUtilAzureDevopsPullRequest = Object.assign({}, state, {
                status: "failed",
                reason: "Azure DevOps REST preparation timed out"
              });
              return window.__fetchUtilAzureDevopsPullRequest;
            })()
          JS
        end
      end
    end
  end
end
