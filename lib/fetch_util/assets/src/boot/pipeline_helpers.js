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
