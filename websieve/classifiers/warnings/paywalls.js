  function consentWallDominates(text) {
    var normalized = normalizeText(text || "").toLowerCase();
    if (!normalized) return false;

    var cookiePattern = consentKeywordPattern("i");
    if (!cookiePattern.test(normalized)) return false;

    if (consentKeywordLeadPattern("i").test(normalized)) return true;

    var hits = normalized.match(consentKeywordPattern("gi")) || [];
    if (normalized.length < 5000 && hits.length >= 3) return true;
    // For longer text, check if consent keywords dominate: >= 0.4 hits per 500 chars
    if (hits.length >= 8 && (hits.length / (normalized.length / 500)) >= 0.4) return true;
    return false;
  }

  function shortConsentPrivacyFragment(text) {
    var normalized = normalizeText(text || "").toLowerCase();
    if (!normalized || normalized.length > 220) return false;

    return /^(?:do not sell(?: or share)? my personal information|do not sell(?: or share)?|privacy policy|cookie policy|cookies? policy|terms of (?:service|use)|manage (?:privacy|cookie|consent) preferences|privacy choices|your privacy choices)$/i.test(normalized) ||
      /(?:do not sell(?: or share)? my personal information|privacy policy|cookie policy|terms of (?:service|use)|privacy choices|your privacy choices)/i.test(normalized);
  }

  function subscriptionWallDominates(text) {
    var normalized = normalizeText(text || "").toLowerCase();
    if (!normalized) return false;

    var pattern = /subscribe to continue|subscription required|sign in to continue reading|log in to continue reading|subscriber-only|purchase short-term access|institutional access|access through your institution|read with a subscription/g;
    if (pattern.test(normalized.slice(0, 600))) return true;

    var hits = normalized.match(pattern) || [];
    return normalized.length < 3000 && hits.length >= 1;
  }

  // Detect structured data paywall signals (isAccessibleForFree, content_tier meta)
  function paywallSignals() {
    // Check structured data: isAccessibleForFree
    var article = structuredDataNode(["NewsArticle", "Article", "BlogPosting", "WebPage", "LiveBlogPosting", "ReportageNewsArticle"]);
    var sdPaywall = article && (article.isAccessibleForFree === false || article.isAccessibleForFree === "False" || article.isAccessibleForFree === "false");

    // Check meta tags: article:content_tier
    var contentTier = metadataValue("article:content_tier", "property") || metadataValue("article:content_tier", "name");
    var metaPaywall = contentTier && /^(locked|metered|premium)$/i.test(normalizeText(contentTier));

    // Check common paywall DOM indicators
    var domPaywall = !!document.querySelector(
      "[data-piano-offer], [data-paywall], [class*='paywall' i], [id*='paywall' i], " +
      "[class*='subscribe-wall' i], [class*='premium-wall' i], [class*='piano-offer' i], " +
      "[data-testid*='paywall' i], [class*='metered' i][class*='banner' i]"
    );

    // Detect paywall text patterns in body
    var bodySnippet = normalizeText((document.body && document.body.innerText) || "").slice(0, 6000).toLowerCase();
    var textPaywall = /(for abonnenter|unlock full access|contenu réservé aux abonnés|solo para suscriptores|nur für abonnenten|alleen voor abonnees|solo per abbonati|dostępne dla subskrybentów|только для подписчиков|лише для передплатників|přístupné pouze pro předplatitele|csak előfizetőknek|exklusivt för prenumeranter|kun for abonnenter|vain tilaajille|tik prenumeratoriams|tikai abonentiem|nur für abonnent|nur für abonnenten|contenido exclusivo para suscriptores|réservé aux abonnés|subscriber exclusive|subscribers only|premium content|members only|členský obsah|premium-inhalt)/.test(bodySnippet);

    if (!sdPaywall && !metaPaywall && !domPaywall && !textPaywall) return null;

    return {
      source: sdPaywall ? "structured_data" : metaPaywall ? "meta_tag" : domPaywall ? "dom_element" : "text_pattern",
      contentTier: contentTier ? normalizeText(contentTier).toLowerCase() : (sdPaywall ? "locked" : null)
    };
  }
