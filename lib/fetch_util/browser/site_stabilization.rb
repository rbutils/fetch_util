# frozen_string_literal: true

module FetchUtil
  class Browser
    module SiteStabilization
      autoload :CommunityStabilization, 'fetch_util/browser/site_stabilization/communities'
      autoload :FacebookStabilization, "fetch_util/browser/site_stabilization/facebook_stabilization"
      autoload :ForgeStabilization, "fetch_util/browser/site_stabilization/forges"
      autoload :MarketplaceStabilization, 'fetch_util/browser/site_stabilization/marketplaces'
      autoload :SocialPlatforms, "fetch_util/browser/site_stabilization/social_platforms"
      autoload :TravelAndLodging, "fetch_util/browser/site_stabilization/travel_and_lodging"

      include CommunityStabilization
      include FacebookStabilization
      include ForgeStabilization
      include MarketplaceStabilization
      include SocialPlatforms
      include TravelAndLodging
    end
  end
end
