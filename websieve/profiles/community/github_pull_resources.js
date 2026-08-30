function githubPullSiblingInventory(route) {
  return [
    { label: "Conversation", url: githubRouteUrl(route) },
    { label: "Commits", url: githubRouteUrl(route, "/commits") },
    { label: "Checks", url: githubRouteUrl(route, "/checks") },
    { label: "Files changed", url: githubRouteUrl(route, "/files") },
    { label: "Raw diff", url: githubRouteUrl(route) + ".diff" },
    { label: "Raw patch", url: githubRouteUrl(route) + ".patch" }
  ];
}

function githubPullResourceNodeMarkdown(node, removals) {
  if (!node) return "";

  var clone = visibilityPrunedClone(node);
  (removals || []).forEach(function(selector) { removeAll(clone, selector); });
  removeAll(clone, "button, [role='tooltip'], .js-comment-actions, .timeline-comment-actions, [aria-label='Add reaction']");
  return cleanupMarkdownNoise(markdownFor(clone.innerHTML));
}

function githubPullResourceEmptyMarkdown(root, pattern) {
  if (!root) return "";
  var candidates = Array.prototype.slice.call(root.querySelectorAll(".blankslate, [data-testid*='empty'], [data-testid*='blank'], p"));
  candidates.push(root);
  var node = candidates.find(function(candidate) {
    return !elementVisuallyHidden(candidate) && pattern.test(normalizeText(candidate.textContent));
  });
  return githubPullResourceNodeMarkdown(node);
}

function githubPullResourceResult(route, metadata, label, sections, html) {
  var title = normalizeText(firstText(["[data-testid='issue-title']", "main h1", "h1"]) || metadata.title || document.title);
  var markdown = ["# " + title + " — " + label].concat(sections).filter(Boolean).join("\n\n");
  return {
    title: title + " — " + label,
    byline: route.owner,
    excerpt: normalizeText(sections[0] || ""),
    siteName: "GitHub",
    publishedTime: metadata.publishedTime,
    html: html || "",
    markdown: markdown,
    textContent: normalizeText(markdown),
    hostAware: true,
    readerMode: false,
    contentType: "list"
  };
}

function githubPullCommitLink(route, row) {
  var expected = new URL(githubRouteUrl(route, "/commits")).pathname + "/";
  var links = Array.prototype.slice.call(row.querySelectorAll("a[data-commit-link], [data-commit-link] a, a[href]"));
  return links.find(function(link) {
    try {
      return new URL(link.getAttribute("href"), location.href).pathname.indexOf(expected) === 0;
    } catch (_error) {
      return false;
    }
  }) || null;
}

function githubPullCommitDetail(route, row) {
  var clone = visibilityPrunedClone(row);
  var expected = new URL(githubRouteUrl(route, "/commits")).pathname + "/";
  Array.prototype.slice.call(clone.querySelectorAll("a[href]")).forEach(function(link) {
    try {
      if (new URL(link.getAttribute("href"), location.href).pathname.indexOf(expected) === 0) link.remove();
    } catch (_error) {
      link.remove();
    }
  });
  removeAll(clone, "button, [role='tooltip']");
  return cleanupMarkdownNoise(markdownFor(clone.innerHTML));
}

function githubPullCommitContent(route, metadata) {
  var root = document.querySelector("[data-testid='commits-list']");
  if (!root) return null;

  var seen = new Set();
  var sections = Array.prototype.slice.call(root.querySelectorAll("[data-testid='commit-row-item']")).map(function(row) {
    if (elementVisuallyHidden(row)) return null;
    var link = githubPullCommitLink(route, row);
    var url = materializedHttpUrl(link && link.getAttribute("href"));
    var title = normalizeText((link && link.textContent) || "");
    if (!url || !title || seen.has(url)) return null;
    seen.add(url);

    var detail = githubPullCommitDetail(route, row);
    return "## " + markdownLink(title, url) + (detail ? "\n\n" + detail : "");
  }).filter(Boolean);
  if (!sections.length) return null;

  sections.push(browsableInventory("Browse this pull request", githubPullSiblingInventory(route)));
  return githubPullResourceResult(route, metadata, "Commits", sections, visibilityPrunedClone(root).outerHTML);
}

function githubPullCheckUrl(route, link) {
  if (!link) return null;
  try {
    var url = new URL(link.getAttribute("href"), location.href);
    var expected = new URL(githubRouteUrl(route, "/checks"));
    if (url.origin !== expected.origin || url.pathname !== expected.pathname) return null;
    if (!/^\d+$/.test(url.searchParams.get("check_run_id") || "")) return null;
    return materializedHttpUrl(url.href);
  } catch (_error) {
    return null;
  }
}

function githubPullCheckInventory(route) {
  var seen = new Set();
  return Array.prototype.slice.call(document.querySelectorAll("a[href*='check_run_id=']")).map(function(link) {
    if (elementVisuallyHidden(link)) return null;
    var url = githubPullCheckUrl(route, link);
    var label = normalizeText(link.textContent);
    if (!url || !label || seen.has(url)) return null;
    seen.add(url);

    var group = link.closest("details.checks-list-item");
    var item = link.closest(".checks-list-item") || group;
    var summary = group && group.querySelector("summary");
    var statusNode = item && item.querySelector("svg[aria-label]");
    var suite = normalizeText((summary && summary.textContent) || "");
    var status = normalizeText((statusNode && statusNode.getAttribute("aria-label")) || "");
    return { label: label, url: url, detail: [suite, status].filter(Boolean).join(" — ") };
  }).filter(Boolean);
}

function githubPullCheckContent(route, metadata) {
  var root = document.querySelector(".actions-grid-container, [class*='Checks-module__checksRoot']");
  if (!root) return null;

  var checkEntries = githubPullCheckInventory(route);
  var selectedId = new URL(location.href).searchParams.get("check_run_id") || "";
  var selected = /^\d+$/.test(selectedId) ? document.getElementById("check_run_" + selectedId) : null;
  if (selected && elementVisuallyHidden(selected)) selected = null;
  var selectedRoot = selected && (selected.closest("section.js-selected-check-run") || selected);
  if (selectedRoot && elementVisuallyHidden(selectedRoot)) selectedRoot = null;
  var sections = [];
  if (selectedRoot) sections.push("## Selected check\n\n" + githubPullResourceNodeMarkdown(selectedRoot));
  var empty = checkEntries.length ? "" : githubPullResourceEmptyMarkdown(root, /no checks (?:have been|were) run/i);
  if (empty) sections.push("## Checks\n\n" + empty);
  if (checkEntries.length) sections.push(browsableInventory("Checks", checkEntries));
  sections.push(browsableInventory("Browse this pull request", githubPullSiblingInventory(route)));

  return githubPullResourceResult(route, metadata, "Checks", sections, visibilityPrunedClone(selectedRoot || root).outerHTML);
}

function githubPullResourceContent(metadata) {
  var route = githubPullResourceRoute();
  if (!route) return null;
  if (route.surface === "commits") return githubPullCommitContent(route, metadata);
  if (route.surface === "checks") return githubPullCheckContent(route, metadata);
  if (route.surface === "files") return githubPullFileContent(route, metadata);
  return null;
}

function registerGitHubPullResourceProfiles() {
  registerHostAwareProfile(/(^|\.)github\.com$/, githubPullResourceContent);
}
