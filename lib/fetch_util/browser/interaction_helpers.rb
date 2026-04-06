# frozen_string_literal: true

module FetchUtil
  class Browser
    module InteractionHelpers
      autoload :ConsentHelpers, "fetch_util/browser/interaction_helpers/consent_helpers"
      autoload :DomInteraction, "fetch_util/browser/interaction_helpers/dom_interaction"
      autoload :TimingHelpers, "fetch_util/browser/interaction_helpers/timing_helpers"

      include ConsentHelpers
      include DomInteraction
      include TimingHelpers
    end
  end
end
