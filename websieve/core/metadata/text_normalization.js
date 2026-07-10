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

function bodyInnerText(pageText) {
  return (document.body && document.body.innerText) || pageText || "";
}

function humanizeValue(value) {
  return normalizeText(String(value || "").split("/").pop().replace(/[_-]+/g, " "));
}
