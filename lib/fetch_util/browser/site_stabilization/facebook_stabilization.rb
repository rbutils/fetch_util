# frozen_string_literal: true

module FetchUtil
  class Browser
    module SiteStabilization
      module FacebookStabilization
        private

        def stabilize_facebook(page, deadline: stabilization_deadline)
          wait_for_idle_or_content(page, deadline: deadline) if @wait_for_idle
          return false unless stabilization_time_remaining?(deadline)

          social_login_phase_pause(deadline: deadline)
          return false unless stabilization_time_remaining?(deadline)

          dismiss_facebook_cookie_dialog(page)
          return false unless stabilization_time_remaining?(deadline)

          social_login_phase_pause(deadline: deadline)
          return false unless stabilization_time_remaining?(deadline)

          retry_until_timeout(capped_timeout(5.0, deadline: deadline), deadline: deadline) do
            dismiss_facebook_login_dialog(page)
          end
          return false unless stabilization_time_remaining?(deadline)

          social_login_phase_pause(deadline: deadline)
        end

        def dismiss_facebook_cookie_dialog(page)
          config = consent_config(
            accept_labels: ["decline optional cookies", "optionale cookies ablehnen", "refuser les cookies optionnels",
                            "rechazar cookies opcionales", "rifiuta i cookie opzionali"],
            fallback_labels: ["allow all cookies", "alle cookies erlauben", "autoriser tous les cookies", "permitir todas las cookies", "consenti tutti i cookie"]
          )

          click_visible_button_by_text(
            page,
            consent_accept_labels(config),
            consent_fallback_labels(config),
            selectors: consent_button_selectors(config)
          )
        end

        def dismiss_facebook_login_dialog(page)
          dismiss_overlay_dialog(
            page,
            close_selectors: ['[aria-label="Close"]', '[aria-label="close"]'],
            dialog_selectors: ['[role="dialog"]', '[aria-modal="true"]'],
            dialog_pattern: "log in|sign up|create (?:new )?account|see more from"
          )
        end
      end
    end
  end
end
