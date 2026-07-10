function mwananchiPrePageTextCleanup() {
  if (!/(^|\.)mwananchi\.co\.tz$/i.test(location.hostname || "")) return;

  removeAll(document, [
    "#paywall",
    "[data-paywall]",
    "[id*='paywall' i]",
    "[class*='paywall' i]",
    "[class*='subscribe' i]",
    "[class*='premium' i]"
  ].join(", "));

  document.querySelectorAll("script[type='application/ld+json']").forEach(function(script) {
    var text = normalizeText(script.textContent || "");
    if (/\b(?:NewsArticle|Article)\b/.test(text)) script.remove();
  });

  document.querySelectorAll("p, div, span, section, aside, button, a").forEach(function(node) {
    var text = normalizeText(node.textContent || "");
    if (!text || text.length > 420) return;
    if (/^(ndiyo, tafadhali!?|ingia|jisajili ili kuanza safari yako ya kufikia maudhui yetu yanayolipiwa|jiunge nasi leo usikose habari muhimu|pata habari na chambuzi huru, za kina na za uhakika kutoka mwananchi|loading\.\.\.)$/i.test(text)) {
      node.remove();
    }
  });
}
