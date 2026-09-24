function originAccessErrorPage(title, page) {
  var normalizedTitle = normalizeText(title || "").toLowerCase();
  var normalizedPage = normalizeText(page || "").toLowerCase();
  var shortErrorPage = normalizedPage.length < 1200 &&
    !document.querySelector("article, [itemprop='articleBody'], [property='articleBody']");
  if (shortErrorPage && (/(?:^|\b)502\s+bad gateway\b/i.test(normalizedTitle + " " + normalizedPage) ||
      normalizedTitle === "bad gateway" || normalizedPage === "bad gateway")) return true;
  if (shortErrorPage && /\b(?:access denied|you do not have permission|you don't have permission|permission denied)\b/i.test(normalizedPage.slice(0, 500))) return true;
  if (normalizedTitle === "access denied" &&
      /\b(?:you (?:do not|don't) have permission|access denied)\b/i.test(normalizedPage.slice(0, 500)) &&
      !document.querySelector("article, [itemprop='articleBody'], [property='articleBody']")) return true;
  var cloudflareStatus = /\|\s*52\d\s*:/i.test(title || "") &&
    /\b(?:error code\s*52\d|cloudflare ray id|host error)\b/i.test(normalizedPage) &&
    /\b(?:connection timed out|web server returning unknown error|web server is down|origin is unreachable|ssl handshake failed|host error)\b/i.test(normalizedPage);
  if (cloudflareStatus) return true;

  var forbiddenTitle = /(?:^|\b)(?:error\s*[-:]\s*)?403(?:\s*[-:|]|$)/i.test(normalizedTitle);
  var forbiddenLead = normalizedPage.slice(0, 500);
  if (forbiddenTitle && /\b(?:forbidden|do not have permission(?: to)? access|permission denied|access denied)\b/i.test(forbiddenLead)) return true;

  var directError = document.body && Array.from(document.body.children).find(function(node) {
    return node.tagName && node.tagName.toLowerCase() === "error";
  });
  var viewer = document.querySelector("#webkit-xml-viewer-source-xml");
  var viewerError = viewer && Array.from(viewer.children).find(function(node) {
    return node.tagName && node.tagName.toLowerCase() === "error";
  });
  var errorNode = directError || viewerError;
  var directOwner = directError && document.body.children.length === 1;
  var viewerOwner = viewerError && document.querySelector(".pretty-print");
  if (!errorNode || (!directOwner && !viewerOwner)) return false;
  var code = normalizeText(((errorNode.querySelector("code") || {}).textContent) || "");
  var message = normalizeText(((errorNode.querySelector("message") || {}).textContent) || "");
  return /^accessdenied$/i.test(code) && /^access denied$/i.test(message);
}

function accessErrorVisibleDetails() {
  var owner = document.querySelector("main, [role='main']") || document.body;
  if (!owner || owner.querySelector("article, nav, form, [role='navigation']")) return [];
  var details = [];
  Array.from(owner.childNodes).forEach(function(node) {
    var text = "";
    if (node.nodeType === Node.TEXT_NODE) {
      text = normalizeText(node.textContent || "");
    } else if (node.nodeType === Node.ELEMENT_NODE &&
        node.matches("h1, h2, h3, p, li, div, section") && !elementSubtreeHidden(node) &&
        !node.querySelector("article, nav, form, [role='navigation']")) {
      text = normalizeText(node.textContent || "");
    }
    if (text && details.indexOf(text) === -1) details.push(text);
  });
  return details;
}
