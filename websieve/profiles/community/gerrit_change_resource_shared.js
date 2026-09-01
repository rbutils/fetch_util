function gerritFileResourceRoute() {
  var pathname = (location.pathname || "").replace(/\/+$/, "");
  var marker = pathname.lastIndexOf('/+/');
  if (marker < 1) return null;

  var tail = pathname.slice(marker + 3).split("/");
  if (tail.length < 3 || !/^\d+$/.test(tail[0])) return null;
  var selector = tail[1];
  var comparison = selector.match(/^(-?[1-9]\d*|0)\.\.([1-9]\d*)$/);
  var targetOnly = selector.match(/^([1-9]\d*)$/);
  if (!comparison && !targetOnly) return null;

  var rawPath = tail.slice(2).join("/");
  var filePath = safeDecodeURI(rawPath);
  if (rawPath.indexOf("%") >= 0 && filePath === rawPath) return null;
  var parts = filePath.split("/");
  var magicPath = parts[0] === "" && parts.length === 2 && parts[1];
  if (!filePath || parts.some(function(part, index) { return !part && !(index === 0 && magicPath); }) ||
      parts.some(function(part) { return part === "." || part === ".."; })) return null;

  var target = comparison ? comparison[2] : targetOnly[1];
  var base = comparison ? comparison[1] : null;
  var comparisonKind = "implicit";
  var comparisonValue = null;
  if (base != null) {
    if (Number(base) > 0) {
      comparisonKind = "patchset";
      comparisonValue = base;
    } else if (Number(base) < 0) {
      comparisonKind = "parent";
      comparisonValue = String(Math.abs(Number(base)));
    } else {
      comparisonKind = "auto_merge";
    }
  }
  return {
    number: tail[0],
    selector: selector,
    target: target,
    base: base,
    comparison: comparisonKind,
    comparisonValue: comparisonValue,
    filePath: filePath,
    changePath: pathname.slice(0, marker) + "/+/" + tail[0]
  };
}

function gerritPreparedFileResource(route) {
  var prepared = window.__fetchUtilGerritFileResource;
  if (!route || !prepared || prepared.status !== "ready" || !prepared.product || !prepared.detail ||
      !prepared.route || !prepared.diff || !prepared.file || !prepared.filePath) return null;
  var actual = prepared.route;
  if (actual.number !== route.number || actual.selector !== route.selector || actual.target !== route.target ||
      actual.base !== route.base || actual.filePath !== route.filePath ||
      String(prepared.detail._number || "") !== route.number) return null;
  if (prepared.diff.meta_b && prepared.diff.meta_b.name != null &&
      String(prepared.diff.meta_b.name) !== prepared.filePath) return null;
  if (prepared.firstParentDiff && (typeof prepared.firstParentDiff !== "object" ||
      Array.isArray(prepared.firstParentDiff) ||
      (prepared.firstParentDiff.meta_b && prepared.firstParentDiff.meta_b.name != null &&
        String(prepared.firstParentDiff.meta_b.name) !== prepared.filePath))) return null;

  var revisions = Object.keys(prepared.detail.revisions || {}).map(function(revisionId) {
    return prepared.detail.revisions[revisionId];
  });
  var targetRevision = revisions.find(function(revision) {
    return String(revision && revision._number || "") === route.target;
  });
  if (!targetRevision) return null;
  if (route.comparison === "patchset" && !revisions.some(function(revision) {
    return String(revision && revision._number || "") === route.comparisonValue;
  })) return null;
  if (route.comparison === "parent" &&
      (!targetRevision.commit || !Array.isArray(targetRevision.commit.parents) ||
        targetRevision.commit.parents.length < Number(route.comparisonValue))) return null;
  return prepared;
}

function gerritFileComparisonParameters(route) {
  var parameters = new URLSearchParams();
  if (route.comparison === "patchset") parameters.set("base", route.comparisonValue);
  if (route.comparison === "parent") parameters.set("parent", route.comparisonValue);
  return parameters;
}

function gerritFileComparisonLabel(route) {
  if (route.comparison === "patchset") return "Patch set " + route.comparisonValue + " to " + route.target;
  if (route.comparison === "parent") return "Parent " + route.comparisonValue + " to patch set " + route.target;
  if (route.comparison === "auto_merge") return "Auto-merge base to patch set " + route.target;
  return "Gerrit default base to patch set " + route.target;
}

function gerritFileResourceUiUrl(prepared, filePath, selector) {
  return gerritChangeFileUiUrl(prepared, filePath, selector || prepared.route.selector);
}

function gerritFileResourceApiUrl(prepared, filePath, action, parameters) {
  var prefix = "/revisions/" + encodeURIComponent(prepared.route.target) + "/files/" +
    encodeURIComponent(filePath) + "/" + action;
  var query = parameters && parameters.toString();
  return gerritChangeApiUrl(prepared, prefix + (query ? "?" + query : ""));
}

function gerritFileHasTargetSide(file, diff) {
  return !/^(?:D|DELETED)$/i.test(normalizeText(file && file.status || diff && diff.change_type));
}

function gerritFileHasBaseSide(file, diff) {
  return !/^(?:A|ADDED)$/i.test(normalizeText(file && file.status || diff && diff.change_type));
}

function gerritFileTargetRevision(prepared) {
  return Object.keys(prepared.detail.revisions || {}).map(function(revisionId) {
    return prepared.detail.revisions[revisionId];
  }).find(function(revision) {
    return String(revision && revision._number || "") === prepared.route.target;
  });
}

function gerritFileWebLinkEntries(prefix, links) {
  return (Array.isArray(links) ? links : []).map(function(link, index) {
    if (!link || typeof link !== "object" || !link.url) return null;
    return {
      label: prefix + ": " + (normalizeText(link.name) || ("Link " + (index + 1))),
      url: link.url
    };
  }).filter(Boolean);
}

function gerritFileResourceInventory(prepared) {
  var route = prepared.route;
  var parameters = gerritFileComparisonParameters(route);
  var diffParameters = new URLSearchParams(parameters);
  diffParameters.set("context", "ALL");
  var entries = [
    { label: "Change conversation", url: location.origin + route.changePath },
    { label: "Selected file", url: gerritFileResourceUiUrl(prepared, prepared.filePath) },
    { label: "Selected file diff API", url: gerritFileResourceApiUrl(prepared, prepared.filePath, "diff", diffParameters) },
    { label: "Selected comparison files API", url: gerritChangeApiUrl(prepared,
      "/revisions/" + encodeURIComponent(route.target) + "/files/" +
      (parameters.toString() ? "?" + parameters.toString() : "")) },
    { label: "All change comments API", url: gerritChangeApiUrl(prepared,
      "/comments?enable-context=true&context-padding=3") },
    { label: "Target patch set raw patch", url: gerritChangeApiUrl(prepared,
      "/revisions/" + encodeURIComponent(route.target) + "/patch?download&raw") }
  ];
  if (gerritFileHasTargetSide(prepared.file, prepared.diff)) {
    entries.push({
      label: "Selected file target content",
      url: gerritFileResourceApiUrl(prepared, prepared.filePath, "content")
    });
  }
  var oldPath = normalizeText(prepared.file.old_path) || normalizeText(prepared.diff.meta_a && prepared.diff.meta_a.name) ||
    prepared.filePath;
  var targetRevision = gerritFileTargetRevision(prepared);
  var targetParents = targetRevision && targetRevision.commit && Array.isArray(targetRevision.commit.parents)
    ? targetRevision.commit.parents : [];
  if (oldPath !== prepared.filePath) {
    entries.push({
      label: "Previous file path: " + oldPath,
      url: gerritFileResourceUiUrl(prepared, oldPath)
    });
  }
  if (route.comparison === "patchset" && gerritFileHasBaseSide(prepared.file, prepared.diff)) {
    entries.push({
      label: "Base patch set file content",
      url: gerritChangeApiUrl(prepared, "/revisions/" + encodeURIComponent(route.comparisonValue) +
        "/files/" + encodeURIComponent(oldPath) + "/content")
    });
  } else if (route.comparison === "parent" && gerritFileHasBaseSide(prepared.file, prepared.diff)) {
    var parentParameters = new URLSearchParams();
    parentParameters.set("parent", route.comparisonValue);
    entries.push({
      label: "Base parent file content",
      url: gerritFileResourceApiUrl(prepared, oldPath, "content", parentParameters)
    });
  } else if (route.comparison === "implicit" && targetParents.length &&
      gerritFileHasBaseSide(prepared.file, prepared.diff)) {
    var firstParentParameters = new URLSearchParams();
    firstParentParameters.set("parent", "1");
    entries.push({
      label: targetParents.length > 1 ? "First-parent file content (alternative)" : "Base parent file content",
      url: gerritFileResourceApiUrl(prepared, oldPath, "content", firstParentParameters)
    });
  }
  if (prepared.firstParentDiff) {
    var firstParentDiffParameters = new URLSearchParams();
    firstParentDiffParameters.set("parent", "1");
    firstParentDiffParameters.set("context", "ALL");
    entries.push(
      { label: "Explicit first-parent comparison", url: gerritFileResourceUiUrl(prepared, prepared.filePath,
        "-1.." + route.target) },
      { label: "Explicit first-parent diff API", url: gerritFileResourceApiUrl(prepared, prepared.filePath,
        "diff", firstParentDiffParameters) }
    );
  }
  entries = entries.concat(
    gerritFileWebLinkEntries("Diff link", prepared.diff.web_links),
    gerritFileWebLinkEntries("Base link", prepared.diff.meta_a && prepared.diff.meta_a.web_links),
    gerritFileWebLinkEntries("Target link", prepared.diff.meta_b && prepared.diff.meta_b.web_links)
  );
  Object.keys(prepared.files || {}).forEach(function(filePath) {
    var file = prepared.files[filePath] || {};
    var siblingDiff = new URLSearchParams(parameters);
    siblingDiff.set("context", "ALL");
    entries = entries.concat(gerritChangeFileInventoryEntries(prepared, filePath, route.target, {
      diffFirst: true,
      diffParameters: siblingDiff,
      selector: route.selector,
      targetContent: gerritFileHasTargetSide(file)
    }));
    if (route.comparison === "patchset" && gerritFileHasBaseSide(file)) {
      entries.push({ label: "Base file content: " + filePath,
        url: gerritChangeApiUrl(prepared, "/revisions/" + encodeURIComponent(route.comparisonValue) +
          "/files/" + encodeURIComponent(file.old_path || filePath) + "/content") });
    } else if ((route.comparison === "parent" || (route.comparison === "implicit" && targetParents.length)) &&
        gerritFileHasBaseSide(file)) {
      var siblingParentParameters = new URLSearchParams();
      siblingParentParameters.set("parent", route.comparison === "parent" ? route.comparisonValue : "1");
      entries.push({ label: (route.comparison === "implicit" && targetParents.length > 1
        ? "First-parent file content (alternative): " : "Base file content: ") + filePath,
      url: gerritFileResourceApiUrl(prepared, file.old_path || filePath, "content", siblingParentParameters) });
    }
    if (prepared.firstParentDiff) {
      var siblingFirstParentDiff = new URLSearchParams();
      siblingFirstParentDiff.set("parent", "1");
      siblingFirstParentDiff.set("context", "ALL");
      entries.push({ label: "First-parent diff (alternative): " + filePath,
        url: gerritFileResourceApiUrl(prepared, filePath, "diff", siblingFirstParentDiff) });
    }
    if (file.old_path && file.old_path !== filePath) {
      entries.push({ label: "Previous path: " + file.old_path, url: gerritFileResourceUiUrl(prepared, file.old_path) });
    }
  });
  return browsableInventory("Browse this Gerrit file comparison", entries);
}
