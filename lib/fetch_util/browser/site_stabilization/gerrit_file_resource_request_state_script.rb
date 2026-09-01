# frozen_string_literal: true

module FetchUtil
  class Browser
    module SiteStabilization
      module GerritFileResourceRequestStateScript
        private

        def gerrit_file_resource_request_state_script
          gerrit_file_resource_fetch_state_script + gerrit_file_resource_validation_state_script + <<~'JS'
            window[stateKey] = { status: "loading", product: true, routeKey: routeKey, route: route };

            const comparisonQuery = new URLSearchParams();
            if (route.comparison === "patchset") comparisonQuery.set("base", route.comparisonValue);
            if (route.comparison === "parent") comparisonQuery.set("parent", route.comparisonValue);
            const query = comparisonQuery.toString();
            const filesSuffix = "/revisions/" + encodeURIComponent(route.target) + "/files/" +
              (query ? "?" + query : "");

            Promise.all([
              requestJson("/detail?o=ALL_REVISIONS&o=ALL_COMMITS&o=DETAILED_LABELS&o=DETAILED_ACCOUNTS&o=MESSAGES"),
              requestJson("/comments?enable-context=true&context-padding=3"),
              requestJson(filesSuffix)
            ]).then(async ([detail, comments, files]) => {
              if (String(detail._number || "") !== route.number || detail.project !== route.project) {
                throw new Error("Gerrit API change identity mismatch");
              }
              if (!objectRecord(detail.revisions)) throw new Error("invalid Gerrit revisions payload");
              if (!Object.values(comments).every(
                (records) => Array.isArray(records) && records.every(objectRecord)
              )) throw new Error("invalid Gerrit comments payload");
              if (!Object.values(files).every(objectRecord)) throw new Error("invalid Gerrit files payload");
              const revisions = Object.values(detail.revisions || {});
              const targetRevision = revisions.find(
                (revision) => String(revision && revision._number || "") === route.target
              );
              if (!targetRevision) throw new Error("Gerrit API target patch set identity mismatch");
              if (route.comparison === "patchset" && !revisions.some(
                (revision) => String(revision && revision._number || "") === route.comparisonValue
              )) throw new Error("Gerrit API base patch set identity mismatch");
              if (route.comparison === "parent" &&
                  (!targetRevision.commit || !Array.isArray(targetRevision.commit.parents) ||
                    targetRevision.commit.parents.length < Number(route.comparisonValue))) {
                throw new Error("Gerrit API parent identity mismatch");
              }

              let filePath = route.filePath;
              if (!Object.prototype.hasOwnProperty.call(files, filePath)) {
                filePath = Object.keys(files).find((path) => files[path] && files[path].old_path === route.filePath);
              }
              if (!filePath || !files[filePath]) throw new Error("Gerrit API file identity mismatch");

              const diffQuery = new URLSearchParams(comparisonQuery);
              diffQuery.set("context", "ALL");
              const encodedFile = encodeURIComponent(filePath);
              const diff = await requestJson("/revisions/" + encodeURIComponent(route.target) +
                "/files/" + encodedFile + "/diff?" + diffQuery.toString());
              validateDiff(diff, filePath);
              let firstParentDiff = null;
              if (route.comparison === "implicit" && targetRevision.commit &&
                  Array.isArray(targetRevision.commit.parents) && targetRevision.commit.parents.length > 1) {
                const firstParentQuery = new URLSearchParams();
                firstParentQuery.set("parent", "1");
                firstParentQuery.set("context", "ALL");
                firstParentDiff = await requestJson("/revisions/" + encodeURIComponent(route.target) +
                  "/files/" + encodedFile + "/diff?" + firstParentQuery.toString());
                validateDiff(firstParentDiff, filePath);
              }
              const countComments = Object.keys(comments || {}).reduce(
                (total, path) => total + (Array.isArray(comments[path]) ? comments[path].length : 0), 0
              );
              window[stateKey] = {
                status: "ready",
                product: true,
                routeKey: routeKey,
                route: route,
                detail: detail,
                comments: comments,
                files: files,
                filePath: filePath,
                requestedFilePath: route.filePath,
                file: files[filePath],
                diff: diff,
                firstParentDiff: firstParentDiff,
                fileCount: Object.keys(files).length,
                commentCount: countComments,
                diffBlockCount: Array.isArray(diff.content) ? diff.content.length : 0,
                firstParentDiffBlockCount: firstParentDiff && Array.isArray(firstParentDiff.content)
                  ? firstParentDiff.content.length : 0
              };
            }).catch((error) => {
              window[stateKey] = {
                status: "failed",
                product: true,
                routeKey: routeKey,
                route: route,
                reason: String(error && error.message || error || "Gerrit file preparation failed")
              };
            });

            return { matched: true, product: true, status: "loading", signature: "loading" };
          JS
        end
      end
    end
  end
end
