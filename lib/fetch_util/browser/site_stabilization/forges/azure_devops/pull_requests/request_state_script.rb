# frozen_string_literal: true

module FetchUtil
  class Browser
    module SiteStabilization
      module AzureDevopsPrRequestStateScript
        include AzureDevopsPrCommitDetailsScript
        include AzureDevopsPrRequestHelpersScript

        private

        def azure_devops_pr_request_state_script
          <<~JS
            #{azure_devops_pr_request_lifecycle_script}

            #{azure_devops_pr_request_helpers_script}
            #{azure_devops_pr_commit_details_script}

            const metadataUrl = new URL(route.apiPath, location.origin);
            metadataUrl.searchParams.set("api-version", "7.1");
            requestJson(metadataUrl, signal).then(async ({ value: metadata }) => {
              const repositoryData = metadata.repository || {};
              const projectData = repositoryData.project || {};
              const repositoryId = typeof repositoryData.id === "string" ? repositoryData.id.trim() : "";
              if (String(metadata.pullRequestId || "") !== route.number ||
                  String(repositoryData.name || "").toLowerCase() !== route.repository.toLowerCase() ||
                  String(projectData.name || "").toLowerCase() !== route.project.toLowerCase() ||
                  !/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(repositoryId) ||
                  !/^public$/i.test(String(projectData.visibility || ""))) {
                throw new Error("Azure DevOps API pull request identity mismatch");
              }
              if (repositoryData.webUrl && new URL(repositoryData.webUrl, location.href).origin !== location.origin) {
                throw new Error("Azure DevOps API repository origin mismatch");
              }

              const repositoryApiPath = route.prefixPath + "/_apis/git/repositories/" +
                encodeURIComponent(repositoryId) + "/pullRequests/" + route.number;
              route.repositoryApiPath = repositoryApiPath;
              const threadsUrl = new URL(repositoryApiPath + "/threads", location.origin);
              threadsUrl.searchParams.set("api-version", "7.1");
            const threadsPage = await requestJson(threadsUrl, signal);
            const threads = threadsPage.value;
            if (!Array.isArray(threads.value)) throw new Error("invalid Azure DevOps threads payload");
            if (!Number.isInteger(threads.count) || threads.count !== threads.value.length) {
              throw new Error("incomplete Azure DevOps threads payload");
            }
            const threadsContinuation = threadsPage.response.headers &&
              threadsPage.response.headers.get("x-ms-continuationtoken");
            if (threadsContinuation) throw new Error("unexpected Azure DevOps threads continuation");

              const commits = [];
              const seenTokens = new Set();
              let continuation = "";
              do {
                const commitsUrl = new URL(repositoryApiPath + "/commits", location.origin);
                commitsUrl.searchParams.set("api-version", "7.1");
                commitsUrl.searchParams.set("$top", "1000");
              if (continuation) commitsUrl.searchParams.set("continuationToken", continuation);
              const page = await requestJson(commitsUrl, signal);
              if (!Array.isArray(page.value.value)) throw new Error("invalid Azure DevOps commits payload");
              if (!Number.isInteger(page.value.count) || page.value.count !== page.value.value.length) {
                throw new Error("incomplete Azure DevOps commits payload");
              }
              page.value.value.forEach((commit) => {
                if (!commit || typeof commit.commitId !== "string" || !/^[0-9a-f]{40}$/i.test(commit.commitId)) {
                  throw new Error("invalid Azure DevOps commit record");
                }
                commits.push(commit);
              });
              const nextValue = page.response.headers &&
                page.response.headers.get("x-ms-continuationtoken");
              if (nextValue != null && typeof nextValue !== "string") {
                throw new Error("invalid Azure DevOps continuation token");
              }
              const next = (nextValue || "").trim();
                if (next && seenTokens.has(next)) throw new Error("repeated Azure DevOps continuation token");
                if (next) seenTokens.add(next);
                continuation = next;
              } while (continuation);

              const completedCommits = await completeCommits(commits, repositoryId, signal);

              const comments = threads.value.reduce((total, thread) =>
                total + (Array.isArray(thread && thread.comments) ? thread.comments.length : 0), 0);
              if (!preparationActive()) return;
              clearAbortController();
              window[stateKey] = {
                status: "ready",
                product: true,
                routeKey: routeKey,
                route: route,
                metadata: metadata,
                threads: threads,
                commits: completedCommits,
                threadCount: threads.value.length,
                commentCount: comments,
                commitCount: completedCommits.length
              };
            }).catch((error) => {
              if (!preparationActive()) return;
              abortController.abort();
              clearAbortController();
              window[stateKey] = {
                status: "failed",
                product: true,
                routeKey: routeKey,
                route: route,
                reason: String(error && error.message || error || "Azure DevOps preparation failed")
              };
            });

            return { matched: true, product: true, status: "loading", signature: "loading" };
          JS
        end
      end
    end
  end
end
