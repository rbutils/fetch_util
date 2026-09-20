# frozen_string_literal: true

module FetchUtil
  class Browser
    module SiteStabilization
      autoload :RedditStabilization, "fetch_util/browser/site_stabilization/communities/reddit"

      module CommunityStabilization
        include RedditStabilization
      end
    end
  end
end
