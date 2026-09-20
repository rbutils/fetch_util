function sourcehutListsPatchsetRoute() {
  var match = (location.pathname || "").match(/^\/(~[\w.%+-]+)\/([\w.%+-]+)\/patches\/(\d+)\/?$/);
  if (!match || /^(?:\.{1,2}|\.git|\.hg)$/i.test(match[2])) return null;

  var listPath = "/" + match[1] + "/" + match[2];
  return {
    owner: match[1],
    list: match[2],
    number: match[3],
    community: match[1] + "/" + match[2],
    listPath: listPath,
    patchesPath: listPath + "/patches",
    patchsetPath: listPath + "/patches/" + match[3]
  };
}

function sourcehutListsArchiveThreadRoute() {
  var match = (location.pathname || "").match(/^\/(~[\w.%+-]+)\/([\w.%+-]+)\/(.+?)\/?$/);
  if (!match || /^(?:\.{1,2}|\.git|\.hg)$/i.test(match[2])) return null;

  var messageId = match[3].replace(/\/$/, "");
  if (!messageId) return null;
  var listPath = "/" + match[1] + "/" + match[2];
  return {
    owner: match[1],
    list: match[2],
    messageId: messageId,
    community: match[1] + "/" + match[2],
    listPath: listPath,
    patchesPath: listPath + "/patches",
    threadPath: listPath + "/" + messageId
  };
}

function sourcehutListsSameOriginUrl(value) {
  var url = materializedHttpUrl(value);
  if (!url) return null;
  try {
    return new URL(url).origin === location.origin ? url : null;
  } catch (_error) {
    return null;
  }
}

function sourcehutListsAssetEvidence() {
  return Array.prototype.slice.call(document.querySelectorAll("link[href], script[src]")).some(function(node) {
    var value = node.getAttribute("href") || node.getAttribute("src");
    var url = sourcehutListsSameOriginUrl(value);
    return !!url && /\/static\/lists\.sr\.ht\/main\.min\.[a-f0-9]+\.css$/i.test(new URL(url).pathname);
  });
}

function sourcehutListsRoot() {
  return Array.prototype.slice.call(document.querySelectorAll(".container")).find(function(candidate) {
    return !!candidate.querySelector(":scope > .row:first-child .col-md-12 > h3 > small");
  }) || null;
}

function sourcehutListsIdentity(root) {
  var heading = root && root.querySelector(":scope > .row:first-child .col-md-12 > h3");
  if (!heading) return null;
  var clone = heading.cloneNode(true);
  removeAll(clone, "small, .pull-right, a.btn");
  return {
    heading: heading,
    title: normalizeText(clone.textContent),
    version: normalizeText((heading.querySelector(":scope > small") || {}).textContent || ""),
    status: normalizeText((heading.querySelector(":scope > .pull-right") || {}).textContent || "")
  };
}

function sourcehutListsNavigationMatches(route) {
  var paths = new Set(Array.prototype.slice.call(document.querySelectorAll(
    ".header-tabbed.resource-nav a[href]"
  )).map(function(link) {
    var url = sourcehutListsSameOriginUrl(link.getAttribute("href"));
    return url ? new URL(url).pathname.replace(/\/$/, "") : "";
  }));
  return paths.has(route.listPath) && paths.has(route.patchesPath);
}

function sourcehutListsArchiveThreadRoot() {
  return Array.prototype.slice.call(document.querySelectorAll(".container")).find(function(candidate) {
    var column = candidate.querySelector(":scope > .row > .col-md-12");
    return !!column && Array.prototype.slice.call(column.children).some(function(child) {
      return !!child.querySelector(":scope > .message-header");
    });
  }) || null;
}

function sourcehutListsArchiveThreadColumn(root) {
  return root && Array.prototype.slice.call(root.querySelectorAll(":scope > .row > .col-md-12")).find(function(column) {
    return Array.prototype.slice.call(column.children).some(function(child) {
      return !!child.querySelector(":scope > .message-header");
    });
  }) || null;
}

function sourcehutListsArchiveThreadWrappers(root) {
  var column = sourcehutListsArchiveThreadColumn(root);
  if (!column) return [];
  return Array.prototype.slice.call(column.children).filter(function(child) {
    return !elementSubtreeHidden(child) && !!child.querySelector(":scope > .message-header");
  });
}

function sourcehutListsArchiveMboxUrl(route) {
  var link = document.querySelector("link[rel='alternate'][type='application/mbox'][href]");
  var url = link && sourcehutListsSameOriginUrl(link.getAttribute("href"));
  return url && new URL(url).pathname.replace(/\/$/, "") === route.threadPath + "/mbox" ? url : null;
}

function sourcehutListsArchiveRawUrl(header, route) {
  var identity = header && header.querySelector(":scope > .date > a[id]");
  if (!identity) return null;
  var link = Array.prototype.slice.call(header.querySelectorAll("details a[href]")).find(function(candidate) {
    var url = sourcehutListsSameOriginUrl(candidate.getAttribute("href"));
    if (!url) return false;
    var path = new URL(url).pathname;
    if (path.indexOf(route.listPath + "/") !== 0 || !/\/raw$/.test(path)) return false;
    return safeDecodeURI(path.slice(route.listPath.length + 1, -4)) === identity.id;
  });
  return link && sourcehutListsSameOriginUrl(link.getAttribute("href"));
}

function sourcehutListsArchiveThreadProductMatch(route, root) {
  var wrappers = sourcehutListsArchiveThreadWrappers(root);
  var header = wrappers[0] && wrappers[0].querySelector(":scope > .message-header");
  var identity = header && header.querySelector(":scope > .date > a[id][href]");
  if (!identity || identity.id !== safeDecodeURI(route.messageId)) return false;
  try {
    var permalink = new URL(identity.getAttribute("href"), location.href);
    if (permalink.origin !== location.origin || permalink.pathname.replace(/\/$/, "") !== route.threadPath ||
        safeDecodeURI(permalink.hash.slice(1)) !== identity.id) return false;
  } catch (_error) {
    return false;
  }
  return sourcehutListsAssetEvidence() && sourcehutListsNavigationMatches(route) &&
    !!sourcehutListsArchiveMboxUrl(route) && !!sourcehutListsArchiveRawUrl(header, route);
}

function sourcehutListsPatchInfo(heading, route) {
  if (!heading || !heading.matches("h3")) return null;
  var rawLink = heading && Array.prototype.slice.call(heading.querySelectorAll("a[href]")).find(function(link) {
    var url = sourcehutListsSameOriginUrl(link.getAttribute("href"));
    if (!url) return false;
    var path = new URL(url).pathname;
    if (path.indexOf(route.listPath + "/") !== 0 || !/\/raw$/.test(path)) return false;
    var messageId = path.slice(route.listPath.length + 1, -4);
    return !!messageId;
  });
  if (!rawLink) return null;
  var clone = heading.cloneNode(true);
  removeAll(clone, "a.btn, button");
  return {
    heading: heading,
    subject: normalizeText(clone.textContent),
    rawUrl: sourcehutListsSameOriginUrl(rawLink.getAttribute("href"))
  };
}

function sourcehutListsPatchInfos(root, route) {
  return Array.prototype.slice.call(root.querySelectorAll("h3")).map(function(heading) {
    return sourcehutListsPatchInfo(heading, route);
  }).filter(Boolean);
}

function sourcehutListsPatchsetMboxUrl(root, route) {
  var link = Array.prototype.slice.call(root.querySelectorAll("a[href]")).find(function(candidate) {
    var url = sourcehutListsSameOriginUrl(candidate.getAttribute("href"));
    return url && new URL(url).pathname.replace(/\/$/, "") === route.patchsetPath + "/mbox";
  });
  return link && sourcehutListsSameOriginUrl(link.getAttribute("href"));
}

function sourcehutListsArchiveThreadUrl(root, route) {
  var link = Array.prototype.slice.call(root.querySelectorAll("a[href]")).find(function(candidate) {
    if (!/view this thread in the archives/i.test(normalizeText(candidate.textContent))) return false;
    var url = sourcehutListsSameOriginUrl(candidate.getAttribute("href"));
    if (!url) return false;
    var path = new URL(url).pathname.replace(/\/$/, "");
    var suffix = path.indexOf(route.listPath + "/") === 0
      ? path.slice(route.listPath.length + 1)
      : "";
    return !!suffix;
  });
  return link && sourcehutListsSameOriginUrl(link.getAttribute("href"));
}

function sourcehutListsOpeningBody(root) {
  var column = Array.prototype.slice.call(root.querySelectorAll(":scope > .row > .col-md-8")).find(function(node) {
    return !!Array.prototype.slice.call(node.children).find(function(child) {
      return child.matches("pre.message-body");
    });
  });
  if (!column) return null;
  return Array.prototype.slice.call(column.children).find(function(child) {
    return child.matches("pre.message-body");
  }) || null;
}

function sourcehutListsProductMatch(route, root) {
  var identity = sourcehutListsIdentity(root);
  var statuses = ["UNKNOWN", "PROPOSED", "NEEDS REVISION", "SUPERSEDED", "APPROVED", "REJECTED", "APPLIED"];
  return !!identity && !!identity.title && /^v\d+$/i.test(identity.version) &&
    statuses.indexOf(identity.status.toUpperCase()) >= 0 && !!sourcehutListsOpeningBody(root) &&
    sourcehutListsAssetEvidence() && sourcehutListsNavigationMatches(route) &&
    !!sourcehutListsPatchsetMboxUrl(root, route) && !!sourcehutListsArchiveThreadUrl(root, route) &&
    sourcehutListsPatchInfos(root, route).length > 0;
}

function sourcehutListsInventory(route, root, patches) {
  var entries = [
    { label: "List archive", url: location.origin + route.listPath },
    { label: "Patchsets", url: location.origin + route.patchesPath },
    { label: "Current patchset", url: location.origin + route.patchsetPath }
  ];
  var mbox = sourcehutListsPatchsetMboxUrl(root, route);
  if (mbox) entries.push({ label: "Patchset mbox", url: mbox, detail: "Patches only" });
  var thread = sourcehutListsArchiveThreadUrl(root, route);
  if (thread) {
    entries.push({ label: "Archive thread", url: thread });
    entries.push({ label: "Full thread mbox", url: thread.replace(/\/$/, "") + "/mbox" });
  }
  patches.forEach(function(patch) {
    entries.push({ label: "Raw patch: " + patch.subject, url: patch.rawUrl });
  });
  Array.prototype.slice.call(root.querySelectorAll(".alert.alert-info a[href]")).forEach(function(link) {
    var url = sourcehutListsSameOriginUrl(link.getAttribute("href"));
    if (url) entries.push({ label: normalizeText(link.textContent) || "Related revision", url: url });
  });
  Array.prototype.slice.call(document.querySelectorAll(".project-nav a[href]")).forEach(function(link) {
    var url = materializedHttpUrl(link.getAttribute("href"));
    if (url) entries.push({ label: normalizeText(link.textContent) || "Related project", url: url });
  });
  return browsableInventory("Browse this SourceHut patchset", entries);
}
