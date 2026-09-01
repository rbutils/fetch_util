# frozen_string_literal: true

module FetchUtil
  class Browser
    module SiteStabilization
      autoload :BitbucketCloudPullDiffProductState,
               "fetch_util/browser/site_stabilization/bitbucket_cloud_pull_diff_product_state"
      autoload :BitbucketCloudPullDiffRequestState,
               "fetch_util/browser/site_stabilization/bitbucket_cloud_pull_diff_request_state"
      autoload :BitbucketCloudPullDiffState,
               "fetch_util/browser/site_stabilization/bitbucket_cloud_pull_diff_state"
      autoload :BitbucketCloudPullResourceState,
               "fetch_util/browser/site_stabilization/bitbucket_cloud_pull_resource_state"
      autoload :BitbucketCloudPullResources,
               "fetch_util/browser/site_stabilization/bitbucket_cloud_pull_resources"

      module BitbucketCloudPullResourceModules
        include BitbucketCloudPullDiffProductState
        include BitbucketCloudPullDiffRequestState
        include BitbucketCloudPullDiffState
        include BitbucketCloudPullResourceState
        include BitbucketCloudPullResources
      end
    end
  end
end
