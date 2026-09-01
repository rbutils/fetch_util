function bitbucketCloudPullCommitIdentity(link, route) {
  if (!link || !route) return null;

  var labelMatch = normalizeText(link.getAttribute("aria-label")).match(/^Commit:\s*([0-9a-f]{7,40})$/i);
  if (!labelMatch) return null;
  try {
    var url = new URL(link.href, location.href);
    var pathMatch = url.pathname.match(/^\/([^/]+)\/([^/]+)\/commits\/([0-9a-f]{40})\/?$/i);
    if (url.origin !== location.origin || !pathMatch) return null;
    if (safeDecodeURI(pathMatch[1]) !== route.workspace || safeDecodeURI(pathMatch[2]) !== route.repository) return null;
    if (pathMatch[3].toLowerCase().indexOf(labelMatch[1].toLowerCase()) !== 0) return null;
    return { hash: pathMatch[3].toLowerCase(), url: url.href };
  } catch (_error) {
    return null;
  }
}

function bitbucketCloudPullCommitRows(root, route) {
  var seen = new Set();
  var links = Array.prototype.slice.call(root.querySelectorAll("a[aria-label^='Commit: '][href*='/commits/']"));
  return links.map(function(link) {
    var identity = bitbucketCloudPullCommitIdentity(link, route);
    var row = link.closest("tr, [role='row']");
    if (!identity || !row || elementSubtreeHidden(row) || seen.has(identity.hash)) return null;
    seen.add(identity.hash);
    return { hash: identity.hash, node: row };
  }).filter(Boolean);
}

function bitbucketCloudPullCommitRoot() {
  var panel = document.querySelector("[role='tabpanel'][id^='pull-request-tabs-']");
  if (panel) return panel;

  var wrapper = document.querySelector("[data-qa^='commit-hash-wrapper-']");
  return wrapper && wrapper.closest("table, [role='grid']");
}

function bitbucketCloudPullCommitMarkdown(record) {
  var clone = bitbucketCloudVisibleClone(record.node);
  if (!clone) return "";
  removeAll(clone, "button, [role='tooltip'], [data-testid*='menu'], [data-qa*='menu']");
  return cleanupMarkdownNoise(markdownFor(clone.innerHTML));
}

function bitbucketCloudPullCommitsContent(metadata, route, root) {
  var records = bitbucketCloudPullCommitRows(root, route).map(function(record) {
    return { record: record, markdown: bitbucketCloudPullCommitMarkdown(record) };
  }).filter(function(record) {
    return !!normalizeText(record.markdown);
  });
  if (!records.length) return null;

  var heading = firstText(["[data-testid='pr-header'] h1", "[data-testid='pr-header'] [role='heading']", "h1"]);
  var title = normalizeText(heading || metadata.title || document.title || "Bitbucket pull request") + " - Commits";
  var sections = ["# " + title, "- Commits shown: " + records.length, "## Commits"];
  records.forEach(function(record, index) {
    sections.push("### Commit " + (index + 1), record.markdown);
  });
  sections.push(browsableInventory("Browse this Bitbucket pull request", bitbucketCloudInventoryEntries(route)));
  var markdown = sections.filter(Boolean).join("\n\n");

  return {
    title: title,
    siteName: "Bitbucket",
    excerpt: normalizeText(records[0].markdown),
    html: records.map(function(record) {
      var clone = bitbucketCloudVisibleClone(record.record.node);
      return clone ? clone.outerHTML : "";
    }).filter(Boolean).join("\n"),
    markdown: markdown,
    textContent: normalizeText(markdown),
    hostAware: true,
    readerMode: false,
    contentType: "list"
  };
}

function bitbucketCloudPullResourceContent(metadata) {
  var route = bitbucketCloudPullRequestResourceRoute();
  if (!route || route.surface !== "commits" || !bitbucketCloudRuntimeProductMatch(route)) return null;
  var root = bitbucketCloudPullCommitRoot();
  return root && bitbucketCloudPullCommitsContent(metadata, route, root);
}

function registerBitbucketCloudPullResourceProfiles() {
  registerHostAwareProfile(true, bitbucketCloudPullResourceContent);
}
