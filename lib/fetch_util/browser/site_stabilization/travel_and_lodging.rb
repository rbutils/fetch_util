# frozen_string_literal: true

module FetchUtil
  class Browser
    module SiteStabilization
      module TravelAndLodging
        TRAVEL_LODGING_STABILIZATION_PROFILES = {
          stabilize_lodging_detail: {
            host: %w[airbnb.com booking.com],
            path_query: ->(uri) { uri.path.match?(%r{/(?:rooms|hotel)/}) },
            strategy: :stabilize_lodging_detail,
            notes: "Wait for client-rendered lodging detail cues without bypassing access controls.",
            tests: "spec/fetch_util/browser_stabilization_spec.rb"
          }
        }.freeze

        private

        def stabilize_lodging_detail(page)
          accepted_cookies = accept_cookie_consent(page)
          accepted_cookies = dismiss_privacy_preference_overlay(page) || accepted_cookies

          retry_until_timeout(capped_timeout(8.0), interval: 0.25) do
            safe_evaluate(page, <<~JS, default: false)
              (() => {
                const bodyText = document.body ? (document.body.innerText || '') : '';
                const structuredLodging = Array.from(document.querySelectorAll('script[type="application/ld+json"]')).some((script) => /LodgingBusiness|LodgingReservation|Hotel|VacationRental|Accommodation/i.test(script.textContent || ''));
                if (structuredLodging) return true;
                if (document.querySelector('[data-testid*="amenity" i], [data-testid*="facility" i], [data-testid*="review-score" i], [data-testid="property-description"], [itemprop="address"]')) return true;
                return /amenities|facilities|guest reviews|property highlights|hosted by|check-in|check-out/i.test(bodyText) && bodyText.length > 900;
              })()
            JS
          end

          settle_after_stabilization(0.25) if accepted_cookies
        end
      end
    end
  end
end
