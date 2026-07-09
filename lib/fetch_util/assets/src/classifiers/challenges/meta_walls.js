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

  if (!/(^|\.)(facebook\.com|threads\.(net|com))$/.test(location.hostname) && !/(facebook|threads|meta)/.test(signature)) return false;

  return /meta products|cookies from other companies|allow the use of cookies from threads by instagram|log in with your instagram|join threads to share ideas|create new account|log in to facebook|log in to continue|essential cookies/.test(signature + " " + combined);
}

function metaWallContent(metadata, pageText) {
  if (!metaWallPage(metadata, pageText)) return null;

  var threadsHost = /(threads)/i.test([location.hostname, metadata && metadata.siteName, metadata && metadata.title].join(" "));
  var title = normalizeText(metadata.title || document.title);
  var target = metaRequestedLabel();
  var details = [threadsHost ? "Access notice: Threads login or cookie acceptance required" : "Access notice: Facebook login or cookie acceptance required"];
  var description = metadata.excerpt;

  if (!title || /threads\s*[•|-]\s*log in|facebook\s*-\s*log in/i.test(title)) {
    title = target ? (threadsHost ? "Threads page " + target : "Facebook page " + target) : (threadsHost ? "Threads page" : "Facebook page");
  }

  if (!description || /join threads to share ideas|log in with your instagram|create an account or log into facebook/i.test(description)) {
    description = threadsHost ?
      "Original content on this Threads page is not available without login or cookie acceptance." :
      "Original content on this Facebook page is not available without login or cookie acceptance.";
  }

  if (target && title.indexOf(target) === -1) details.push("Requested page: " + target);

  return articleContentFromParts({
    title: title,
    description: description,
    details: details,
    siteName: metadata.siteName || location.hostname
  });
}
