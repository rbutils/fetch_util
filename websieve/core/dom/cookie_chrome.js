  function cookieChromeNode(node) {
    if (!node || node.nodeType !== 1) return false;

    var attrs = normalizeText([
      node.getAttribute("id"),
      node.getAttribute("class"),
      node.getAttribute("aria-label"),
      node.getAttribute("data-testid")
    ].join(" ")).toLowerCase();
    var text = normalizeText(node.textContent || "");
    var vendorContainer = /(onetrust|ot-sdk|\bot-[\w-]*|cookiebot|cybot|cookiedeclaration|cookie-declaration|usercentrics|trustarc|didomi|quantcast|osano|cookieyes|cky-|sourcepoint|sp_message|privacy-center|privacy preference center|cookie information|cookie list|consent preferences)/.test(attrs) ||
      node.getAttribute("data-nosnippet") === "true";

    if (vendorContainer) return true;
    if (!text) return false;
    var attrCookieMatch = /(cookie|consent|privacy|gdpr|ccpa)/.test(attrs);
    if (attrCookieMatch && cookieNoticeText(text)) return true;
    if (attrCookieMatch && text.length > 5000 && /(cookie|cookies|consent|privacy|gdpr|ccpa)/i.test(text.slice(0, 2000))) return true;
    if ((node.matches("[role='dialog'], [aria-modal='true'], dialog") || /position:\s*(fixed|sticky)/i.test(node.getAttribute("style") || "")) && cookieNoticeText(text)) return true;
    if (typeof window !== "undefined" && node.ownerDocument && node.ownerDocument.defaultView) {
      try {
        var computed = node.ownerDocument.defaultView.getComputedStyle(node);
        if (computed && /fixed|sticky/.test(computed.position) && cookieNoticeText(text)) return true;
      } catch (e) {}
    }
    if (cookieNoticeText(text) && text.length < 3000 && node.querySelectorAll("button, a, input[type='button'], input[type='submit']").length >= 1) {
      // Policy links alone do not make their containing page a consent notice.
      var noticeClone = node.cloneNode(true);
      noticeClone.querySelectorAll("a, button, input, select, textarea, nav, footer, script, style, noscript, template").forEach(function(el) { el.remove(); });
      var noticeText = normalizeText(noticeClone.textContent || "").toLowerCase();
      if (!textMatchesAnyPattern(noticeText, COOKIE_NOTICE_KEYWORD_PATTERNS)) return false;

      var paragraphCount = node.querySelectorAll("p").length;
      var formControlCount = node.querySelectorAll("button, input, select, textarea").length;
      var leadingText = text.slice(0, Math.max(40, Math.ceil(text.length / 2)));
      var substantiveTrailingNotice = node.tagName !== "BODY" && text.length > 1000 && paragraphCount >= 2 &&
        paragraphCount >= formControlCount && !cookieNoticeText(leadingText);
      if (!substantiveTrailingNotice) return true;
    }

    return false;
  }

  function cleanupCookieChrome(root) {
    if (!root || !root.querySelectorAll) return root;

    root.querySelectorAll("[role='dialog'], [aria-modal='true'], dialog, [id*='cookie' i], [class*='cookie' i], [id*='consent' i], [class*='consent' i], [id*='privacy' i], [class*='privacy' i], [id*='onetrust' i], [class*='onetrust' i], [id^='ot-' i], [class*='ot-' i], [id*='gdpr' i], [class*='gdpr' i], [id*='ccpa' i], [class*='ccpa' i], [class*='CookieConsent' i], [id*='CookieConsent' i], [class*='CookieDeclaration' i], [id*='CookieDeclaration' i], [class*='cookiebar' i], [id*='cookiebar' i], [class*='cookie-banner' i], [id*='cookie-banner' i], [class*='cookie-notice' i], [id*='cookie-notice' i], [class*='privacy-center' i], [id*='privacy-center' i], [data-nosnippet='true'], .cc-banner, .cc-window, #CybotCookiebotDialog, .cky-consent-container, #usercentrics-root, .osano-cm-dialog").forEach(function(el) {
      if (cookieChromeNode(el)) el.remove();
    });

    root.querySelectorAll("section, div, aside, form").forEach(function(el) {
      if (cookieChromeNode(el)) el.remove();
    });

    return root;
  }
