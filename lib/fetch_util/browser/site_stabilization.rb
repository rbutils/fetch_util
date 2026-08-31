# frozen_string_literal: true

module FetchUtil
  class Browser
    module SiteStabilization
      autoload :CommunityAndMarketplace, "fetch_util/browser/site_stabilization/community_and_marketplace"
      autoload :GithubPullResources, "fetch_util/browser/site_stabilization/github_pull_resources"
      autoload :GithubThreads, "fetch_util/browser/site_stabilization/github_threads"
      autoload :GiteaFamilyThreadProductState,
               "fetch_util/browser/site_stabilization/gitea_family_thread_product_state"
      autoload :GiteaFamilyThreadTimelineState,
               "fetch_util/browser/site_stabilization/gitea_family_thread_timeline_state"
      autoload :GiteaFamilyThreads, "fetch_util/browser/site_stabilization/gitea_family_threads"
      autoload :GitlabRepo, "fetch_util/browser/site_stabilization/gitlab_repo"
      autoload :GitlabMergeRequestResourceVisibilityScript,
               "fetch_util/browser/site_stabilization/gitlab_merge_request_resource_visibility_script"
      autoload :GitlabMergeRequestResourceStateScript,
               "fetch_util/browser/site_stabilization/gitlab_merge_request_resource_state_script"
      autoload :GitlabMergeRequestResourceState,
               "fetch_util/browser/site_stabilization/gitlab_merge_request_resource_state"
      autoload :GitlabMergeRequestResources, "fetch_util/browser/site_stabilization/gitlab_merge_request_resources"
      autoload :GitlabThreads, "fetch_util/browser/site_stabilization/gitlab_threads"
      autoload :SocialPlatforms, "fetch_util/browser/site_stabilization/social_platforms"
      autoload :TravelAndLodging, "fetch_util/browser/site_stabilization/travel_and_lodging"

      include CommunityAndMarketplace
      include GithubPullResources
      include GithubThreads
      include GiteaFamilyThreadProductState
      include GiteaFamilyThreadTimelineState
      include GiteaFamilyThreads
      include GitlabRepo
      include GitlabMergeRequestResources
      include GitlabThreads
      include SocialPlatforms
      include TravelAndLodging
    end
  end
end
