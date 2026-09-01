# frozen_string_literal: true

module FetchUtil
  class Browser
    module SiteStabilization
      module GerritFileResourceFetchStateScript
        private

        def gerrit_file_resource_fetch_state_script
          <<~'JS'
            const requestJson = async (suffix) => {
              const url = new URL(apiPath + suffix, location.origin);
              if (url.origin !== location.origin) throw new Error("cross-origin Gerrit API route");
              const response = await fetch(url.href, {
                credentials: "same-origin",
                headers: { Accept: "application/json" }
              });
              if (!response.ok) throw new Error("Gerrit API returned " + response.status);
              const text = await response.text();
              const value = JSON.parse(text.replace(/^\)\]\}'(?:\r?\n)?/, ""));
              if (!value || typeof value !== "object" || Array.isArray(value)) {
                throw new Error("invalid Gerrit API payload");
              }
              return value;
            };
          JS
        end
      end
    end
  end
end
