function gerritChangeRoute() {
  var pathname = (location.pathname || "").replace(/\/+$/, "");
  var marker = pathname.lastIndexOf('/+/');
  if (marker < 1) return null;
  var tail = pathname.slice(marker + 3).split("/").filter(Boolean);
  if (tail.length < 1 || tail.length > 2 || !/^\d+$/.test(tail[0]) || (tail[1] && !/^\d+$/.test(tail[1]))) {
    return null;
  }
  return {
    number: tail[0],
    patchset: tail[1] || null,
    changePath: pathname.slice(0, marker) + "/+/" + tail[0]
  };
}

function gerritChangeProductMatch() {
  var description = document.querySelector("meta[name='description']");
  var descriptionMatch = /^Gerrit Code Review$/i.test(normalizeText(description && description.getAttribute("content")));
  var appMatch = !!document.querySelector("gr-app");
  var footerMatch = Array.prototype.slice.call(document.querySelectorAll("footer, [role='contentinfo']")).some(function(node) {
    return /Powered by Gerrit Code Review/i.test(normalizeText(node.textContent));
  });
  var assetMatch = Array.prototype.slice.call(document.querySelectorAll("script[src], link[href]")).some(function(node) {
    var value = node.getAttribute("src") || node.getAttribute("href") || "";
    if (!/\/polygerrit_ui\/.*\/gr-app\.js(?:$|[?#])/i.test(value)) return false;
    try {
      return new URL(value, location.href).origin === location.origin;
    } catch (_error) {
      return false;
    }
  });
  var preloadMatch = Array.prototype.slice.call(document.querySelectorAll("link[href]")).some(function(node) {
    var value = node.getAttribute("href") || "";
    if (!/\/changes\/[^/?]+\/(?:detail|comments)(?:$|[?])/i.test(value)) return false;
    try {
      return new URL(value, location.href).origin === location.origin;
    } catch (_error) {
      return false;
    }
  });
  return descriptionMatch && appMatch && (footerMatch || assetMatch || preloadMatch);
}

function gerritPreparedChange(route) {
  var prepared = window.__fetchUtilGerritChange;
  if (!route || !prepared || prepared.status !== "ready" || !prepared.product || !prepared.route) return null;
  if (String(prepared.route.number || "") !== route.number || !prepared.route.project ||
      normalizeText(prepared.route.patchset) !== normalizeText(route.patchset) ||
      !prepared.detail || !prepared.comments || !prepared.files) {
    return null;
  }
  if (String(prepared.detail._number || "") !== route.number || prepared.detail.project !== prepared.route.project) return null;
  return prepared;
}

function gerritAccountName(account) {
  if (!account) return "";
  return normalizeText(account.display_name || account.name || account.username || account.email || "");
}

function gerritLiteralBlock(value) {
  return String(value == null ? "" : value).replace(/\r\n?/g, "\n").split("\n").map(function(line) {
    return "    " + line;
  }).join("\n");
}

function gerritChangeApiUrl(prepared, suffix) {
  if (!prepared || !prepared.route || !prepared.route.apiPath) return null;
  try {
    var url = new URL(prepared.route.apiPath + suffix, location.origin);
    if (url.origin !== location.origin || url.pathname.indexOf("/changes/") < 0) return null;
    return url.href;
  } catch (_error) {
    return null;
  }
}

function gerritSelectedRevision(prepared) {
  var detail = prepared.detail || {};
  var selectedPatchset = normalizeText(prepared.route.patchset);
  if (selectedPatchset) {
    var revisions = detail.revisions || {};
    var key = Object.keys(revisions).find(function(revisionKey) {
      return normalizeText(revisions[revisionKey] && revisions[revisionKey]._number) === selectedPatchset;
    });
    return key ? revisions[key] : null;
  }
  return (detail.revisions || {})[detail.current_revision] || null;
}

function gerritSelectedPatchset(prepared) {
  var revision = gerritSelectedRevision(prepared);
  return normalizeText(prepared.route.patchset) || normalizeText(revision && revision._number) || "current";
}

function gerritChangeFileUiUrl(prepared, filePath, patchset) {
  var path = String(filePath || "").split("/").map(encodeURIComponent).join("/");
  if (!path.replace(/\//g, "")) return null;
  var revision = normalizeText(patchset) || gerritSelectedPatchset(prepared);
  return materializedHttpUrl(location.origin + prepared.route.changePath + "/" + revision + "/" + path);
}

function gerritRevisionInventoryEntries(prepared) {
  var revisions = Object.keys(prepared.detail.revisions || {}).map(function(key) {
    return prepared.detail.revisions[key] || {};
  }).filter(function(revision) {
    return normalizeText(revision._number);
  }).sort(function(left, right) {
    return Number(left._number) - Number(right._number);
  });
  var entries = [];
  revisions.forEach(function(revision) {
    var patchset = normalizeText(revision._number);
    var apiPrefix = "/revisions/" + encodeURIComponent(patchset);
    entries.push(
      { label: "Patch set " + patchset, url: location.origin + prepared.route.changePath + "/" + patchset },
      { label: "Patch set " + patchset + " commit API", url: gerritChangeApiUrl(prepared, apiPrefix + "/commit") },
      { label: "Patch set " + patchset + " files API", url: gerritChangeApiUrl(prepared, apiPrefix + "/files/") },
      { label: "Patch set " + patchset + " raw patch", url: gerritChangeApiUrl(prepared, apiPrefix + "/patch?download&raw") }
    );
  });
  return entries;
}

function gerritChangeInventory(prepared) {
  var selectedPatchset = gerritSelectedPatchset(prepared);
  var selectedPrefix = "/revisions/" + encodeURIComponent(selectedPatchset);
  var entries = [
    { label: "Change", url: location.origin + prepared.route.changePath },
    { label: "Change detail API", url: gerritChangeApiUrl(prepared, "/detail?o=ALL_REVISIONS&o=ALL_COMMITS&o=DETAILED_LABELS&o=DETAILED_ACCOUNTS&o=MESSAGES") },
    { label: "Inline comments API", url: gerritChangeApiUrl(prepared, "/comments?enable-context=true&context-padding=3") },
    { label: "Selected patch set files API", url: gerritChangeApiUrl(prepared, selectedPrefix + "/files/") },
    { label: "Selected patch set commit API", url: gerritChangeApiUrl(prepared, selectedPrefix + "/commit") },
    { label: "Selected patch set raw patch", url: gerritChangeApiUrl(prepared, selectedPrefix + "/patch?download&raw") },
    { label: "Selected patch set related changes API", url: gerritChangeApiUrl(prepared, selectedPrefix + "/related") },
    { label: "Selected patch set actions API", url: gerritChangeApiUrl(prepared, selectedPrefix + "/actions") }
  ].concat(gerritRevisionInventoryEntries(prepared));
  Object.keys(prepared.files || {}).forEach(function(filePath) {
    var encoded = encodeURIComponent(filePath);
    entries.push(
      { label: "File: " + filePath, url: gerritChangeFileUiUrl(prepared, filePath) },
      { label: "File content: " + filePath, url: gerritChangeApiUrl(prepared, selectedPrefix + "/files/" + encoded + "/content") },
      { label: "File diff: " + filePath, url: gerritChangeApiUrl(prepared, selectedPrefix + "/files/" + encoded + "/diff") }
    );
  });
  return browsableInventory("Browse this Gerrit change", entries);
}
