# frozen_string_literal: true

module FetchUtil
  class Browser
    module SiteStabilization
      autoload :CommunityStabilization, "fetch_util/browser/site_stabilization/communities"
      autoload :ForgeStabilization, "fetch_util/browser/site_stabilization/forges"
      autoload :MarketplaceStabilization, "fetch_util/browser/site_stabilization/marketplaces"
      autoload :SocialStabilization, "fetch_util/browser/site_stabilization/social"
      autoload :TravelAndLodging, "fetch_util/browser/site_stabilization/travel_and_lodging"

      include CommunityStabilization
      include ForgeStabilization
      include MarketplaceStabilization
      include SocialStabilization
      include TravelAndLodging
    end
  end
end
