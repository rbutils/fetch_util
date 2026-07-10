function metaRequestedLabel() {
  var target = queryParam("next") || location.pathname;

  try {
    target = new URL(target, location.href).pathname;
  } catch (_error) {
  }

  var parts = safeDecodeURI(target || "").split("/").filter(Boolean);
  if (!parts.length) return null;
  if (parts[0] === "login") return normalizeText(parts[1] || "");
  return normalizeText(parts[0]);
}

function metaWallPage(metadata, pageText) {
  var signature = normalizeText([
    location.hostname,
    metadata && metadata.siteName,
    metadata && metadata.title,
    metadata && metadata.excerpt
  ].join(" ")).toLowerCase();
  var combined = normalizeText([
    pageText
  ].join(" ")).toLowerCase();

  if (!/(^|\.)(facebook\.com|instagram\.com|threads\.(net|com))$/.test(location.hostname) && !/(facebook|instagram|threads|meta)/.test(signature)) return false;

  return /meta products|cookies from other companies|allow the use of cookies from (?:threads by )?instagram|log in with your instagram|join threads to share ideas|create new account|log in to (?:facebook|instagram)|log in to continue|log in to see photos and videos|sign up to see|page (?:is|isn't|is not) available|sorry, this page isn't available|essential cookies/.test(signature + " " + combined);
}

function metaWallContent(metadata, pageText) {
  if (!metaWallPage(metadata, pageText)) return null;

  var network = /(threads)/i.test([location.hostname, metadata && metadata.siteName, metadata && metadata.title].join(" ")) ? "Threads" :
    /(instagram)/i.test([location.hostname, metadata && metadata.siteName, metadata && metadata.title].join(" ")) ? "Instagram" : "Facebook";
  var title = normalizeText(metadata.title || document.title);
  var target = metaRequestedLabel();
  var details = ["Access notice: " + network + " login or cookie acceptance required"];
  var description = metadata.excerpt;

  if (!title || /threads\s*[•|-]\s*log in|facebook\s*-\s*log in/i.test(title)) {
    title = target ? network + " page " + target : network + " page";
  }

  if (!description || /join threads to share ideas|log in with your instagram|create an account or log into facebook/i.test(description)) {
    description = "Original content on this " + network + " page is not available without login or cookie acceptance.";
  }

  if (target && title.indexOf(target) === -1) details.push("Requested page: " + target);

  return articleContentFromParts({
    title: title,
    description: description,
    details: details,
    siteName: metadata.siteName || location.hostname,
    contentType: "interstitial"
  });
}
