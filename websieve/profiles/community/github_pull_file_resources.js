function githubPullFileEntries(route) {
  var seen = new Set();
  return Array.prototype.slice.call(document.querySelectorAll(".file.js-file .file-header[data-path][data-anchor]")).map(function(header) {
    if (elementVisuallyHidden(header)) return null;
    var path = normalizeText(header.getAttribute("data-path"));
    var anchor = header.getAttribute("data-anchor") || "";
    if (!path || !anchor || seen.has(anchor)) return null;
    seen.add(anchor);

    var url = new URL(githubRouteUrl(route, "/files"));
    url.hash = anchor;
    return { label: path, url: materializedHttpUrl(url.href), detail: githubPullFileDetail(header, path) };
  }).filter(Boolean);
}

function githubPullFilesExpectedCount(route) {
  var expectedPath = new URL(githubRouteUrl(route, "/files")).pathname;
  return Array.prototype.slice.call(document.querySelectorAll("a[href]")).reduce(function(total, link) {
    try {
      if (new URL(link.getAttribute("href"), location.href).pathname !== expectedPath) return total;
      var values = normalizeText(link.textContent).match(/\d[\d,]*/g) || [];
      return values.reduce(function(maximum, value) { return Math.max(maximum, Number(value.replace(/,/g, ""))); }, total);
    } catch (_error) {
      return total;
    }
  }, 0);
}

function githubPullFileApiEntries(route, total, loaded) {
  if (!total || total <= loaded) return [];
  var apiTotal = Math.min(total, 3000);
  var pageCount = Math.ceil(apiTotal / 100);
  return Array.from({ length: pageCount }, function(_entry, index) {
    var page = index + 1;
    var first = index * 100 + 1;
    var last = Math.min(page * 100, apiTotal);
    var url = "https://api.github.com/repos/" + encodeURIComponent(route.owner) + "/" + encodeURIComponent(route.repository) +
      "/pulls/" + route.number + "/files?per_page=100&page=" + page;
    return { label: "Files API page " + page, url: url, detail: "Files " + first + "-" + last + " of " + apiTotal };
  });
}

function githubPullCompleteTreeEntries(route, total) {
  if (total <= 3000) return [];
  var repository = location.origin + "/" + route.owner + "/" + route.repository;
  return [
    {
      label: "Complete pull-request Git ref",
      url: repository + ".git",
      detail: "Fetch refs/pull/" + route.number + "/head and compare it with the base branch to enumerate all " + total + " changed files"
    },
    {
      label: "Pull-request head tree archive",
      url: repository + "/archive/refs/pull/" + route.number + "/head.zip",
      detail: "Complete head tree; use the Git ref above for the full changed-file comparison"
    }
  ];
}

function githubPullDeferredFileEntries(file, label) {
  if (!file) return [];
  var seen = new Set();
  return Array.prototype.slice.call(file.querySelectorAll(".js-diff-load-container include-fragment[src], .js-diff-load-container[data-fragment-url], include-fragment[src*='/pull/'][src*='/files']")).map(function(node) {
    var url = materializedHttpUrl(node.getAttribute("src") || node.getAttribute("data-fragment-url"));
    if (!url || seen.has(url)) return null;
    seen.add(url);
    return { label: label || "Deferred diff content", url: url };
  }).filter(Boolean);
}

function githubPullAllDeferredFileEntries() {
  var seen = new Set();
  var entries = [];
  Array.prototype.slice.call(document.querySelectorAll(".file.js-file")).forEach(function(file) {
    if (elementVisuallyHidden(file)) return;
    var header = file.querySelector(".file-header[data-path]");
    var path = normalizeText((header && header.getAttribute("data-path")) || "");
    githubPullDeferredFileEntries(file, path ? path + " deferred diff" : "Deferred diff content").forEach(function(entry) {
      if (!seen.has(entry.url)) {
        seen.add(entry.url);
        entries.push(entry);
      }
    });
  });
  return entries;
}

function githubPullFileDetail(header, path) {
  var accessibleStat = header.querySelector(".file-info .sr-only");
  if (normalizeText((accessibleStat && accessibleStat.textContent) || "")) return normalizeText(accessibleStat.textContent);

  var clone = visibilityPrunedClone(header);
  removeAll(clone, ".file-actions, button, details, svg, clipboard-copy, .diffstat, .Truncate");
  return normalizeText(clone.textContent).replace(path, "").trim();
}

function githubPullFileContent(route, metadata) {
  var entries = githubPullFileEntries(route);
  var root = document.querySelector(".js-diff-progressive-container, [data-testid='pull-request-files']") || document.querySelector("main");
  var empty = entries.length ? "" : githubPullResourceEmptyMarkdown(root, /(?:no files (?:were )?changed|there are no files)/i);
  if (!entries.length && !empty) return null;

  var selectedAnchor = (location.hash || "").replace(/^#/, "");
  var selectedHeader = selectedAnchor ? document.querySelector(".file-header[data-anchor='" + CSS.escape(selectedAnchor) + "']") : null;
  if (selectedHeader && elementVisuallyHidden(selectedHeader)) selectedHeader = null;
  var selectedFile = selectedHeader && selectedHeader.closest(".file.js-file");
  if (selectedFile && elementVisuallyHidden(selectedFile)) selectedFile = null;
  var sections = [];
  if (selectedFile) sections.push("## " + normalizeText(selectedHeader.getAttribute("data-path")) + "\n\n" + githubPullResourceNodeMarkdown(selectedFile));
  if (empty) sections.push("## Files changed\n\n" + empty);
  sections.push(browsableInventory("Files changed", entries));
  var expectedCount = githubPullFilesExpectedCount(route);
  var apiEntries = githubPullFileApiEntries(route, expectedCount, entries.length);
  if (apiEntries.length) {
    var apiCoverage = Math.min(expectedCount, 3000);
    sections.push("GitHub rendered " + entries.length + " of " + expectedCount + " changed files on this page; the public files API inventories " + apiCoverage + ".");
    sections.push(browsableInventory("Additional file inventory pages", apiEntries));
  }
  var completeTreeEntries = githubPullCompleteTreeEntries(route, expectedCount);
  if (completeTreeEntries.length) sections.push(browsableInventory("Complete file comparison", completeTreeEntries));
  var deferredEntries = githubPullAllDeferredFileEntries();
  if (deferredEntries.length) sections.push(browsableInventory("Deferred file content", deferredEntries));
  sections.push(browsableInventory("Browse this pull request", githubPullSiblingInventory(route)));

  var html = selectedFile ? visibilityPrunedClone(selectedFile).outerHTML : entries.map(function(entry) {
    var link = document.createElement("a");
    link.href = entry.url;
    link.textContent = entry.label;
    return link.outerHTML;
  }).join("\n");
  if (!html && empty) html = visibilityPrunedClone(root).outerHTML;
  return githubPullResourceResult(route, metadata, "Files changed", sections, html);
}
