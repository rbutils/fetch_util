function listTrackingQueryName(name) {
  return /^(?:utm_.+|fbclid|gclid|dclid|msclkid|mc_cid|mc_eid|tracking_source)$/i.test(name || "");
}

function listPresentationUrl(value) {
  var materialized = materializedHttpUrl(value || "");
  if (!materialized) return null;
  try {
    var parsed = new URL(materialized);
    Array.from(parsed.searchParams.keys()).forEach(function(name) {
      if (name.toLowerCase() === "tracking_source") parsed.searchParams.delete(name);
    });
    return materializedHttpUrl(parsed.href);
  } catch (_error) {
    return materialized;
  }
}

function listTrackingAliasKey(value) {
  var materialized = listPresentationUrl(value);
  if (!materialized) return "";
  try {
    var parsed = new URL(materialized);
    Array.from(parsed.searchParams.keys()).forEach(function(name) {
      if (listTrackingQueryName(name)) parsed.searchParams.delete(name);
    });
    parsed.hash = "";
    return parsed.origin + parsed.pathname + parsed.search;
  } catch (_error) {
    return "";
  }
}

function listMarkdownWithPresentationUrls(markdown) {
  return String(markdown || "").replace(/(\]\()(https?:\/\/(?:\\.|[^)\s])+)(\))/g, function(_match, prefix, url, suffix) {
    var presented = listPresentationUrl(url.replace(/\\([()])/g, "$1"));
    return prefix + (presented || url) + suffix;
  });
}

function listExactPrimaryAliasDetail(value, item) {
  var match = String(value || "").trim().match(/^\[([^\]]+)\]\((https?:\/\/(?:\\.|[^\)\s])+)\)$/);
  if (!match) return false;
  var destination = listTrackingAliasKey(match[2].replace(/\\([()])/g, "$1"));
  var primary = listTrackingAliasKey(item && item.url || "");
  return !!(destination && primary &&
    normalizeText(match[1]) === normalizeText(item.displayText || item.text || "") &&
    destination === primary);
}

function listEmptyRepresentedReference(value, primaryUrls) {
  var match = String(value || "").trim().match(/^!?\[\]\((https?:\/\/(?:\\.|[^\)\s])+)\)$/);
  if (!match || !primaryUrls) return false;
  var destination = materializedHttpUrl(match[1].replace(/\\([()])/g, "$1"));
  return !!(destination && primaryUrls.has(listCanonicalKey(destination)));
}

function listPrimaryRecordKey(url, title) {
  var destination = materializedHttpUrl(url || "");
  var label = normalizeText(title || "");
  return destination && label ? JSON.stringify([listCanonicalKey(destination), label]) : "";
}

function listPrimaryRecordKeys(items) {
  return new Set((items || []).map(function(item) {
    return listPrimaryRecordKey(item.url, item.displayText || item.text);
  }).filter(Boolean));
}
