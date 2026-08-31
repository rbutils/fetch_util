function giteaFamilyRuntime() {
  return window.config || {};
}

function giteaFamilyRoute() {
  var runtime = giteaFamilyRuntime();
  var routePrefix = normalizeText(runtime.appSubUrl || "").replace(/^\/+|\/+$/g, "");
  routePrefix = routePrefix ? "/" + routePrefix : "";
  var pathname = location.pathname || "";
  if (routePrefix && pathname.indexOf(routePrefix + "/") !== 0) return null;

  var relativePath = routePrefix ? pathname.slice(routePrefix.length) : pathname;
  var match = relativePath.match(/^\/([\w.%+-]+)\/([\w.%+-]+)\/(issues|pulls)\/(\d+)(?:\/(commits|files))?\/?$/);
  if (!match) return null;

  var projectPath = match[1] + "/" + match[2];
  return {
    owner: match[1],
    repository: match[2],
    projectPath: projectPath,
    community: projectPath,
    kind: match[3],
    number: match[4],
    surface: match[5] || null,
    routePrefix: routePrefix,
    basePath: routePrefix + "/" + projectPath + "/" + match[3] + "/" + match[4]
  };
}

function giteaFamilyThreadRoute() {
  var route = giteaFamilyRoute();
  return route && !route.surface ? route : null;
}

function giteaFamilyRouteUrl(route, suffix) {
  return location.origin + route.basePath + (suffix || "");
}

function giteaFamilyApiBase(route) {
  return location.origin + route.routePrefix + "/api/v1/repos/" +
    encodeURIComponent(route.owner) + "/" + encodeURIComponent(route.repository);
}

function giteaFamilyRuntimeMatches(route) {
  var runtime = giteaFamilyRuntime();
  if (!runtime.appUrl) return false;

  try {
    var appUrl = new URL(runtime.appUrl, location.href);
    var appPath = appUrl.pathname.replace(/\/$/, "");
    return appUrl.origin === location.origin && appPath === route.routePrefix;
  } catch (_error) {
    return false;
  }
}

function giteaFamilyBrandEvidence() {
  var values = Array.prototype.slice.call(document.querySelectorAll(
    "meta[name='author'], meta[name='generator'], meta[property='og:site_name']"
  )).map(function(node) {
    return normalizeText(node.getAttribute("content"));
  });
  Array.prototype.slice.call(document.querySelectorAll("footer a[href]")).forEach(function(link) {
    var text = normalizeText(link.textContent);
    var href = normalizeText(link.getAttribute("href"));
    if (/powered by/i.test(text) || /(?:forgejo|gitea)/i.test(href)) values.push(text + " " + href);
  });
  values.push(normalizeText(giteaFamilyRuntime().assetVersionEncoded || ""));
  return values.join(" ");
}

function giteaFamilyRuntimeAssetEvidence(route) {
  var prefix = normalizeText(giteaFamilyRuntime().assetUrlPrefix || "");
  if (!prefix) return false;

  try {
    var assetUrl = new URL(prefix, location.href);
    var expectedPath = route.routePrefix + "/assets";
    if (assetUrl.origin !== location.origin || assetUrl.pathname.replace(/\/$/, "") !== expectedPath) return false;

    return Array.prototype.slice.call(document.querySelectorAll("script[src], link[href]")).some(function(node) {
      var value = node.getAttribute("src") || node.getAttribute("href");
      if (!value) return false;
      var url = new URL(value, location.href);
      return url.origin === location.origin && url.pathname.indexOf(expectedPath + "/") === 0;
    });
  } catch (_error) {
    return false;
  }
}

function giteaFamilyPlatform() {
  var evidence = giteaFamilyBrandEvidence();
  if (/\bforgejo\b/i.test(evidence)) return "Forgejo";
  if (/\bgitea\b/i.test(evidence)) return "Gitea";
  return "Gitea/Forgejo";
}

function giteaFamilyThreadRoot(route) {
  if (!route) return null;

  return document.querySelector([
    ".page-content.repository.view.issue .issue-content",
    ".repository.view.issue .issue-content",
    ".page-content .issue-content"
  ].join(", "));
}

function giteaFamilyOpening(root) {
  if (!root) return null;

  return root.querySelector([
    ".issue-content-left .timeline-item.comment.issue-content-comment[id^='issue-']",
    ".issue-content-left .timeline-item.comment.issue-content-comment",
    ".issue-content-left .timeline-item.comment.first[id^='issue-']",
    ".issue-content-left .timeline-item.comment.first",
    ".comment-list .timeline-item.comment.issue-content-comment",
    ".comment-list .timeline-item.comment.first"
  ].join(", "));
}

function giteaFamilyProductMatch(route, root) {
  var opening = giteaFamilyOpening(root);
  if (!route || !root || !opening) return false;
  if (!giteaFamilyRuntimeMatches(route)) return false;

  var openingBody = opening.querySelector(".comment-body");
  var rendered = openingBody && openingBody.querySelector(".render-content.markup");
  var empty = openingBody && openingBody.querySelector(".no-content");
  var attachment = openingBody && Array.prototype.slice.call(openingBody.querySelectorAll(
    ".dropzone-attachments a[href], .attachments a[href]"
  )).some(function(node) { return !elementVisuallyHidden(node); });
  var structure = !!(
    root.querySelector(".issue-content-left .comment-list, .issue-content-left.comment-list") &&
    opening.querySelector(".content.comment-container, .comment-body") &&
    ((rendered && !elementVisuallyHidden(rendered) && normalizeText(rendered.textContent)) ||
      (empty && !elementVisuallyHidden(empty)) || attachment)
  );
  var branded = /\b(?:forgejo|gitea)\b/i.test(giteaFamilyBrandEvidence());
  return structure && (branded || giteaFamilyRuntimeAssetEvidence(route));
}

function giteaFamilyTimelineItems(root) {
  var selector = [
    ".issue-content-left .timeline-item-group",
    ".issue-content-left .timeline-item",
    ".comment-list .timeline-item-group",
    ".comment-list .timeline-item"
  ].join(", ");
  var records = [];
  Array.prototype.slice.call(root.querySelectorAll(selector)).forEach(function(node) {
    var group = node.closest(".timeline-item-group");
    var record = group && root.contains(group) ? group : node;
    if (elementSubtreeHidden(record)) return;
    if (record.matches(".pull-merge-box, .timeline-item.comment.merge.box, .form, #timeline-comments-end")) return;
    if (records.some(function(existing) { return existing === record || existing.contains(record); })) return;
    records.push(record);
  });
  return records;
}

function giteaFamilyInventoryEntries(route) {
  var api = giteaFamilyApiBase(route);
  var issueApi = api + "/issues/" + route.number;
  var entries = [];
  if (route.kind === "pulls") {
    var pullApi = api + "/pulls/" + route.number;
    entries.push(
      { label: "Commits", url: giteaFamilyRouteUrl(route, "/commits") },
      { label: "Files changed", url: giteaFamilyRouteUrl(route, "/files") },
      { label: "Raw diff", url: giteaFamilyRouteUrl(route) + ".diff" },
      { label: "Raw patch", url: giteaFamilyRouteUrl(route) + ".patch" },
      { label: "Pull request API", url: pullApi },
      { label: "Pull request commits API", url: pullApi + "/commits", detail: "Follow response pagination headers when present." },
      { label: "Pull request files API", url: pullApi + "/files", detail: "Follow response pagination headers when present." },
      { label: "Pull request reviews API", url: pullApi + "/reviews", detail: "Follow response pagination headers when present." }
    );
  }
  entries.push(
    { label: "Issue API", url: issueApi },
    { label: "Comments API", url: issueApi + "/comments", detail: "Follow Link, X-HasMore, and total-count headers when present." },
    { label: "Timeline API", url: issueApi + "/timeline", detail: "Follow Link, X-HasMore, and total-count headers when present." },
    { label: "Labels API", url: issueApi + "/labels", detail: "Follow Link, X-HasMore, and total-count headers when present." }
  );
  return entries;
}

function giteaFamilyThreadInventory(route) {
  return browsableInventory("Browse this " + giteaFamilyPlatform() + " thread", giteaFamilyInventoryEntries(route));
}
