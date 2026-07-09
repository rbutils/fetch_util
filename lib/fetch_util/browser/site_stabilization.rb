# frozen_string_literal: true

module FetchUtil
  class Browser
    module SiteStabilization
      autoload :CommunityAndMarketplace, "fetch_util/browser/site_stabilization/community_and_marketplace"
      autoload :GitlabRepo, "fetch_util/browser/site_stabilization/gitlab_repo"
      autoload :SocialPlatforms, "fetch_util/browser/site_stabilization/social_platforms"
      autoload :TravelAndLodging, "fetch_util/browser/site_stabilization/travel_and_lodging"

      include CommunityAndMarketplace
      include GitlabRepo
      include SocialPlatforms
      include TravelAndLodging
    end
  end
end
