function listTrackingAliasKey(value) {
  var materialized = materializedHttpUrl(value || "");
  if (!materialized) return "";
  try {
    var parsed = new URL(materialized);
    Array.from(parsed.searchParams.keys()).forEach(function(name) {
      if (/^(?:utm_.+|fbclid|gclid|dclid|msclkid|mc_cid|mc_eid)$/i.test(name)) {
        parsed.searchParams.delete(name);
      }
    });
    parsed.hash = "";
    return parsed.origin + parsed.pathname + parsed.search;
  } catch (_error) {
    return "";
  }
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
