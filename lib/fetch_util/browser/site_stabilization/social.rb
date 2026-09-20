# frozen_string_literal: true

module FetchUtil
  class Browser
    module SiteStabilization
      autoload :FacebookStabilization, "fetch_util/browser/site_stabilization/social/facebook"
      autoload :InstagramStabilization, "fetch_util/browser/site_stabilization/social/instagram"

      module SocialStabilization
        include FacebookStabilization
        include InstagramStabilization
      end
    end
  end
end
