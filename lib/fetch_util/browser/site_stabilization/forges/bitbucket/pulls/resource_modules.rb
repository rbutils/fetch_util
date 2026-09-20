# frozen_string_literal: true

module FetchUtil
  class Browser
    module SiteStabilization
      autoload :BitbucketCloudPullDiffProductState,
               "fetch_util/browser/site_stabilization/forges/bitbucket/pulls/diff/product_state"
      autoload :BitbucketCloudPullDiffRequestState,
               "fetch_util/browser/site_stabilization/forges/bitbucket/pulls/diff/request_state"
      autoload :BitbucketCloudPullDiffState,
               "fetch_util/browser/site_stabilization/forges/bitbucket/pulls/diff/state"
      autoload :BitbucketCloudPullResourceState,
               "fetch_util/browser/site_stabilization/forges/bitbucket/pulls/resource_state"
      autoload :BitbucketCloudPullResources,
               "fetch_util/browser/site_stabilization/forges/bitbucket/pulls/resources"

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
