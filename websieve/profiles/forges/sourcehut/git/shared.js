function sourcehutGitCommitRoute() {
  var match = (location.pathname || "").match(/^\/(~[\w.%+-]+)\/([\w.%+-]+)\/commit\/(.+)$/);
  if (!match || /\/$/.test(location.pathname) || /\.patch$/i.test(match[3])) return null;

  var segments = match[3].split("/");
  if (segments.some(function(segment) {
    var decoded = safeDecodeURI(segment);
    return !segment || decoded === "." || decoded === "..";
  })) return null;

  var repositoryPath = "/" + match[1] + "/" + match[2];
  return {
    owner: match[1],
    repository: match[2],
    revision: match[3],
    community: match[1] + "/" + match[2],
    repositoryPath: repositoryPath,
    commitPath: repositoryPath + "/commit/" + match[3]
  };
}

function sourcehutGitSameOriginUrl(value) {
  var url = materializedHttpUrl(value);
  if (!url) return null;
  try {
    return new URL(url).origin === location.origin ? url : null;
  } catch (_error) {
    return null;
  }
}

function sourcehutGitAssetEvidence() {
  return Array.prototype.slice.call(document.querySelectorAll("link[href], script[src]")).some(function(node) {
    var url = sourcehutGitSameOriginUrl(node.getAttribute("href") || node.getAttribute("src"));
    return !!(url && /\/static\/git\.sr\.ht\/main\.min\.[a-z0-9]+\.css$/i.test(new URL(url).pathname));
  });
}

function sourcehutGitHeadMeta(name) {
  var nodes = document.head && Array.prototype.slice.call(
    document.head.querySelectorAll(":scope > meta[name='" + name + "'][content]")
  );
  return nodes && nodes.length === 1 ? nodes[0] : null;
}

function sourcehutGitForgeEvidence(route) {
  var summary = sourcehutGitHeadMeta("forge:summary");
  var vcs = sourcehutGitHeadMeta("vcs");
  var summaryUrl = summary && sourcehutGitSameOriginUrl(summary.getAttribute("content"));
  if (!summaryUrl || !vcs || normalizeText(vcs.getAttribute("content")).toLowerCase() !== "git") return false;
  if (new URL(summaryUrl).pathname.replace(/\/$/, "") !== route.repositoryPath) return false;

  return ["forge:dir", "forge:file", "forge:rawfile", "forge:line"].every(function(name) {
    var node = sourcehutGitHeadMeta(name);
    var value = node && node.getAttribute("content");
    if (!value) return false;
    try {
      var url = new URL(value.replace(/\{[^}]+\}/g, "placeholder"), location.href);
      return url.origin === location.origin && url.pathname.indexOf(route.repositoryPath + "/") === 0;
    } catch (_error) {
      return false;
    }
  });
}

function sourcehutGitNavigationEvidence(route) {
  var paths = new Set(Array.prototype.slice.call(document.querySelectorAll(".resource-nav > a[href]")).map(function(link) {
    var url = sourcehutGitSameOriginUrl(link.getAttribute("href"));
    return url && new URL(url).pathname.replace(/\/$/, "");
  }).filter(Boolean));
  return [
    route.repositoryPath,
    route.repositoryPath + "/tree",
    route.repositoryPath + "/log",
    route.repositoryPath + "/refs"
  ].every(function(path) { return paths.has(path); });
}

function sourcehutGitCommitRoot() {
  return Array.prototype.slice.call(document.querySelectorAll(".container > .row .event-list > .event")).find(function(node) {
    return !!(sourcehutGitCommitHeading(node) && node.querySelector(":scope > pre.commit"));
  }) || null;
}

function sourcehutGitCommitHeading(root) {
  return root && Array.prototype.slice.call(root.children).find(function(node) {
    return node.matches("div");
  }) || null;
}

function sourcehutGitSummaryRow(root) {
  return root && root.closest(".container > .row");
}

function sourcehutGitDiffRoot() {
  return Array.prototype.slice.call(document.querySelectorAll(".container .event-list.commit-diff")).find(function(node) {
    return !elementSubtreeHidden(node);
  }) || null;
}

function sourcehutGitCommitId(root) {
  var heading = sourcehutGitCommitHeading(root);
  var match = normalizeText(heading && heading.textContent).match(/\b[0-9a-f]{40}\b/i);
  return match ? match[0].toLowerCase() : "";
}

function sourcehutGitExactLink(path, scope) {
  return Array.prototype.slice.call((scope || document).querySelectorAll("a[href]")).find(function(link) {
    var url = sourcehutGitSameOriginUrl(link.getAttribute("href"));
    return url && new URL(url).pathname.replace(/\/$/, "") === path.replace(/\/$/, "");
  }) || null;
}

function sourcehutGitDiffstatNode(diffRoot) {
  return diffRoot && Array.prototype.slice.call(diffRoot.querySelectorAll(":scope > .event.diff > pre")).find(function(node) {
    return !elementSubtreeHidden(node) && !node.querySelector("a.lineno, strong.text-info");
  }) || null;
}

function sourcehutGitChangedLineCount(diffstat) {
  var text = normalizeText(diffstat && diffstat.textContent);
  var insertions = text.match(/([\d,]+) insertions?\(\+\)/i);
  var deletions = text.match(/([\d,]+) deletions?\(-\)/i);
  if (!insertions && !deletions) return null;
  return Number((insertions ? insertions[1] : "0").replace(/,/g, "")) +
    Number((deletions ? deletions[1] : "0").replace(/,/g, ""));
}

function sourcehutGitLargeDiffNode(diffstat) {
  if (sourcehutGitChangedLineCount(diffstat) <= 10000) return null;
  return Array.prototype.slice.call(document.querySelectorAll(".container .alert.alert-warning")).find(function(node) {
    return !elementSubtreeHidden(node) && /diff is too large to display/i.test(normalizeText(node.textContent));
  }) || null;
}

function sourcehutGitProductMatch(route, root, diffRoot) {
  if (!route || !root || !diffRoot) return false;
  var commitId = sourcehutGitCommitId(root);
  var message = root.querySelector(":scope > pre.commit");
  if (!commitId || !message || !normalizeText(message.textContent)) return false;

  var decodedRevision = safeDecodeURI(route.revision);
  if (/^[0-9a-f]+$/i.test(decodedRevision) &&
      (decodedRevision.length < 4 || decodedRevision.length > 40 || commitId.indexOf(decodedRevision.toLowerCase()) !== 0)) return false;

  var summaryRow = sourcehutGitSummaryRow(root);
  var patch = summaryRow && sourcehutGitExactLink(route.repositoryPath + "/commit/" + commitId + ".patch", summaryRow);
  var tree = summaryRow && sourcehutGitExactLink(route.repositoryPath + "/tree/" + commitId, summaryRow);
  return sourcehutGitAssetEvidence() && sourcehutGitForgeEvidence(route) &&
    sourcehutGitNavigationEvidence(route) && !!sourcehutGitDiffstatNode(diffRoot) && !!patch && !!tree;
}

function sourcehutGitNodeMarkdown(node) {
  var clone = node && visibilityPrunedClone(node);
  if (!clone) return "";
  removeAll(clone, "script, style, noscript, button, form, [role='tooltip'], .dropdown");
  return cleanupMarkdownNoise(markdownFor(clone.innerHTML));
}

function sourcehutGitCommitAuthor(root, commitId) {
  var heading = sourcehutGitCommitHeading(root);
  var clone = heading && visibilityPrunedClone(heading);
  if (!clone) return "";
  removeAll(clone, "small, .ml-2");
  return normalizeText(clone.textContent).replace(new RegExp("^" + commitId + "\\s*(?:-|—)\\s*", "i"), "");
}

function sourcehutGitCommitTimestamp(root) {
  var heading = sourcehutGitCommitHeading(root);
  var titled = heading && heading.querySelector("small.pull-right [title]");
  if (titled) return normalizeText(titled.getAttribute("title"));
  var time = heading && heading.querySelector("small.pull-right time[datetime]");
  return normalizeText(time && time.getAttribute("datetime"));
}

function sourcehutGitCommitParents(root, route) {
  var seen = new Set();
  var heading = sourcehutGitCommitHeading(root);
  return Array.prototype.slice.call(heading.querySelectorAll("a[href]")).map(function(link) {
    var url = sourcehutGitSameOriginUrl(link.getAttribute("href"));
    if (!url) return null;
    var path = new URL(url).pathname;
    var prefix = route.repositoryPath + "/commit/";
    var candidate = path.indexOf(prefix) === 0 ? path.slice(prefix.length) : "";
    var match = candidate.match(/^([0-9a-f]{40})$/i);
    if (!match || seen.has(match[1].toLowerCase())) return null;
    seen.add(match[1].toLowerCase());
    return { id: match[1].toLowerCase(), label: normalizeText(link.textContent), url: url };
  }).filter(Boolean);
}

function sourcehutGitCommitRefs(root) {
  var heading = sourcehutGitCommitHeading(root);
  return Array.prototype.slice.call(heading.querySelectorAll("a.ref[href]")).map(function(link) {
    var url = sourcehutGitSameOriginUrl(link.getAttribute("href"));
    return url && normalizeText(link.textContent) ? { label: normalizeText(link.textContent), url: url } : null;
  }).filter(Boolean);
}
