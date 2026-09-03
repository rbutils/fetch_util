# frozen_string_literal: true

module FetchUtil
  class Browser
    module SiteStabilization
      module GerritChangeRequestStateScript
        private

        def gerrit_change_request_state_script
          <<~'JS'
            const prepared = { status: "loading", product: true, routeKey: routeKey, route: route };
            window[stateKey] = prepared;

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
            const selectedRevision = route.patchset || "current";
            Promise.all([
              requestJson("/detail?o=ALL_REVISIONS&o=ALL_COMMITS&o=DETAILED_LABELS&o=DETAILED_ACCOUNTS&o=MESSAGES"),
              requestJson("/comments?enable-context=true&context-padding=3"),
              requestJson("/revisions/" + encodeURIComponent(selectedRevision) + "/files/")
            ]).then(([detail, comments, files]) => {
              if (window[stateKey] !== prepared || prepared.status !== "loading") return;
              if (String(detail._number || "") !== number || !detail.project || detail.project !== projectPath) {
                throw new Error("Gerrit API change identity mismatch");
              }
              const selectedExists = !route.patchset || Object.values(detail.revisions || {}).some(
                (revision) => String(revision && revision._number || "") === route.patchset
              );
              if (!selectedExists) throw new Error("Gerrit API patch set identity mismatch");
              const countComments = (collection) => Object.keys(collection || {}).reduce(
                (total, path) => total + (Array.isArray(collection[path]) ? collection[path].length : 0), 0
              );
              window[stateKey] = {
                status: "ready",
                product: true,
                routeKey: routeKey,
                route: route,
                detail: detail,
                comments: comments,
                files: files,
                messageCount: Array.isArray(detail.messages) ? detail.messages.length : 0,
                commentCount: countComments(comments),
                fileCount: Object.keys(files).length
              };
            }).catch((error) => {
              if (window[stateKey] !== prepared || prepared.status !== "loading") return;
              window[stateKey] = {
                status: "failed",
                product: true,
                routeKey: routeKey,
                route: route,
                reason: String(error && error.message || error || "Gerrit preparation failed")
              };
            });

            return { matched: true, product: true, status: "loading", signature: "loading" };
          JS
        end
      end
    end
  end
end
