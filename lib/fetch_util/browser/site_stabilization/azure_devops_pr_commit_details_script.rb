# frozen_string_literal: true

module FetchUtil
  class Browser
    module SiteStabilization
      module AzureDevopsPrCommitDetailsScript
        private

        def azure_devops_pr_commit_details_script
          <<~'JS'
            const AZURE_DEVOPS_COMMIT_DETAIL_CONCURRENCY = 8;
            const completeCommit = async (commit, repositoryId, signal) => {
              const url = new URL(route.prefixPath + "/_apis/git/repositories/" +
                encodeURIComponent(repositoryId) + "/commits/" + encodeURIComponent(commit.commitId), location.origin);
              url.searchParams.set("api-version", "7.1");
              const page = await requestJson(url, signal);
              const detail = page.value;
              if (typeof detail.commitId !== "string" || detail.commitId !== commit.commitId ||
                  detail.commentTruncated !== false || typeof detail.comment !== "string") {
                throw new Error("incomplete Azure DevOps commit detail");
              }
              return Object.assign({}, commit, detail, { commentTruncated: false });
            };

            const completeCommits = async (commits, repositoryId, signal) => {
              const completed = new Array(commits.length);
              let nextIndex = 0;
              const completeNext = async () => {
                while (nextIndex < commits.length) {
                  if (signal.aborted) throw new Error("Azure DevOps preparation aborted");
                  const index = nextIndex;
                  nextIndex += 1;
                  completed[index] = await completeCommit(commits[index], repositoryId, signal);
                }
              };
              const workers = Array.from(
                { length: Math.min(AZURE_DEVOPS_COMMIT_DETAIL_CONCURRENCY, commits.length) },
                completeNext
              );
              await Promise.all(workers);
              return completed;
            };
          JS
        end
      end
    end
  end
end
