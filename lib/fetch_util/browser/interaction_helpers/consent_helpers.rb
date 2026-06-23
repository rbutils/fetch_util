# frozen_string_literal: true

module FetchUtil
  class Browser
    module InteractionHelpers
      # rubocop:disable Metrics/ModuleLength
      module ConsentHelpers
        CONSENT_ACTION_LABELS = [
          "Accept All", "Allow all", "Confirm My Choices", "Save preferences", "Customize Choices",
          "Alle akzeptieren", "Alles akzeptieren", "Alle zulassen",
          "Tout accepter", "Accepter tout", "Autoriser tout",
          "Aceptar todo", "Aceptar todas",
          "Accetta tutto", "Accetta tutti",
          "Aceitar tudo", "Aceitar todos", "Aceitar todos os cookies",
          "Alles accepteren", "Accepteer alles",
          "Godta alle", "Aksepter alle", "Godkjenn alle",
          "Acceptera alla", "Godkänn alla", "Tillåt alla",
          "Accepter alle", "Tillad alle",
          "Hyväksy kaikki", "Salli kaikki",
          "Priimti visus", "Leisti visus",
          "Pieņemt visus", "Atļaut visus",
          "Přijmout vše", "Povolit vše",
          "Zaakceptuj wszystkie", "Akceptuję",
          "Mindent elfogadok", "Összes elfogadása", "Elfogadom",
          "Acceptă tot", "Acceptă toate",
          "Прифати сите", "Прихвати све",
          "すべて受け入れる", "すべて許可",
          "모두 허용", "全部接受"
        ].freeze
        CONSENT_FALLBACK_LABELS = [
          "Essential only", "Reject All",
          "Alle ablehnen", "Tout refuser", "Rechazar todo",
          "Rifiuta tutto", "Rejeitar tudo", "Alles weigeren",
          "Avvis alle", "Avvisa alla", "Afvis alle",
          "Hylkää kaikki", "Atmesti visus", "Noraidīt visus",
          "Odmítnout vše", "Odrzuć wszystkie",
          "Összes elutasítása", "Respinge tot",
          "Одбиј ги сите", "Одбиј све"
        ].freeze
        private_constant :CONSENT_ACTION_LABELS, :CONSENT_FALLBACK_LABELS

        private

        def accept_cookie_consent(page)
          safe_evaluate(page, <<~JS)
            (() => {
              const quickIndicator = document.querySelector(#{consent_quick_indicator_selector_js});
              const bodyPreview = ((document.body && (document.body.textContent || document.body.innerText)) || '')
                .replace(/\s+/g, ' ')
                .trim()
                .slice(0, 4000)
                .toLowerCase();
              const bodyLooksLikeConsent = /(cookie|privacy|consent|personal data|personalized ads|personalized content|vendors want your permission|configurações avançadas de cookies|declaração de cookies|gerenciar cookies|utilizamos cookies|dados pessoais|informasjonskapsler|personvern|kakor|sekretess|samtycke|evästeet|evästeasetukset|tietosuoja|slapukai|slapukų|privatumas|sīkdatnes|sīkfailus|privātums|sütiket|adatvédelem|cookie-uri|confidențialitate|колачиња|приватност)/.test(bodyPreview) &&
                /(accept|reject|manage|allow|agree|consent|cookies|privacy|more options|aceitar|rejeitar|gerenciar|godta|aksepter|godkjenn|godkänn|acceptera|tillåt|hyväksy|salli|priimti|sutinku|leisti|pieņemt|piekrītu|atļaut|elfogad|összes|acceptă|sunt de acord|прифати|се согласувам)/.test(bodyPreview);
              const hasConsentDialog = quickIndicator ||
                document.querySelector('[role="dialog"][aria-modal="true"]') ||
                document.querySelector('dialog') ||
                bodyLooksLikeConsent;
              if (!hasConsentDialog) return false;

              const pattern = /^(accept(?: all(?: cookies?)?)?|allow all(?: cookies)?|allow cookies|agree(?: to cookies| and continue| & continue)?|i agree|ok(?:ay)?|accept & continue|continue with cookies|consent|got it|i understand|continue|accept and close|close|accept recommended settings|przejdź do serwisu|zaakceptuj(?:\s+(?:wszystkie|wszystko))?|akceptuję|zgadzam się|zgoda|akzeptieren|alle akzeptieren|zustimmen|accepter (?:tout|les cookies|et continuer)|tout accepter|j'accepte|accepter|aceptar (?:todo|todas|cookies)|acepto|accetta (?:tutto|tutti)|accetto|aceitar(?:\s+(?:tudo|todos|cookies|todos os cookies))?|aceitar cookies|aceitar todos os cookies|aceitar e continuar|aceitar e fechar|aceito|accetta e continua|akkoord|ga akkoord|alles accepteren|accepteer alles|すべて受け入れる|すべて許可|同意する|同意して閉じる|쿠키 허용|모두 허용|동의하고 계속|동의|接受全部|全部接受|同意并继续|接受并继续|принять все|согласен|согласиться|souhlasím|přijmout vše|přijmout(?:\s+(?:všechny|vše))?|povolit vše|souhlasit|godkänn alla|acceptera alla|tillåt alla|jag godkänner|godkänn|accepter alle|tillad alle|jeg accepterer|acceptér|godta alle|tanggap semua|setuju|terima semua|godkjenn alle|aksepter alle|aksepter|jeg godtar|godta|accepta-ho tot|accepta|accepto|d'acord|razumem|prihvatam|прихватам|прихвати све|qəbul edirəm|ყველას მიღება|සියල්ල පිළිගන්න|පිළිගන්න|همه را بپذیرید|ተቀበል|ሁሉንም ተቀበል|allow all|confirm my choices|pokračovat|hyväksy(?:\s+kaikki)?|salli kaikki|salli evästeet|hyväksyn|priimti visus|sutinku|leisti visus|прифати(?:\s+(?:ги\s+)?сите)?|се согласувам|acceptă(?:\s+tot(?:ul)?)?|accept toate|acceptă toate|sunt de acord|pieņemt(?:\s+visus)?|piekrītu|atļaut(?:\s+visus)?|apstiprināt|elfogad(?:om)?|mindent elfogad(?:ok)?|összes elfogadása|elfogadom az összeset|hozzájárulok)(?:\s+and\s+.*)?$/i;
              const consentPattern = /(cookie|cookies|privacy|consent|gdpr|ccpa|onetrust|before you continue|we use cookies and data|device identifiers|personalized ads|personalized content|trusted third party partners?|privacy preference center|your privacy settings|your privacy choices|manage privacy preferences|manage consent preferences|cookie information|cookie list|cookies details|list of partners(?: \(vendors\))?|configurações avançadas de cookies|declaração de cookies|gerenciar cookies|utilizamos cookies|dados pessoais|pliki cookie|datenschutz|données personnelles|datos personales|dati personali|wish to store|access information on your devices|preferenze cookie|クッキー|Cookieプリファレンス|Cookie設定|同意設定|쿠키|동의|개인정보|接受|隐私设置|cookie 偏好设置|файлы cookie|настройки cookie|souhlas|personalizac|soukromí|nastavení souhlasu|kakor|sekretess|samtycke|cookies og data|privatlivs|samtykke|privatliv|personvern|informasjonskapsler|informasjonskapslar|aller media|dine data|galetes|protecció de dades|política de privadesa|ግላዊነት|ኩኪ|ኩኪዎች|pro pokračování vyberte|technické cookies|jakou formou vám máme zobrazovat obsah|evästeet|evästeasetukset|tietosuoja|yksityisyys|hyväksy evästeet|slapukai|privatumas|slapukų nustatymai|kolačinji|приватност|поставки за колачиња|cookie-uri|confidențialitate|setări cookie|protecția datelor|sīkdatnes|sīkfailus|privātums|privātuma iestatījumi|sīkdatņu iestatījumi|sütiket|adatvédelem|adatvédelmi beállítások|süti beállítások)/i;
              const containerPattern = /(cookie|consent|privacy|onetrust|cookiebot|usercentrics|trustarc|didomi|quantcast|gdpr|ccpa)/i;
              #{js_dom_helpers}
              const parentOrHost = (node) => {
                if (!node) return null;
                if (node.parentElement) return node.parentElement;
                const root = node.getRootNode && node.getRootNode();
                return root && root.host ? root.host : null;
              };
              const candidates = queryAllRoots('button, [role="button"], a, input[type="button"], input[type="submit"]');

              const consentContext = (el) => {
                let node = el;
                for (let depth = 0; node && depth < 8; depth += 1, node = parentOrHost(node)) {
                  const text = textFor(node);
                  const attrs = [node.id, node.className, node.getAttribute('aria-label'), node.getAttribute('data-testid')]
                    .filter(Boolean)
                    .join(' ');
                  if (consentPattern.test(text + ' ' + attrs)) return true;
                }
                return bodyLooksLikeConsent;
              };

              const consentAttrs = (el) => [el.id, el.className, el.getAttribute('aria-label'), el.getAttribute('data-testid')]
                .filter(Boolean)
                .join(' ');

              let clicked = false;
              for (const el of candidates) {
                const text = textFor(el);
                if (!text || !visible(el) || !pattern.test(text) || !consentContext(el)) continue;
                el.click();
                clicked = true;
              }

              if (!clicked) {
                const consentContainerSel = #{consent_container_selector_js};
                for (const container of queryAllRoots(consentContainerSel)) {
                  if (!visible(container)) continue;
                  for (const el of container.querySelectorAll('div, span')) {
                    const text = textFor(el);
                    if (!text || !visible(el) || !pattern.test(text)) continue;
                    if (text.length > 120) continue;
                    el.click();
                    clicked = true;
                  }
                  if (clicked) break;
                }
              }

              for (const el of queryAllRoots('[role="dialog"], [aria-modal="true"], dialog')) {
                const attrs = consentAttrs(el);
                if (!consentContext(el) && !containerPattern.test(attrs)) continue;
                if (!visible(el)) continue;
                el.remove();
                clicked = true;
              }

              const consentOverlaySelector = #{consent_overlay_selector_js};
              for (const el of queryAllRoots(consentOverlaySelector)) {
                if (el.matches('[role="dialog"], [aria-modal="true"], dialog')) continue;
                const style = window.getComputedStyle(el);
                if (!/fixed|sticky/.test(style.position)) continue;
                if (!visible(el)) continue;
                el.remove();
                clicked = true;
              }

              if (clicked) {
                restoreScroll();
              }

              return clicked;
            })()
          JS
        end

        def dismiss_privacy_preference_overlay(page)
          overlay_present = safe_evaluate(page, <<~'JS', default: false)
            (() => {
              if (!document.querySelector(
                "[id*='onetrust' i], [class*='onetrust' i], " +
                "[id*='cookiebot' i], [class*='cookiebot' i], " +
                "[id*='cookie-consent' i], [class*='cookie-consent' i], " +
                "[id*='cookie_consent' i], [class*='cookie_consent' i], " +
                "[id*='cookieconsent' i], [class*='cookieconsent' i], " +
                "[id*='cookie-banner' i], [class*='cookie-banner' i], " +
                "[id*='cookie-notice' i], [class*='cookie-notice' i], " +
                "[id*='privacy-banner' i], [class*='privacy-banner' i], " +
                "[id*='privacy_banner' i], [class*='privacy_banner' i], " +
                "[id*='privacy-preference' i], [class*='privacy-preference' i], " +
                "[id*='gdpr' i], [class*='gdpr' i]"
              )) return false;
              const text = ((document.body && document.body.innerText) || '').toLowerCase()
              if (!text) return false
              if (!/(privacy preference center|your privacy settings|your privacy choices|manage privacy preferences|manage consent preferences|cookie information|cookie list|cookies details|list of partners(?: \(vendors\))?|personverninnstillinger|informasjonskapsler|sekretessinställningar|kakor|evästeasetukset|tietosuoja|slapukų nustatymai|privatumo nustatymai|sīkdatņu iestatījumi|privātuma iestatījumi|adatvédelmi beállítások|süti beállítások|setări cookie|nastavení souhlasu)/i.test(text)) return false
              return true
            })()
          JS
          return false unless overlay_present

          click_visible_button_by_text(
            page,
            CONSENT_ACTION_LABELS,
            CONSENT_FALLBACK_LABELS,
            selectors: 'button, [role="button"], a, input[type="button"], input[type="submit"]'
          )
        end

        def consent_quick_indicator_selector_js
          selector = <<~JS
            [id*="onetrust" i], [class*="onetrust" i],
            [id*="cookiebot" i], [class*="cookiebot" i],
            [id*="usercentrics" i], [class*="usercentrics" i],
            [id*="trustarc" i], [class*="trustarc" i],
            [id*="didomi" i], [class*="didomi" i],
            [id*="quantcast" i], [class*="quantcast" i],
            [id*="cookie-consent" i], [class*="cookie-consent" i],
            [id*="cookie_consent" i], [class*="cookie_consent" i],
            [id*="cookieconsent" i], [class*="cookieconsent" i],
            [id*="cookie-banner" i], [class*="cookie-banner" i],
            [id*="cookie_banner" i], [class*="cookie_banner" i],
            [id*="cookie-notice" i], [class*="cookie-notice" i],
            [id*="gdpr" i], [class*="gdpr" i],
            [id*="ccpa" i], [class*="ccpa" i],
            [id*="privacy-banner" i], [class*="privacy-banner" i],
            [id*="privacy_banner" i], [class*="privacy_banner" i]
          JS
          selector.gsub(/\s+/, " ").strip.inspect
        end

        def consent_container_selector_js
          selector = <<~JS
            [id*="cookie" i], [class*="cookie" i],
            [id*="consent" i], [class*="consent" i],
            [id*="privacy" i], [class*="privacy" i],
            [id*="gdpr" i], [class*="gdpr" i],
            [id*="ccpa" i], [class*="ccpa" i]
          JS
          selector.gsub(/\s+/, " ").strip.inspect
        end

        def consent_overlay_selector_js
          selector = <<~JS
            [id*="cookie" i], [class*="cookie" i],
            [id*="consent" i], [class*="consent" i],
            [id*="privacy" i], [class*="privacy" i],
            [id*="gdpr" i], [class*="gdpr" i],
            [id*="ccpa" i], [class*="ccpa" i],
            [id*="onetrust" i], [class*="onetrust" i],
            [id*="cookiebot" i], [class*="cookiebot" i],
            [id*="usercentrics" i], [class*="usercentrics" i],
            [id*="trustarc" i], [class*="trustarc" i],
            [id*="didomi" i], [class*="didomi" i],
            [id*="quantcast" i]
          JS
          selector.gsub(/\s+/, " ").strip.inspect
        end
      end
      # rubocop:enable Metrics/ModuleLength
    end
  end
end
