# frozen_string_literal: true

module FetchUtil
  class Browser
    module SiteStabilization
      module AzureDevopsPrRequestHelpersScript
        private

        def azure_devops_pr_request_helpers_script
          <<~'JS'
            const requestJson = async (url) => {
              if (url.origin !== location.origin) throw new Error("cross-origin Azure DevOps API route");
              const response = await fetch(url.href, {
                credentials: "same-origin",
                redirect: "error",
                headers: { Accept: "application/json", "X-TFS-FedAuthRedirect": "Suppress" }
              });
              if (response.url && new URL(response.url, location.href).origin !== location.origin) {
                throw new Error("cross-origin Azure DevOps API response");
              }
              if (!response.ok) throw new Error("Azure DevOps API returned " + response.status);
              const value = await response.json();
              if (!value || typeof value !== "object" || Array.isArray(value)) {
                throw new Error("invalid Azure DevOps API payload");
              }
              return { response: response, value: value };
            };
          JS
        end
      end
    end
  end
end
