# frozen_string_literal: true

module FetchUtil
  class Browser
    module SiteStabilization
      autoload :AzureDevopsPrProductStateScript,
               "fetch_util/browser/site_stabilization/azure_devops_pr_product_state_script"
      autoload :AzureDevopsPrCommitDetailsScript,
               "fetch_util/browser/site_stabilization/azure_devops_pr_commit_details_script"
      autoload :AzureDevopsPrRequestHelpersScript,
               "fetch_util/browser/site_stabilization/azure_devops_pr_request_helpers_script"
      autoload :AzureDevopsPrRequestStateScript,
               "fetch_util/browser/site_stabilization/azure_devops_pr_request_state_script"
      autoload :AzureDevopsPrState, "fetch_util/browser/site_stabilization/azure_devops_pr_state"
      autoload :AzureDevopsPrStabilization,
               "fetch_util/browser/site_stabilization/azure_devops_pr_stabilization"
      autoload :BitbucketCloudThreadState,
               "fetch_util/browser/site_stabilization/bitbucket_cloud_thread_state"
      autoload :BitbucketCloudThreads, "fetch_util/browser/site_stabilization/bitbucket_cloud_threads"
      autoload :BitbucketCloudPullResourceState,
               "fetch_util/browser/site_stabilization/bitbucket_cloud_pull_resource_state"
      autoload :BitbucketCloudPullResources,
               "fetch_util/browser/site_stabilization/bitbucket_cloud_pull_resources"
      autoload :CommunityAndMarketplace, "fetch_util/browser/site_stabilization/community_and_marketplace"
      autoload :GerritChangeProductStateScript,
               "fetch_util/browser/site_stabilization/gerrit_change_product_state_script"
      autoload :GerritChangeRequestStateScript,
               "fetch_util/browser/site_stabilization/gerrit_change_request_state_script"
      autoload :GerritChangeState, "fetch_util/browser/site_stabilization/gerrit_change_state"
      autoload :GerritChangeStabilization,
               "fetch_util/browser/site_stabilization/gerrit_change_stabilization"
      autoload :GerritFileResourceProductStateScript,
               "fetch_util/browser/site_stabilization/gerrit_file_resource_product_state_script"
      autoload :GerritFileResourceRouteStateScript,
               "fetch_util/browser/site_stabilization/gerrit_file_resource_route_state_script"
      autoload :GerritFileResourceFetchStateScript,
               "fetch_util/browser/site_stabilization/gerrit_file_resource_fetch_state_script"
      autoload :GerritFileResourceValidationStateScript,
               "fetch_util/browser/site_stabilization/gerrit_file_resource_validation_state_script"
      autoload :GerritFileResourceRequestStateScript,
               "fetch_util/browser/site_stabilization/gerrit_file_resource_request_state_script"
      autoload :GerritFileResourceState,
               "fetch_util/browser/site_stabilization/gerrit_file_resource_state"
      autoload :GerritFileResourceStabilization,
               "fetch_util/browser/site_stabilization/gerrit_file_resource_stabilization"
      autoload :GithubPullResources, "fetch_util/browser/site_stabilization/github_pull_resources"
      autoload :GithubPullResourceStabilization,
               "fetch_util/browser/site_stabilization/github_pull_resource_stabilization"
      autoload :GithubThreads, "fetch_util/browser/site_stabilization/github_threads"
      autoload :GiteaFamilyThreadProductState,
               "fetch_util/browser/site_stabilization/gitea_family_thread_product_state"
      autoload :GiteaFamilyThreadTimelineState,
               "fetch_util/browser/site_stabilization/gitea_family_thread_timeline_state"
      autoload :GiteaFamilyStabilization,
               "fetch_util/browser/site_stabilization/gitea_family_stabilization"
      autoload :GiteaFamilyVisibilityScript,
               "fetch_util/browser/site_stabilization/gitea_family_visibility_script"
      autoload :GiteaFamilyThreads, "fetch_util/browser/site_stabilization/gitea_family_threads"
      autoload :GiteaFamilyPullResourceProductState,
               "fetch_util/browser/site_stabilization/gitea_family_pull_resource_product_state"
      autoload :GiteaFamilyPullResourceState,
               "fetch_util/browser/site_stabilization/gitea_family_pull_resource_state"
      autoload :GiteaFamilyPullResources, "fetch_util/browser/site_stabilization/gitea_family_pull_resources"
      autoload :GitlabRepo, "fetch_util/browser/site_stabilization/gitlab_repo"
      autoload :GitlabMergeRequestResourceVisibilityScript,
               "fetch_util/browser/site_stabilization/gitlab_merge_request_resource_visibility_script"
      autoload :GitlabMergeRequestResourceStateScript,
               "fetch_util/browser/site_stabilization/gitlab_merge_request_resource_state_script"
      autoload :GitlabMergeRequestResourceState,
               "fetch_util/browser/site_stabilization/gitlab_merge_request_resource_state"
      autoload :GitlabMergeRequestResources, "fetch_util/browser/site_stabilization/gitlab_merge_request_resources"
      autoload :GitlabStabilization, "fetch_util/browser/site_stabilization/gitlab_stabilization"
      autoload :GitlabThreads, "fetch_util/browser/site_stabilization/gitlab_threads"
      autoload :SocialPlatforms, "fetch_util/browser/site_stabilization/social_platforms"
      autoload :TravelAndLodging, "fetch_util/browser/site_stabilization/travel_and_lodging"

      include AzureDevopsPrState
      include AzureDevopsPrStabilization
      include BitbucketCloudThreadState
      include BitbucketCloudThreads
      include BitbucketCloudPullResourceState
      include BitbucketCloudPullResources
      include CommunityAndMarketplace
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
      include SocialPlatforms
      include TravelAndLodging
    end
  end
end
