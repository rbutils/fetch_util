# frozen_string_literal: true

module FetchUtil
  class Browser
    module Stabilization
      module Anubis
        ANUBIS_POLL = 0.25

        private

        def wait_for_anubis_challenge(page)
          deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + @timeout
          state = anubis_page_state(page)
          if !valid_anubis_state?(state) && Process.clock_gettime(Process::CLOCK_MONOTONIC) < deadline
            state = anubis_page_state(page)
          end
          return false unless valid_anubis_state?(state) && state["challenge"] == true

          remaining = deadline - Process.clock_gettime(Process::CLOCK_MONOTONIC)
          return false unless remaining.positive?

          retry_until_timeout(remaining, interval: ANUBIS_POLL) do
            state = anubis_page_state(page)
            next false unless valid_anubis_state?(state)
            next false unless state["challenge"] == false

            state["document_ready"] == true && state["body_present"] == true && state["body_text_present"] == true
          end
        end

        def valid_anubis_state?(state)
          state.is_a?(Hash) &&
            [true, false].include?(state["challenge"]) &&
            [true, false].include?(state["document_ready"]) &&
            [true, false].include?(state["body_present"]) &&
            [true, false].include?(state["body_text_present"]) &&
            state["url"].is_a?(String) && !state["url"].empty?
        end

        def anubis_page_state(page)
          safe_evaluate(page, <<~JS, default: {})
            (() => {
              const body = document.body;
              const bodyText = body ? (body.innerText || '').replace(/\s+/g, ' ').trim() : '';
              const anubisRoot = document.querySelector('#anubis_challenge');
              const anubisScript = document.querySelector('script[src*="/.within.website/x/cmd/anubis/"]');
              const visibleRoot = anubisRoot && (() => {
                const style = window.getComputedStyle(anubisRoot);
                const rect = anubisRoot.getBoundingClientRect();
                return style.display !== 'none' && style.visibility !== 'hidden' && rect.width > 0 && rect.height > 0;
              })();
              const makingSure = /making sure you're not a bot/i.test((document.title || '') + ' ' + bodyText);
              const protectedChallenge = /protected by anubis/i.test(bodyText) &&
                /(enable javascript to get past this challenge|please wait a moment while we ensure the security of your connection|loading|calculating|challenge:\s*anubis)/i.test(bodyText);
              const challenge = Boolean((visibleRoot || anubisScript) && (makingSure || protectedChallenge));
              return {
                challenge,
                document_ready: document.readyState === 'complete',
                body_present: Boolean(body),
                body_text_present: bodyText.length > 0,
                url: location.href
              };
            })()
          JS
        end
      end
    end
  end
end
