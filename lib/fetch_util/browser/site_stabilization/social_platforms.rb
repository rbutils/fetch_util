# frozen_string_literal: true

module FetchUtil
  class Browser
    module SiteStabilization
      module SocialPlatforms
        private

        def instagram_url?(url)
          host = URI.parse(url).host.to_s.downcase
          host == "instagram.com" || host.end_with?(".instagram.com")
        rescue URI::InvalidURIError
          false
        end

        def stabilize_instagram(page)
          wait_for_idle_or_content(page) if @wait_for_idle
          accept_instagram_cookie_dialog(page) || accept_cookie_consent(page)
          social_login_phase_pause
          accept_instagram_cookie_dialog(page) || accept_cookie_consent(page)
          retry_until_timeout(capped_timeout(5.0)) { dismiss_instagram_login_modal(page) }
          social_login_phase_pause
          dismiss_instagram_login_modal(page)
        end

        def accept_instagram_cookie_dialog(page)
          click_visible_button_by_text(
            page,
            ["accept", "accept all", "accept all cookies"],
            ["allow all cookies", "allow all", "allow cookies"],
            selectors: 'button, [role="button"], a, input[type="button"], input[type="submit"]'
          )
        end

        def dismiss_instagram_login_modal(page)
          dismiss_overlay_dialog(
            page,
            close_selectors: [
              '[role="dialog"] button',
              '[role="dialog"] [role="button"]',
              '[role="dialog"] button[aria-label]',
              '[role="dialog"] button[title]',
              '[role="dialog"] button svg',
              '[role="presentation"] button',
              '[role="presentation"] [role="button"]',
              '[role="presentation"] button[aria-label]',
              '[role="presentation"] button[title]',
              '[role="presentation"] button svg',
              '[aria-modal="true"] button',
              '[aria-modal="true"] [role="button"]',
              '[aria-modal="true"] button[aria-label]',
              '[aria-modal="true"] button[title]',
              '[aria-modal="true"] button svg',
              'div[style*="position: fixed"] button',
              'div[style*="position:fixed"] button',
              'div[style*="position: fixed"] [role="button"]',
              'div[style*="position:fixed"] [role="button"]',
              'div[style*="position: fixed"] svg',
              'div[style*="position:fixed"] svg'
            ],
            dialog_selectors: ['[role="dialog"]', '[role="presentation"]', '[aria-modal="true"]'],
            overlay_selectors: ['div[style*="position: fixed"]', 'div[style*="position:fixed"]'],
            dialog_pattern: "log in|sign up|create (?:new )?account|don.?t have an account",
            close_label_pattern: "^(?:close|dismiss|x|×)?$",
            allow_empty_close_label: true
          )
        end

        def facebook_url?(url)
          host = URI.parse(url).host.to_s.downcase
          host == "facebook.com" || host.end_with?(".facebook.com")
        rescue URI::InvalidURIError
          false
        end

        def stabilize_facebook(page)
          wait_for_idle_or_content(page) if @wait_for_idle
          social_login_phase_pause
          dismiss_facebook_cookie_dialog(page)
          social_login_phase_pause
          retry_until_timeout(capped_timeout(5.0)) { dismiss_facebook_login_dialog(page) }
          social_login_phase_pause
        end

        def dismiss_facebook_cookie_dialog(page)
          click_visible_button_by_text(
            page,
            [
              "decline optional cookies",
              "optionale cookies ablehnen",
              "refuser les cookies optionnels",
              "rechazar cookies opcionales",
              "rifiuta i cookie opzionali"
            ],
            [
              "allow all cookies",
              "alle cookies erlauben",
              "autoriser tous les cookies",
              "permitir todas las cookies",
              "consenti tutti i cookie"
            ]
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
