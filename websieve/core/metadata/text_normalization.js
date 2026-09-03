function normalizeText(value) {
  if (typeof value !== "string") value = value == null ? "" : String(value);
  return value.replace(/\s+/g, " ").trim();
}

function safeDecodeURI(value) {
  try { return decodeURIComponent(value); } catch (_e) { return value; }
}

function safeDecodeFragment(value) {
  var raw = String(value || "").replace(/^#/, "");
  var decoded = safeDecodeURI(raw);
  return raw.indexOf("%") >= 0 && decoded === raw ? "" : decoded;
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
    if (parsed.username || parsed.password) return null;
    return parsed.href.replace(/\(/g, "%28").replace(/\)/g, "%29");
  } catch (_error) {
    return null;
  }
}

function credentialFreeHttpUrl(value) {
  var url = absoluteUrl(value);
  if (!url) return null;

  try {
    var parsed = new URL(url);
    if (parsed.protocol !== "http:" && parsed.protocol !== "https:") return null;
    parsed.username = "";
    parsed.password = "";
    return parsed.href.replace(/\(/g, "%28").replace(/\)/g, "%29");
  } catch (_error) {
    return null;
  }
}

function credentialFreeHttpText(value) {
  return String(value || "").replace(/(https?:[\\/]{2})[^\\/\s?#@]+@/gi, "$1");
}

function credentialFreeHttpValue(value) {
  if (typeof value === "string") return credentialFreeHttpText(value);
  if (Array.isArray(value)) return value.map(credentialFreeHttpValue);
  if (!value || typeof value !== "object") return value;

  return Object.keys(value).reduce(function(result, key) {
    result[key] = credentialFreeHttpValue(value[key]);
    return result;
  }, {});
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
