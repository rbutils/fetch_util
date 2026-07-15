# frozen_string_literal: true

module FetchUtil
  class Browser
    module Stabilization
      autoload :PageFlow, "fetch_util/browser/stabilization/page_flow"
      autoload :SpaHydration, "fetch_util/browser/stabilization/spa_hydration"
      autoload :Anubis, "fetch_util/browser/stabilization/anubis"

      include PageFlow
      include SpaHydration
      include Anubis
    end
  end
end
