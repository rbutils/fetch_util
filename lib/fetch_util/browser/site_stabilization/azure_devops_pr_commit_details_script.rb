# frozen_string_literal: true

module FetchUtil
  class Browser
    module SiteStabilization
      module AzureDevopsPrCommitDetailsScript
        private

        def azure_devops_pr_commit_details_script
          <<~'JS'
            const completeCommit = async (commit, repositoryId) => {
              if (!commit.commentTruncated) return commit;

              const url = new URL(route.prefixPath + "/_apis/git/repositories/" +
                encodeURIComponent(repositoryId) + "/commits/" + encodeURIComponent(commit.commitId), location.origin);
              url.searchParams.set("api-version", "7.1");
              const page = await requestJson(url);
              const detail = page.value;
              if (String(detail.commitId || "") !== String(commit.commitId) ||
                  detail.commentTruncated || typeof detail.comment !== "string") {
                throw new Error("incomplete Azure DevOps commit detail");
              }
              return Object.assign({}, commit, detail, { commentTruncated: false });
            };
          JS
        end
      end
    end
  end
end
