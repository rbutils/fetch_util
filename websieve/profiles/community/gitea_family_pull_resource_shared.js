function giteaFamilyPullResourceRoute() {
  var route = giteaFamilyRoute();
  if (!route || route.kind !== "pulls") return null;
  if (route.surface === "commits") {
    return !route.surfaceDetail || route.surfaceDetail === "list" || /^[a-f0-9]{4,64}$/i.test(route.surfaceDetail)
      ? route
      : null;
  }
  if (route.surface === "files") {
    return !route.surfaceDetail || /^[a-f0-9]{4,64}$/i.test(route.surfaceDetail) ||
      /^[a-f0-9]{7,64}\.\.?\.[a-f0-9]{7,64}$/i.test(route.surfaceDetail)
      ? route
      : null;
  }
  return null;
}

function giteaFamilyPullResourceSurface(route) {
  if (route.surface === "commits" && route.surfaceDetail && route.surfaceDetail !== "list") return "files";
  return route.surface;
}

function giteaFamilyPullResourceRoot(route) {
  if (!route) return null;

  var selectors = giteaFamilyPullResourceSurface(route) === "commits"
    ? [
      ".page-content.repository.view.issue.pull.commits",
      ".repository.view.issue.pull.commits",
      ".page-content.repository.view.issue.pull"
    ]
    : [
      ".page-content.repository.view.issue.pull.files.diff",
      ".repository.view.issue.pull.files.diff",
      ".page-content.repository.view.issue.pull"
    ];
  for (var index = 0; index < selectors.length; index += 1) {
    var root = document.querySelector(selectors[index]);
    if (root) return root;
  }
  return null;
}

function giteaFamilyPullEmptyNode(root) {
  if (!root) return null;
  var nodes = Array.prototype.slice.call(root.querySelectorAll(
    ".ui.message.empty, .empty-state, .nothing-here, .no-results, [data-testid='empty-state']"
  ));
  return nodes.find(function(node) {
    return !elementVisuallyHidden(node) && normalizeText(node.textContent);
  }) || null;
}

function giteaFamilyPullEmptyMarkdown(root) {
  var node = giteaFamilyPullEmptyNode(root);
  if (!node) return "";

  var clone = visibilityPrunedClone(node);
  removeAll(clone, "button, form, [role='tooltip'], .menu, .dropdown");
  return cleanupMarkdownNoise(markdownFor(clone.innerHTML));
}

function giteaFamilyPullVisibleMaterial(node) {
  if (!node || elementSubtreeHidden(node)) return false;
  if (!elementVisuallyHidden(node)) return true;

  var clone = visibilityPrunedClone(node);
  return !!normalizeText(clone.textContent) ||
    !!clone.querySelector("table, pre, code, img, ins, del, .diff-line");
}

function giteaFamilyPullResourceProductMatch(route, root) {
  if (!route || !root || !giteaFamilyRuntimeMatches(route)) return false;

  var branded = /\b(?:forgejo|gitea)\b/i.test(giteaFamilyBrandEvidence());
  var product = branded || giteaFamilyRuntimeAssetEvidence(route);
  if (!product) return false;

  if (giteaFamilyPullResourceSurface(route) === "commits") {
    return !!(root.querySelector("#commits-table > tbody.commit-list, .commit-group .commits .commit") ||
      giteaFamilyPullEmptyNode(root));
  }
  return !!(root.querySelector("#diff-container, #diff-file-boxes, #diff-file-tree") ||
    giteaFamilyPullEmptyNode(root));
}

function giteaFamilyPullResourceTitle(metadata, surface) {
  var heading = firstText([".issue-title-header h1", ".issue-title h1", "main h1"]);
  var base = normalizeText(heading || metadata.title || document.title || "Pull request");
  return base + " - " + surface;
}

function giteaFamilyPullCoreInventoryEntries(route) {
  return [{ label: "Conversation", url: giteaFamilyRouteUrl(route) }]
    .concat(giteaFamilyInventoryEntries(route));
}

function giteaFamilyPullResourceResult(title, sections, htmlNodes, route) {
  var markdown = sections.filter(Boolean).join("\n\n");
  return {
    title: title,
    siteName: giteaFamilyPlatform(),
    excerpt: normalizeText(markdown).slice(0, 300),
    html: htmlNodes.filter(Boolean).map(function(node) { return node.outerHTML; }).join("\n"),
    markdown: markdown,
    textContent: normalizeText(markdown),
    hostAware: true,
    readerMode: false,
    contentType: "list",
    platform: giteaFamilyPlatform(),
    community: route.community
  };
}
