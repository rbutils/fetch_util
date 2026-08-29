function normalizeText(value) {
  if (typeof value !== "string") value = value == null ? "" : String(value);
  return value.replace(/\s+/g, " ").trim();
}

function safeDecodeURI(value) {
  try { return decodeURIComponent(value); } catch (_e) { return value; }
}

function textLength(node) {
  return normalizeText(node && node.textContent).length;
}

function absoluteUrl(value) {
  if (!value) return null;
  try {
    return new URL(value, document.baseURI).href;
  } catch (_error) {
    return value;
  }
}

function materializedHttpUrl(value) {
  var url = absoluteUrl(value);
  if (!url) return null;

  try {
    var parsed = new URL(url);
    if (parsed.protocol !== "http:" && parsed.protocol !== "https:") return null;
    return parsed.href.replace(/\(/g, "%28").replace(/\)/g, "%29");
  } catch (_error) {
    return null;
  }
}

function materializedCanonicalUrl() {
  var nodes = document.querySelectorAll('link[rel="canonical"]');
  for (var index = 0; index < nodes.length; index += 1) {
    var url = materializedHttpUrl(nodes[index].getAttribute("href"));
    if (url) return url;
  }
  return null;
}

function bodyInnerText(pageText) {
  return (document.body && document.body.innerText) || pageText || "";
}

function humanizeValue(value) {
  return normalizeText(String(value || "").split("/").pop().replace(/[_-]+/g, " "));
}
