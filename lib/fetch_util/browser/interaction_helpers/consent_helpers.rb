# frozen_string_literal: true

module FetchUtil
  class Browser
    module InteractionHelpers
      # rubocop:disable Metrics/ModuleLength
      module ConsentHelpers
        private

        def accept_cookie_consent(page)
          safe_evaluate(page, <<~JS)
            (() => {
              // Fast pre-check: skip expensive DOM scan when no consent indicators exist.
              // On large pages (e.g. 89K DOM elements), the full scan can take 90+ seconds
              // due to innerText calls on huge parent containers forcing layout reflows.
              // Only check CMP-specific selectors, not generic patterns like
              // [id*="consent" i] which false-positive on API docs with "consent"
              // in operation IDs (e.g. Allegro's /allegro-prices-offer-consents).
              const quickIndicator = document.querySelector(
                '[id*="onetrust" i], [class*="onetrust" i], ' +
                '[id*="cookiebot" i], [class*="cookiebot" i], ' +
                '[id*="usercentrics" i], [class*="usercentrics" i], ' +
                '[id*="trustarc" i], [class*="trustarc" i], ' +
                '[id*="didomi" i], [class*="didomi" i], ' +
                '[id*="quantcast" i], [class*="quantcast" i], ' +
                '[id*="cookie-consent" i], [class*="cookie-consent" i], ' +
                '[id*="cookie_consent" i], [class*="cookie_consent" i], ' +
                '[id*="cookieconsent" i], [class*="cookieconsent" i], ' +
                '[id*="cookie-banner" i], [class*="cookie-banner" i], ' +
                '[id*="cookie_banner" i], [class*="cookie_banner" i], ' +
                '[id*="cookie-notice" i], [class*="cookie-notice" i], ' +
                '[id*="gdpr" i], [class*="gdpr" i], ' +
                '[id*="ccpa" i], [class*="ccpa" i], ' +
                '[id*="privacy-banner" i], [class*="privacy-banner" i], ' +
                '[id*="privacy_banner" i], [class*="privacy_banner" i]'
              );
              const bodyPreview = ((document.body && (document.body.textContent || document.body.innerText)) || '')
                .replace(/\s+/g, ' ')
                .trim()
                .slice(0, 4000)
                .toLowerCase();
              const bodyLooksLikeConsent = /(cookie|privacy|consent|personal data|vendors want your permission|configurações avançadas de cookies|declaração de cookies|gerenciar cookies|utilizamos cookies|dados pessoais|informasjonskapsler|personvern|kakor|sekretess|samtycke|evästeet|evästeasetukset|tietosuoja|slapukai|slapukų|privatumas|sīkdatnes|sīkfailus|privātums|sütiket|adatvédelem|cookie-uri|confidențialitate|колачиња|приватност)/.test(bodyPreview) &&
                /(accept|reject|manage|allow|agree|consent|cookies|privacy|aceitar|rejeitar|gerenciar|godta|aksepter|godkjenn|godkänn|acceptera|tillåt|hyväksy|salli|priimti|sutinku|leisti|pieņemt|piekrītu|atļaut|elfogad|összes|acceptă|sunt de acord|прифати|се согласувам)/.test(bodyPreview);
              const hasConsentDialog = quickIndicator ||
                document.querySelector('[role="dialog"][aria-modal="true"]') ||
                document.querySelector('dialog') ||
                bodyLooksLikeConsent;
              if (!hasConsentDialog) return false;

              const pattern = /^(accept(?: all(?: cookies?)?)?|allow all(?: cookies)?|allow cookies|agree(?: to cookies| and continue| & continue)?|i agree|ok(?:ay)?|accept & continue|continue with cookies|consent|got it|i understand|continue|accept and close|close|accept recommended settings|przejdź do serwisu|zaakceptuj(?:\s+(?:wszystkie|wszystko))?|akceptuję|zgadzam się|zgoda|akzeptieren|alle akzeptieren|zustimmen|accepter (?:tout|les cookies|et continuer)|tout accepter|j'accepte|accepter|aceptar (?:todo|todas|cookies)|acepto|accetta (?:tutto|tutti)|accetto|aceitar(?:\s+(?:tudo|todos|cookies|todos os cookies))?|aceitar cookies|aceitar todos os cookies|aceitar e continuar|aceitar e fechar|aceito|accetta e continua|akkoord|ga akkoord|alles accepteren|accepteer alles|すべて受け入れる|すべて許可|同意する|同意して閉じる|쿠키 허용|모두 허용|동의하고 계속|동의|接受全部|全部接受|同意并继续|接受并继续|принять все|согласен|согласиться|souhlasím|přijmout vše|přijmout(?:\s+(?:všechny|vše))?|povolit vše|souhlasit|godkänn alla|acceptera alla|tillåt alla|jag godkänner|godkänn|accepter alle|tillad alle|jeg accepterer|acceptér|godta alle|tanggap semua|setuju|terima semua|godkjenn alle|aksepter alle|aksepter|jeg godtar|godta|accepta-ho tot|accepta|accepto|d'acord|razumem|prihvatam|прихватам|прихвати све|qəbul edirəm|ყველას მიღება|සියල්ල පිළිගන්න|පිළිගන්න|همه را بپذیرید|ተቀበል|ሁሉንም ተቀበል|allow all|confirm my choices|pokračovat|hyväksy(?:\s+kaikki)?|salli kaikki|salli evästeet|hyväksyn|priimti visus|sutinku|leisti visus|прифати(?:\s+(?:ги\s+)?сите)?|се согласувам|acceptă(?:\s+tot(?:ul)?)?|accept toate|acceptă toate|sunt de acord|pieņemt(?:\s+visus)?|piekrītu|atļaut(?:\s+visus)?|apstiprināt|elfogad(?:om)?|mindent elfogad(?:ok)?|összes elfogadása|elfogadom az összeset|hozzájárulok)(?:\s+and\s+.*)?$/i;
              const consentPattern = /(cookie|cookies|privacy|consent|gdpr|ccpa|onetrust|before you continue|device identifiers|personalized ads|trusted third party partners?|privacy preference center|your privacy settings|your privacy choices|manage privacy preferences|manage consent preferences|cookie information|cookie list|cookies details|list of partners(?: \(vendors\))?|configurações avançadas de cookies|declaração de cookies|gerenciar cookies|utilizamos cookies|dados pessoais|pliki cookie|datenschutz|données personnelles|datos personales|dati personali|wish to store|access information on your devices|preferenze cookie|クッキー|Cookieプリファレンス|Cookie設定|同意設定|쿠키|동의|개인정보|接受|隐私设置|cookie 偏好设置|файлы cookie|настройки cookie|souhlas|personalizac|soukromí|nastavení souhlasu|kakor|sekretess|samtycke|cookies og data|privatlivs|samtykke|privatliv|personvern|informasjonskapsler|informasjonskapslar|aller media|dine data|galetes|protecció de dades|política de privadesa|ግላዊነት|ኩኪ|ኩኪዎች|pro pokračování vyberte|technické cookies|jakou formou vám máme zobrazovat obsah|evästeet|evästeasetukset|tietosuoja|yksityisyys|hyväksy evästeet|slapukai|privatumas|slapukų nustatymai|kolačinji|приватност|поставки за колачиња|cookie-uri|confidențialitate|setări cookie|protecția datelor|sīkdatnes|sīkfailus|privātums|privātuma iestatījumi|sīkdatņu iestatījumi|sütiket|adatvédelem|adatvédelmi beállítások|süti beállítások)/i;
              const containerPattern = /(cookie|consent|privacy|onetrust|cookiebot|usercentrics|trustarc|didomi|quantcast|gdpr|ccpa)/i;
              const queryAllRoots = (selectors) => {
                const matches = [];
                const queue = [document];
                while (queue.length) {
                  const root = queue.shift();
                  if (!root || !root.querySelectorAll) continue;
                  root.querySelectorAll(selectors).forEach((el) => matches.push(el));
                  root.querySelectorAll('*').forEach((el) => {
                    if (el.shadowRoot) queue.push(el.shadowRoot);
                  });
                }
                return matches;
              };
              const parentOrHost = (node) => {
                if (!node) return null;
                if (node.parentElement) return node.parentElement;
                const root = node.getRootNode && node.getRootNode();
                return root && root.host ? root.host : null;
              };
              const candidates = queryAllRoots('button, [role="button"], a, input[type="button"], input[type="submit"]');

              const visible = (el) => {
                const rect = el.getBoundingClientRect();
                const style = window.getComputedStyle(el);
                return rect.width > 0 && rect.height > 0 && style.visibility !== 'hidden' && style.display !== 'none';
              };

              const textFor = (el) => {
                const values = [el.innerText, el.textContent, el.value, el.getAttribute('aria-label'), el.getAttribute('title')]
                  .filter(Boolean)
                  .map((value) => value.replace(/\s+/g, ' ').trim())
                  .filter(Boolean);
                return values[0] || '';
              };

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

              // Fallback: some sites use bare <div> or <span> as consent buttons without
              // role="button" (e.g. TVP Info's div.tvp-covl__ab). Scan only inside known
              // consent overlay containers to keep the search scoped and fast.
              if (!clicked) {
                const consentContainerSel =
                  '[id*="cookie" i], [class*="cookie" i], ' +
                  '[id*="consent" i], [class*="consent" i], ' +
                  '[id*="privacy" i], [class*="privacy" i], ' +
                  '[id*="gdpr" i], [class*="gdpr" i], ' +
                  '[id*="ccpa" i], [class*="ccpa" i]';
                for (const container of queryAllRoots(consentContainerSel)) {
                  if (!visible(container)) continue;
                  for (const el of container.querySelectorAll('div, span')) {
                    const text = textFor(el);
                    if (!text || !visible(el) || !pattern.test(text)) continue;
                    // Avoid clicking large containers — accept buttons have short text.
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

              const consentOverlaySelector =
                '[id*="cookie" i], [class*="cookie" i], ' +
                '[id*="consent" i], [class*="consent" i], ' +
                '[id*="privacy" i], [class*="privacy" i], ' +
                '[id*="gdpr" i], [class*="gdpr" i], ' +
                '[id*="ccpa" i], [class*="ccpa" i], ' +
                '[id*="onetrust" i], [class*="onetrust" i], ' +
                '[id*="cookiebot" i], [class*="cookiebot" i], ' +
                '[id*="usercentrics" i], [class*="usercentrics" i], ' +
                '[id*="trustarc" i], [class*="trustarc" i], ' +
                '[id*="didomi" i], [class*="didomi" i], ' +
                '[id*="quantcast" i], [class*="quantcast" i]';
              for (const el of queryAllRoots(consentOverlaySelector)) {
                if (el.matches('[role="dialog"], [aria-modal="true"], dialog')) continue;
                const style = window.getComputedStyle(el);
                if (!/fixed|sticky/.test(style.position)) continue;
                if (!visible(el)) continue;
                el.remove();
                clicked = true;
              }

              if (clicked) {
                if (document.body) document.body.style.overflow = 'auto';
                if (document.documentElement) document.documentElement.style.overflow = 'auto';
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
            [
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
            ],
            [
              "Essential only", "Reject All",
              "Alle ablehnen", "Tout refuser", "Rechazar todo",
              "Rifiuta tutto", "Rejeitar tudo", "Alles weigeren",
              "Avvis alle", "Avvisa alla", "Afvis alle",
              "Hylkää kaikki", "Atmesti visus", "Noraidīt visus",
              "Odmítnout vše", "Odrzuć wszystkie",
              "Összes elutasítása", "Respinge tot",
              "Одбиј ги сите", "Одбиј све"
            ],
            selectors: 'button, [role="button"], a, input[type="button"], input[type="submit"]'
          )
        end
      end
      # rubocop:enable Metrics/ModuleLength
    end
  end
end
