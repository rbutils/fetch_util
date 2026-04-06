# frozen_string_literal: true

module FetchUtil
  class Browser
    module Navigation
      module HeadersAndReadiness
        private

        def default_headers
          {
            "User-Agent" => @user_agent,
            "Accept-Language" => @accept_language
          }
        end

        def page_loaded_enough?(page)
          page.evaluate(<<~JS)
            (() => !!(document && document.body && (document.body.innerText || document.body.textContent || '').trim().length > 0))()
          JS
        rescue Ferrum::JavaScriptError, Ferrum::TimeoutError
          false
        end
      end
    end
  end
end
