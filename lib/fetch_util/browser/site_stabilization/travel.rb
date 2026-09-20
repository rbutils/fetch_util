# frozen_string_literal: true

module FetchUtil
  class Browser
    module SiteStabilization
      autoload :LodgingStabilization, "fetch_util/browser/site_stabilization/travel/lodging"

      module TravelStabilization
        include LodgingStabilization
      end
    end
  end
end
