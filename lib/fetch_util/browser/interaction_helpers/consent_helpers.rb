# frozen_string_literal: true

module FetchUtil
  class Browser
    module InteractionHelpers
      # rubocop:disable Metrics/ModuleLength
      module ConsentHelpers
        ConsentConfig = Struct.new(
          :accept_labels,
          :fallback_labels,
          :reject_pattern,
          :accept_pattern,
          :close_pattern,
          :context_pattern,
          :container_pattern,
          :known_cmp_selectors,
          :quick_indicator_selectors,
          :container_selectors,
          :overlay_selectors,
          :button_selectors,
          keyword_init: true
        )

        # rubocop:disable Layout/LineLength, Style/RedundantPercentQ
        DEFAULT_CONSENT_CONFIG = ConsentConfig.new(
          accept_labels: [
            "Accept All", "Accept all", "Accept", "Agree", "I agree", "Got it", "OK", "I understand", "Allow all", "Consent",
            "Confirm My Choices", "Save preferences", "Customize Choices",
            "Alle akzeptieren", "Alles akzeptieren", "Alle zulassen", "Akzeptieren", "Zustimmen",
            "Tout accepter", "Accepter tout", "Autoriser tout", "Accepter", "J'accepte",
            "Aceptar todo", "Aceptar todas", "Aceptar", "Estoy de acuerdo",
            "Accetta tutto", "Accetta tutti", "Accetta", "Accetto",
            "Aceitar tudo", "Aceitar todos", "Aceitar todos os cookies", "Aceitar", "Concordo",
            "Alles accepteren", "Accepteer alles",
            "Godta alle", "Aksepter alle", "Godkjenn alle",
            "Acceptera alla", "Godkänn alla", "Tillåt alla",
            "Accepter alle", "Tillad alle",
            "Hyväksy kaikki", "Salli kaikki",
            "Priimti visus", "Leisti visus",
            "Pieņemt visus", "Atļaut visus",
            "Přijmout vše", "Přijmout", "Souhlasím", "Povolit vše",
            "Akceptuj wszystkie", "Zaakceptuj wszystkie", "Akceptuj", "Akceptuję", "Zgadzam się",
            "Mindent elfogadok", "Összes elfogadása", "Elfogad", "Elfogadom", "Egyetértek",
            "Acceptă tot", "Acceptă toate",
            "Прифати сите", "Прихвати све",
            "Tümünü kabul et", "Kabul et", "Kabul ediyorum",
            "Принять все", "Принять", "Согласен",
            "Приеми всички", "Приеми", "Съгласен съм",
            "Terima semua", "Terima", "Setuju",
            "Chấp nhận tất cả", "Chấp nhận", "Đồng ý",
            "ยอมรับทั้งหมด", "ยอมรับ", "ตกลง",
            "すべて受け入れる", "すべて許可", "許可", "同意する",
            "모두 동의", "모두 허용", "동의", "수락",
            "قبول الكل", "موافق", "全部接受"
          ].freeze,
          fallback_labels: [
            "Essential only", "Reject All", "Reject all", "Reject", "Close", "Dismiss",
            "Alle ablehnen", "Ablehnen", "Schließen", "Tout refuser", "Refuser", "Fermer", "Rechazar todo", "Rechazar", "Cerrar",
            "Rifiuta tutto", "Rifiuta tutti", "Rifiuta", "Chiudi", "Rejeitar tudo", "Rejeitar", "Recusar tudo", "Recusar", "Fechar", "Alles weigeren",
            "Avvis alle", "Avvisa alla", "Afvis alle",
            "Hylkää kaikki", "Atmesti visus", "Noraidīt visus",
            "Odmítnout vše", "Odmítnout", "Zavřít", "Odrzuć wszystkie", "Odrzuć", "Zamknij",
            "Összes elutasítása", "Elutasít", "Bezár", "Respinge tot",
            "Одбиј ги сите", "Одбиј све", "Reddet", "Kapat",
            "Отклонить все", "Отклонить", "Закрыть", "Отказ", "Затвори",
            "Tolak", "Tutup", "Từ chối", "Đóng", "ปฏิเสธ", "ปิด", "拒否", "閉じる", "거부", "닫기", "رفض", "إغلاق"
          ].freeze,
          reject_pattern: %q{^(reject(?: all)?|reject optional(?: cookies)?|decline|deny|essential only|necessary only|close|dismiss|alle ablehnen|ablehnen|schließen|tout refuser|refuser|fermer|rechazar(?: todo)?|cerrar|recusar(?: tudo)?|rejeitar(?: tudo)?|fechar|rifiuta(?: tutti| tutto)?|chiudi|odrzuć(?: wszystkie)?|zamknij|odmítnout(?: vše)?|zavřít|reddet|kapat|отклонить(?: все)?|закрыть|отказ|затвори|elutasít|bezár|tolak|tutup|từ chối|đóng|ปฏิเสธ|ปิด|拒否|閉じる|거부|닫기|رفض|إغلاق)$},
          accept_pattern: %q{^(accept(?: all(?: cookies?)?)?|allow all(?: cookies)?|allow cookies|agree(?: to cookies| and continue| & continue)?|i agree|ok(?:ay)?|accept & continue|continue with cookies|consent|got it|i understand|continue|accept and close|accept recommended settings|przejdź do serwisu|zaakceptuj(?:\s+(?:wszystkie|wszystko))?|akceptuj(?: wszystkie)?|akceptuję|zgadzam się|zgoda|akzeptieren|alle akzeptieren|zustimmen|accepter (?:tout|les cookies|et continuer)|tout accepter|j'accepte|accepter|aceptar (?:todo|todas|cookies)|aceptar|estoy de acuerdo|acepto|accetta (?:tutto|tutti)|accetta|accetto|aceitar(?:\s+(?:tudo|todos|cookies|todos os cookies))?|aceitar cookies|aceitar todos os cookies|aceitar e continuar|aceitar e fechar|concordo|aceito|accetta e continua|akkoord|ga akkoord|alles accepteren|accepteer alles|すべて受け入れる|すべて許可|許可|同意する|同意して閉じる|쿠키 허용|모두 동의|모두 허용|동의하고 계속|동의|수락|接受全部|全部接受|同意并继续|接受并继续|принять все|принять|согласен|согласиться|приеми всички|приеми|съгласен съм|souhlasím|přijmout vše|přijmout(?:\s+(?:všechny|vše))?|povolit vše|souhlasit|godkänn alla|acceptera alla|tillåt alla|jag godkänner|godkänn|accepter alle|tillad alle|jeg accepterer|acceptér|godta alle|tanggap semua|setuju|terima semua|godkjenn alle|aksepter alle|aksepter|jeg godtar|godta|accepta-ho tot|accepta|accepto|d'acord|razumem|prihvatam|прихватам|прихвати све|tümünü kabul et|kabul et|kabul ediyorum|qəbul edirəm|ყველას მიღება|සියල්ල පිළිගන්න|පිළිගන්න|همه را بپذیرید|ተቀበል|ሁሉንም ተቀበል|allow all|confirm my choices|pokračovat|hyväksy(?:\s+kaikki)?|salli kaikki|salli evästeet|hyväksyn|priimti visus|sutinku|leisti visus|прифати(?:\s+(?:ги\s+)?сите)?|се согласувам|acceptă(?:\s+tot(?:ul)?)?|accept toate|acceptă toate|sunt de acord|pieņemt(?:\s+visus)?|piekrītu|atļaut(?:\s+visus)?|apstiprināt|elfogad(?:om)?|mindent elfogad(?:ok)?|összes elfogadása|elfogadom az összeset|egyetértek|hozzájárulok|chấp nhận tất cả|chấp nhận|đồng ý|ยอมรับทั้งหมด|ยอมรับ|ตกลง|قبول الكل|موافق)(?:\s+and\s+.*)?$},
          close_pattern: %q{^(close|dismiss|ok(?:ay)?|got it|i understand|schließen|fermer|cerrar|fechar|chiudi|zamknij|zavřít|kapat|закрыть|затвори|bezár|tutup|đóng|ปิด|閉じる|닫기|إغلاق)$},
          context_pattern: %q{(cookie|cookies|privacy|consent|gdpr|ccpa|cmp|onetrust|cookiebot|didomi|quantcast|before you continue|we use cookies and data|device identifiers|personalized ads|personalized content|trusted third party partners?|privacy preference center|your privacy settings|your privacy choices|manage privacy preferences|manage consent preferences|cookie information|cookie list|cookies details|list of partners(?: \(vendors\))?|configurações avançadas de cookies|declaração de cookies|gerenciar cookies|utilizamos cookies|dados pessoais|pliki cookie|datenschutz|données personnelles|datos personales|dati personali|wish to store|access information on your devices|preferenze cookie|クッキー|Cookieプリファレンス|Cookie設定|同意設定|쿠키|동의|개인정보|接受|隐私设置|cookie 偏好设置|файлы cookie|настройки cookie|souhlas|personalizac|soukromí|nastavení souhlasu|kakor|sekretess|samtycke|cookies og data|privatlivs|samtykke|privatliv|personvern|informasjonskapsler|informasjonskapslar|aller media|dine data|galetes|protecció de dades|política de privadesa|ግላዊነት|ኩኪ|ኩኪዎች|pro pokračování vyberte|technické cookies|jakou formou vám máme zobrazovat obsah|evästeet|evästeasetukset|tietosuoja|yksityisyys|hyväksy evästeet|slapukai|privatumas|slapukų nustatymai|kolačinji|приватност|поставки за колачиња|cookie-uri|confidențialitate|setări cookie|protecția datelor|sīkdatnes|sīkfailus|privātums|privātuma iestatījumi|sīkdatņu iestatījumi|sütiket|adatvédelem|adatvédelmi beállítások|süti beállítások|kabul|çerez|gizlilik|лични данни|поверителност|terima|setuju|privasi|ยินยอม|คุกกี้|ความเป็นส่วนตัว)},
          container_pattern: %q{(cookie|consent|privacy|onetrust|cookiebot|usercentrics|trustarc|didomi|quantcast|sourcepoint|sp_message|uniconsent|osano|gdpr|ccpa)},
          known_cmp_selectors: [
            "#onetrust-banner-sdk", "#onetrust-pc-sdk", ".qc-cmp2-container", ".qc-cmp2-summary",
            "#CybotCookiebotDialog", ".cc-window", ".cc_banner", "#cookie-banner", ".cookie-banner",
            "#consent-banner", ".consent-banner", ".fc-consent-root", ".cmp-modal", ".gdpr-banner",
            "#gdpr-consent", ".js-cookies", ".cookie-notice", "#cookieNotice",
            "[id*='sourcepoint']", "[class*='sourcepoint']", "[id*='sp_message']", "[class*='sp_message']",
            "[id*='uniconsent']", "[class*='uniconsent']", "[id*='uni-consent']", "[class*='uni-consent']",
            "[id*='osano']", "[class*='osano']"
          ].freeze,
          quick_indicator_selectors: [
            "#onetrust-banner-sdk", "#onetrust-pc-sdk", ".qc-cmp2-container", ".qc-cmp2-summary",
            "#CybotCookiebotDialog", ".cc-window", ".cc_banner", "#cookie-banner", ".cookie-banner",
            "#consent-banner", ".consent-banner", ".fc-consent-root", ".cmp-modal", ".gdpr-banner",
            "#gdpr-consent", ".js-cookies", ".cookie-notice", "#cookieNotice",
            '[id*="onetrust" i]', '[class*="onetrust" i]', '[id*="cookiebot" i]', '[class*="cookiebot" i]',
            '[id*="usercentrics" i]', '[class*="usercentrics" i]', '[id*="trustarc" i]', '[class*="trustarc" i]',
            '[id*="didomi" i]', '[class*="didomi" i]', '[id*="quantcast" i]', '[class*="quantcast" i]',
            '[id*="sourcepoint" i]', '[class*="sourcepoint" i]', '[id*="sp_message" i]', '[class*="sp_message" i]',
            '[id*="uniconsent" i]', '[class*="uniconsent" i]', '[id*="uni-consent" i]', '[class*="uni-consent" i]',
            '[id*="osano" i]', '[class*="osano" i]',
            '[id*="cookie-consent" i]', '[class*="cookie-consent" i]', '[id*="cookie_consent" i]', '[class*="cookie_consent" i]',
            '[id*="cookieconsent" i]', '[class*="cookieconsent" i]', '[id*="cookie-banner" i]', '[class*="cookie-banner" i]',
            '[id*="cookie_banner" i]', '[class*="cookie_banner" i]', '[id*="cookie-notice" i]', '[class*="cookie-notice" i]',
            '[id*="gdpr" i]', '[class*="gdpr" i]', '[id*="ccpa" i]', '[class*="ccpa" i]',
            '[id*="privacy-banner" i]', '[class*="privacy-banner" i]', '[id*="privacy_banner" i]', '[class*="privacy_banner" i]',
            '[id*="privacy-preference" i]', '[class*="privacy-preference" i]'
          ].freeze,
          container_selectors: [
            "#onetrust-banner-sdk", "#onetrust-pc-sdk", ".qc-cmp2-container", ".qc-cmp2-summary",
            "#CybotCookiebotDialog", ".cc-window", ".cc_banner", "#cookie-banner", ".cookie-banner",
            "#consent-banner", ".consent-banner", ".fc-consent-root", ".cmp-modal", ".gdpr-banner",
            "#gdpr-consent", ".js-cookies", ".cookie-notice", "#cookieNotice",
            '[id*="cookie" i]', '[class*="cookie" i]', '[id*="consent" i]', '[class*="consent" i]',
            '[class*="cookie-banner" i]', '[data-testid*="cookie" i]', '[id*="privacy" i]', '[class*="privacy" i]',
            '[id*="gdpr" i]', '[class*="gdpr" i]', '[id*="ccpa" i]', '[class*="ccpa" i]',
            '[id*="sourcepoint" i]', '[class*="sourcepoint" i]', '[id*="sp_message" i]', '[class*="sp_message" i]',
            '[id*="uniconsent" i]', '[class*="uniconsent" i]', '[id*="uni-consent" i]', '[class*="uni-consent" i]',
            '[id*="osano" i]', '[class*="osano" i]'
          ].freeze,
          overlay_selectors: [
            "#onetrust-banner-sdk", "#onetrust-pc-sdk", ".qc-cmp2-container", ".qc-cmp2-summary",
            "#CybotCookiebotDialog", ".cc-window", ".cc_banner", "#cookie-banner", ".cookie-banner",
            "#consent-banner", ".consent-banner", ".fc-consent-root", ".cmp-modal", ".gdpr-banner",
            "#gdpr-consent", ".js-cookies", ".cookie-notice", "#cookieNotice",
            '[id*="cookie" i]', '[class*="cookie" i]', '[id*="consent" i]', '[class*="consent" i]',
            '[class*="cookie-banner" i]', '[data-testid*="cookie" i]', '[id*="privacy" i]', '[class*="privacy" i]',
            '[id*="gdpr" i]', '[class*="gdpr" i]', '[id*="ccpa" i]', '[class*="ccpa" i]',
            '[id*="onetrust" i]', '[class*="onetrust" i]', '[id*="cookiebot" i]', '[class*="cookiebot" i]',
            '[id*="usercentrics" i]', '[class*="usercentrics" i]', '[id*="trustarc" i]', '[class*="trustarc" i]',
            '[id*="didomi" i]', '[class*="didomi" i]', '[id*="quantcast" i]',
            '[id*="sourcepoint" i]', '[class*="sourcepoint" i]', '[id*="sp_message" i]', '[class*="sp_message" i]',
            '[id*="uniconsent" i]', '[class*="uniconsent" i]', '[id*="uni-consent" i]', '[class*="uni-consent" i]',
            '[id*="osano" i]', '[class*="osano" i]'
          ].freeze,
          button_selectors: 'button, [role="button"], a, input[type="button"], input[type="submit"]'
        ).freeze
        # rubocop:enable Layout/LineLength, Style/RedundantPercentQ
        private_constant :ConsentConfig, :DEFAULT_CONSENT_CONFIG

        private

        def consent_config(accept_labels: nil, fallback_labels: nil, extra_accept_labels: [], extra_fallback_labels: [],
                           button_selectors: nil)
          ConsentConfig.new(
            **DEFAULT_CONSENT_CONFIG.to_h,
            accept_labels: Array(accept_labels || DEFAULT_CONSENT_CONFIG.accept_labels).dup.concat(Array(extra_accept_labels)).freeze,
            fallback_labels: Array(fallback_labels || DEFAULT_CONSENT_CONFIG.fallback_labels).dup.concat(Array(extra_fallback_labels)).freeze,
            button_selectors: button_selectors || DEFAULT_CONSENT_CONFIG.button_selectors
          ).freeze
        end

        def consent_accept_labels(config = DEFAULT_CONSENT_CONFIG)
          config.accept_labels
        end

        def consent_fallback_labels(config = DEFAULT_CONSENT_CONFIG)
          config.fallback_labels
        end

        def consent_button_selectors(config = DEFAULT_CONSENT_CONFIG)
          config.button_selectors
        end

        def consent_js_patterns(config = DEFAULT_CONSENT_CONFIG)
          <<~JS
            const rejectPattern = new RegExp(#{JSON.generate(config.reject_pattern)}, 'i');
            const acceptPattern = new RegExp(#{JSON.generate(config.accept_pattern)}, 'i');
            const closePattern = new RegExp(#{JSON.generate(config.close_pattern)}, 'i');
            const consentPattern = new RegExp(#{JSON.generate(config.context_pattern)}, 'i');
            const containerPattern = new RegExp(#{JSON.generate(config.container_pattern)}, 'i');
          JS
        end

        def consent_selector_js(selectors)
          Array(selectors).join(", ").inspect
        end

        def consent_known_cmp_selector_js(config = DEFAULT_CONSENT_CONFIG)
          consent_selector_js(config.known_cmp_selectors)
        end

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

              #{consent_js_patterns}
              const knownCmpSelector = #{consent_known_cmp_selector_js};
              #{js_dom_helpers}
              const parentOrHost = (node) => {
                if (!node) return null;
                if (node.parentElement) return node.parentElement;
                const root = node.getRootNode && node.getRootNode();
                return root && root.host ? root.host : null;
              };
              const candidates = queryAllRoots(#{consent_button_selectors.inspect});

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

              const clickFirst = (buttons, buttonPattern) => {
                for (const el of buttons) {
                  const text = textFor(el);
                  if (!text || text.length > 120 || !visible(el) || !buttonPattern.test(text) || !consentContext(el)) continue;
                  el.click();
                  return true;
                }
                return false;
              };

              let clicked = clickFirst(candidates, rejectPattern) || clickFirst(candidates, acceptPattern) || clickFirst(candidates, closePattern);

              if (!clicked) {
                const consentContainerSel = #{consent_container_selector_js};
                for (const container of queryAllRoots(consentContainerSel)) {
                  if (!visible(container)) continue;
                  for (const el of container.querySelectorAll('div, span')) {
                    const text = textFor(el);
                    if (!text || !visible(el) || !(rejectPattern.test(text) || acceptPattern.test(text) || closePattern.test(text))) continue;
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
                if (!el.matches(knownCmpSelector) && !/fixed|sticky/.test(style.position)) continue;
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
          overlay_present = safe_evaluate(page, <<~JS, default: false)
            (() => {
              if (!document.querySelector(#{consent_quick_indicator_selector_js})) return false;
              const text = ((document.body && document.body.innerText) || '').toLowerCase()
              if (!text) return false
              if (!/(privacy preference center|your privacy settings|your privacy choices|manage privacy preferences|manage consent preferences|cookie information|cookie list|cookies details|list of partners(?: \(vendors\))?|personverninnstillinger|informasjonskapsler|sekretessinställningar|kakor|evästeasetukset|tietosuoja|slapukų nustatymai|privatumo nustatymai|sīkdatņu iestatījumi|privātuma iestatījumi|adatvédelmi beállítások|süti beállítások|setări cookie|nastavení souhlasu)/i.test(text)) return false
              return true
            })()
          JS
          return false unless overlay_present

          click_visible_button_by_text(
            page,
            consent_accept_labels,
            consent_fallback_labels,
            selectors: consent_button_selectors
          )
        end

        def consent_quick_indicator_selector_js
          consent_selector_js(DEFAULT_CONSENT_CONFIG.quick_indicator_selectors)
        end

        def consent_container_selector_js
          consent_selector_js(DEFAULT_CONSENT_CONFIG.container_selectors)
        end

        def consent_overlay_selector_js
          consent_selector_js(DEFAULT_CONSENT_CONFIG.overlay_selectors)
        end
      end
      # rubocop:enable Metrics/ModuleLength
    end
  end
end
