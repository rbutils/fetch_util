# frozen_string_literal: true

module FetchUtil
  class Browser
    module SiteStabilization
      autoload :EbayStabilization, "fetch_util/browser/site_stabilization/marketplaces/ebay"

      module MarketplaceStabilization
        include EbayStabilization
      end
    end
  end
end
