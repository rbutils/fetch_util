function sanitizeByline(raw) {
  if (!raw) return raw;
  var text = normalizeText(raw);
  if (!text) return null;
  if (/^https?:\/\//i.test(text)) return null;
  text = text.split(/[\n\t]/)[0];
  text = normalizeText(text);
  if (/^(devam(ın)?ı okuyun|read more|leer más|weiterlesen|lire la suite|leggi di più|czytaj dalej|tümünü gör|اقرأ المزيد|ادامه مطلب|המשך לקרוא|مزید پڑھیں)$/i.test(text)) return null;
  text = text.replace(/\s*@[\w.-]+.*$/i, "").replace(/\s*\d+\s*(takipçi|followers?|متابع|دنبال‌کننده|עוקבים|فالوور).*$/i, "");
  text = normalizeText(text);
  if (!text || text.length < 2) return null;
  return text;
}

function readableOrFallbackContent(options) {
  var content = options && options.reader_mode !== false ? readabilityContent() : null;
  if (content) content = preferFallbackContent(content, fallbackContent());
  if (!content) content = fallbackContent();
  return content;
}

function promoteWarningToInterstitial(content, warnings, warning, maxMarkdownLength, markdown) {
  if (warnings.indexOf(warning) === -1) return;
  if (maxMarkdownLength && normalizeText(markdown || content.markdown || content.textContent || "").length >= maxMarkdownLength) return;
  content.contentType = "interstitial";
}

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
