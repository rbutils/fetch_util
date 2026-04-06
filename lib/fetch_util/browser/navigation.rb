# frozen_string_literal: true

module FetchUtil
  class Browser
    module Navigation
      autoload :HeadersAndReadiness, "fetch_util/browser/navigation/headers_and_readiness"
      autoload :NavigatorPatch, "fetch_util/browser/navigation/navigator_patch"

      include HeadersAndReadiness
      include NavigatorPatch
    end
  end
end
