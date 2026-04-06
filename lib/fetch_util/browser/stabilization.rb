# frozen_string_literal: true

module FetchUtil
  class Browser
    module Stabilization
      autoload :PageFlow, "fetch_util/browser/stabilization/page_flow"
      autoload :SpaHydration, "fetch_util/browser/stabilization/spa_hydration"

      include PageFlow
      include SpaHydration
    end
  end
end
