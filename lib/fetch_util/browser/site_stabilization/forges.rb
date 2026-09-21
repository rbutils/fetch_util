# frozen_string_literal: true

module FetchUtil
  class Browser
    module SiteStabilization
      autoload :AzureDevopsPrProductStateScript,
               "fetch_util/browser/site_stabilization/forges/azure_devops/pull_requests/product_state_script"
      autoload :AzureDevopsPrCommitDetailsScript,
               "fetch_util/browser/site_stabilization/forges/azure_devops/pull_requests/commit_details_script"
      autoload :AzureDevopsPrRequestHelpersScript,
               "fetch_util/browser/site_stabilization/forges/azure_devops/pull_requests/request_helpers_script"
      autoload :AzureDevopsPrRequestStateScript,
               "fetch_util/browser/site_stabilization/forges/azure_devops/pull_requests/request_state_script"
      autoload :AzureDevopsPrState,
               "fetch_util/browser/site_stabilization/forges/azure_devops/pull_requests/state"
      autoload :AzureDevopsPrStabilization,
               "fetch_util/browser/site_stabilization/forges/azure_devops/pull_requests/stabilization"
      autoload :BitbucketCloudThreadState,
               "fetch_util/browser/site_stabilization/forges/bitbucket/threads/state"
      autoload :BitbucketCloudThreads,
               "fetch_util/browser/site_stabilization/forges/bitbucket/threads/index"
      autoload :BitbucketCloudPullResourceModules,
               "fetch_util/browser/site_stabilization/forges/bitbucket/pulls/resource_modules"
      autoload :GerritChangeProductStateScript,
               "fetch_util/browser/site_stabilization/forges/gerrit/changes/product_state_script"
      autoload :GerritChangeRequestStateScript,
               "fetch_util/browser/site_stabilization/forges/gerrit/changes/request_state_script"
      autoload :GerritChangeState,
               "fetch_util/browser/site_stabilization/forges/gerrit/changes/state"
      autoload :GerritChangeStabilization,
               "fetch_util/browser/site_stabilization/forges/gerrit/changes/stabilization"
      autoload :GerritFileResourceProductStateScript,
               "fetch_util/browser/site_stabilization/forges/gerrit/resources/product_state_script"
      autoload :GerritFileResourceRouteStateScript,
               "fetch_util/browser/site_stabilization/forges/gerrit/resources/route_state_script"
      autoload :GerritFileResourceFetchStateScript,
               "fetch_util/browser/site_stabilization/forges/gerrit/resources/fetch_state_script"
      autoload :GerritFileResourceValidationStateScript,
               "fetch_util/browser/site_stabilization/forges/gerrit/resources/validation_state_script"
      autoload :GerritFileResourceRequestStateScript,
               "fetch_util/browser/site_stabilization/forges/gerrit/resources/request_state_script"
      autoload :GerritFileResourceState,
               "fetch_util/browser/site_stabilization/forges/gerrit/resources/state"
      autoload :GerritFileResourceStabilization,
               "fetch_util/browser/site_stabilization/forges/gerrit/resources/stabilization"
      autoload :GithubPullResources,
               "fetch_util/browser/site_stabilization/forges/github/pull_resources"
      autoload :GithubPullResourceStabilization,
               "fetch_util/browser/site_stabilization/forges/github/pull_resource_stabilization"
      autoload :GithubThreads, "fetch_util/browser/site_stabilization/forges/github/threads"
      autoload :ForgeObservationState, "fetch_util/browser/site_stabilization/forges/observation_state"
      autoload :GiteaFamilyThreadProductState,
               "fetch_util/browser/site_stabilization/forges/gitea/threads/product_state"
      autoload :GiteaFamilyThreadTimelineState,
               "fetch_util/browser/site_stabilization/forges/gitea/threads/timeline_state"
      autoload :GiteaFamilyStabilization,
               "fetch_util/browser/site_stabilization/forges/gitea/stabilization"
      autoload :GiteaFamilyVisibilityScript,
               "fetch_util/browser/site_stabilization/forges/gitea/visibility_script"
      autoload :GiteaFamilyThreads,
               "fetch_util/browser/site_stabilization/forges/gitea/threads/index"
      autoload :GiteaFamilyPullResourceProductState,
               "fetch_util/browser/site_stabilization/forges/gitea/pulls/product_state"
      autoload :GiteaFamilyPullResourceState,
               "fetch_util/browser/site_stabilization/forges/gitea/pulls/state"
      autoload :GiteaFamilyPullResources,
               "fetch_util/browser/site_stabilization/forges/gitea/pulls/resources"
      autoload :GitlabRepo, "fetch_util/browser/site_stabilization/forges/gitlab/repository"
      autoload :GitlabMergeRequestResourceVisibilityScript,
               "fetch_util/browser/site_stabilization/forges/gitlab/merge_requests/resource_visibility_script"
      autoload :GitlabMergeRequestResourceStateScript,
               "fetch_util/browser/site_stabilization/forges/gitlab/merge_requests/resource_state_script"
      autoload :GitlabMergeRequestResourceState,
               "fetch_util/browser/site_stabilization/forges/gitlab/merge_requests/resource_state"
      autoload :GitlabMergeRequestResources,
               "fetch_util/browser/site_stabilization/forges/gitlab/merge_requests/resources"
      autoload :GitlabStabilization,
               "fetch_util/browser/site_stabilization/forges/gitlab/stabilization"
      autoload :GitlabThreads, "fetch_util/browser/site_stabilization/forges/gitlab/threads"

      module ForgeStabilization
        include AzureDevopsPrState
        include AzureDevopsPrStabilization
        include BitbucketCloudThreadState
        include BitbucketCloudThreads
        include BitbucketCloudPullResourceModules
        include GerritChangeState
        include GerritChangeStabilization
        include GerritFileResourceState
        include GerritFileResourceStabilization
        include GithubPullResources
        include GithubPullResourceStabilization
        include GithubThreads
        include GiteaFamilyVisibilityScript
        include GiteaFamilyThreadProductState
        include GiteaFamilyThreadTimelineState
        include GiteaFamilyStabilization
        include GiteaFamilyThreads
        include GiteaFamilyPullResourceProductState
        include GiteaFamilyPullResourceState
        include GiteaFamilyPullResources
        include GitlabRepo
        include GitlabStabilization
        include GitlabMergeRequestResources
        include GitlabThreads
      end
    end
  end
end
