function sanitizeByline(raw) {
  if (!raw) return raw;
  var text = normalizeText(raw);
  if (!text) return null;
  if (/^https?:\/\//i.test(text)) return null;
  text = text.split(/[\n\t]/)[0];
  text = normalizeText(text);
  if (/^(devam(ın)?ı okuyun|read more|leer más|weiterlesen|lire la suite|leggi di più|czytaj dalej|tümünü gör|اقرأ المزيد|ادامه مطلب|המשך לקרוא|مزید پڑھیں)$/i.test(text)) return null;
  if (/^(?:author information|authors? and affiliations?)$/i.test(text)) return null;
  if (/^(?:[1-9]|[12]\d|3[01])\s+[^\d\s,]{3,}\s+(?:19|20)\d{2}(?:\s*,?\s*(?:[01]?\d|2[0-3]):[0-5]\d)?$/i.test(text)) return null;
  text = text.replace(/\s*@[\w.-]+.*$/i, "").replace(/\s*\d+\s*(takipçi|followers?|متابع|دنبال‌کننده|עוקבים|فالوور).*$/i, "");
  text = normalizeText(text);
  if (!text || text.length < 2) return null;
  return text;
}

function bylineWithoutPublishedTime(raw, publishedTime, knownByline) {
  var text = sanitizeByline(raw);
  var date = normalizeText(publishedTime || "");
  var known = sanitizeByline(knownByline);
  if (!text || !date) return text;
  if (known && text === normalizeText(known + " " + date)) return known;
  if ((date.match(/\d+/g) || []).length < 2) return text;

  var suffix = date.replace(/[.*+?^${}()|[\]\\]/g, "\\$&").replace(/\s+/g, "\\s*");
  var prefix = normalizeText(text.replace(new RegExp("\\s*" + suffix + "$", "i"), ""));
  if (prefix === text) return text;
  return prefix ? sanitizeByline(prefix) : null;
}

function bylineContainsPublishedTime(raw, publishedTime) {
  var text = sanitizeByline(raw);
  var date = normalizeText(publishedTime || "");
  if (!text || !date || (date.match(/\d+/g) || []).length < 2) return false;
  var suffix = date.replace(/[.*+?^${}()|[\]\\]/g, "\\$&").replace(/\s+/g, "\\s*");
  return new RegExp(suffix + "$", "i").test(text);
}

function bylineWithoutHostIdentity(raw) {
  var text = sanitizeByline(raw);
  if (!text) return null;
  var value = text.toLowerCase().replace(/^www\./, "");
  var hostname = normalizeText(location.hostname || "").toLowerCase().replace(/^www\./, "");
  return hostname && value === hostname ? null : text;
}

function readableOrFallbackContent(options, metadata) {
  var content = options && options.reader_mode !== false ? readabilityContent() : null;
  if (content) content = preferFallbackContent(content, fallbackContent(metadata));
  if (!content) content = fallbackContent(metadata);
  return content;
}

function promoteWarningToInterstitial(content, warnings, warning, maxMarkdownLength, markdown) {
  if (warnings.indexOf(warning) === -1) return;
  if (maxMarkdownLength && normalizeText(markdown || content.markdown || content.textContent || "").length >= maxMarkdownLength) return;
  content.contentType = "interstitial";
}
