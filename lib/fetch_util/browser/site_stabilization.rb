# frozen_string_literal: true

module FetchUtil
  class Browser
    module SiteStabilization
      autoload :CommunityAndMarketplace, "fetch_util/browser/site_stabilization/community_and_marketplace"
      autoload :SocialPlatforms, "fetch_util/browser/site_stabilization/social_platforms"

      include CommunityAndMarketplace
      include SocialPlatforms
    end
  end
end
