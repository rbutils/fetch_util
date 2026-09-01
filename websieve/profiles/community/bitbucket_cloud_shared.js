function bitbucketCloudPullRequestRoute() {
  var match = (location.pathname || "").match(/^\/([^/]+)\/([^/]+)\/pull-requests\/(\d+)(?:\/overview)?\/?$/);
  if (!match) return null;

  var workspace = safeDecodeURI(match[1]);
  var repository = safeDecodeURI(match[2]);
  if (!workspace || !repository || workspace.indexOf("/") >= 0 || repository.indexOf("/") >= 0) return null;

  return {
    workspace: workspace,
    repository: repository,
    number: match[3],
    community: workspace + "/" + repository,
    basePath: "/" + match[1] + "/" + match[2] + "/pull-requests/" + match[3]
  };
}

function bitbucketCloudRouteUrl(route, suffix) {
  return location.origin + route.basePath + (suffix || "");
}

function bitbucketCloudPullRequestRoot() {
  var header = document.querySelector("[data-testid='pr-header']");
  if (header) return header.closest("main") || document.querySelector("main") || header.parentElement;
  return document.querySelector("main");
}

function bitbucketCloudPullRequestOpening(root) {
  if (!root) return null;
  return root.querySelector([
    "#pull-request-description-panel",
    "section[aria-label='Pull request description']",
    "section[aria-label='Description']"
  ].join(", "));
}

function bitbucketCloudRuntimeRepository() {
  var state = window.__initial_state__ || {};
  return (((state.section || {}).repository || {}).currentRepository) || null;
}

function bitbucketCloudPublicRepository(repository) {
  return !!repository && (
    repository.is_private === false ||
    repository.isPrivate === false ||
    repository.visibility === "public"
  );
}

function bitbucketCloudAssetEvidence() {
  return Array.prototype.slice.call(document.querySelectorAll("script[src], link[href]")).some(function(node) {
    var value = node.getAttribute("src") || node.getAttribute("href") || "";
    return /(?:frontbucket|bbc-frontbucket-static|bitbucket)[^/]*\/(?:assets|static)\//i.test(value) ||
      /\/(?:assets|static)\/[^?#]*(?:frontbucket|bitbucket)/i.test(value);
  });
}

function bitbucketCloudProductMatch(route, root) {
  if (!route || !root) return false;

  var repository = bitbucketCloudRuntimeRepository();
  var runtimeName = normalizeText(repository && repository.full_name).toLowerCase();
  var runtime = bitbucketCloudPublicRepository(repository) && repository.type === "repository" &&
    runtimeName === route.community.toLowerCase();
  var application = document.querySelector("meta[name='application-name']");
  var branded = /^Bitbucket$/i.test(normalizeText(application && application.getAttribute("content")));
  var header = root.querySelector("[data-testid='pr-header']") || document.querySelector("[data-testid='pr-header']");
  var opening = bitbucketCloudPullRequestOpening(root);

  return !!(runtime && branded && (header || bitbucketCloudAssetEvidence()) && opening);
}

function bitbucketCloudScopedText(node, selectors) {
  for (var index = 0; index < selectors.length; index += 1) {
    var candidates = Array.prototype.slice.call(node && node.querySelectorAll(selectors[index]) || []);
    for (var candidateIndex = 0; candidateIndex < candidates.length; candidateIndex += 1) {
      var clone = visibilityPrunedClone(candidates[candidateIndex]);
      var text = normalizeText(clone.textContent);
      if (text) return text;
    }
  }
  return "";
}

function bitbucketCloudOwnedCommentNodes(node, selector) {
  return Array.prototype.slice.call(node.querySelectorAll(selector)).filter(function(candidate) {
    return candidate.closest("[data-testid='comment']") === node;
  });
}

function bitbucketCloudOwnedCommentNode(node, selector) {
  return bitbucketCloudOwnedCommentNodes(node, selector)[0] || null;
}

function bitbucketCloudOwnedCommentText(node, selector) {
  var candidates = bitbucketCloudOwnedCommentNodes(node, selector);
  for (var index = 0; index < candidates.length; index += 1) {
    var text = normalizeText(visibilityPrunedClone(candidates[index]).textContent);
    if (text) return text;
  }
  return "";
}

function bitbucketCloudVisibleClone(node) {
  if (!node || elementSubtreeHidden(node)) return "";
  var clone = visibilityPrunedClone(node);
  removeAll(clone, [
    "button", "[role='tooltip']", "[data-testid='comment-header-actions']",
    "[data-testid='comment-footer']", "[aria-label*='reaction' i]", "form"
  ].join(", "));
  return clone;
}

function bitbucketCloudNodeMarkdown(node) {
  var clone = bitbucketCloudVisibleClone(node);
  if (!clone) return "";
  return cleanupMarkdownNoise(markdownFor(clone.innerHTML));
}

function bitbucketCloudThreadAuthor(node) {
  if (node && node.matches && node.matches("[data-testid='comment']")) {
    return bitbucketCloudOwnedCommentText(node, [
      "[data-testid='comment-author']",
      "[data-testid='user-profile-card-trigger-wrapper'] [data-testid='profile-card-trigger']",
      "[data-testid='user-profile-card-trigger-wrapper']"
    ].join(", "));
  }
  return bitbucketCloudScopedText(node, [
    "[data-testid='comment-author']",
    "[data-testid='pull-request-author']",
    "[data-testid='user-profile-card-trigger-wrapper'] [data-testid='profile-card-trigger']",
    "[data-testid='user-profile-card-trigger-wrapper']"
  ]);
}

function bitbucketCloudThreadTimestamp(node) {
  var times = node && node.matches && node.matches("[data-testid='comment']")
    ? bitbucketCloudOwnedCommentNodes(node, "time[datetime], [datetime]")
    : Array.prototype.slice.call(node && node.querySelectorAll("time[datetime], [datetime]") || []);
  var time = times.find(function(candidate) { return !elementVisuallyHidden(candidate); });
  return normalizeText(time && time.getAttribute("datetime"));
}

function bitbucketCloudThreadPermalink(node, route) {
  var link = node && node.matches && node.matches("[data-testid='comment']")
    ? bitbucketCloudOwnedCommentNodes(node, "a[href*='#comment-']")
      .find(function(candidate) { return !elementVisuallyHidden(candidate); })
    : node && node.querySelector("a[href*='#comment-']");
  var url = materializedHttpUrl(link && link.getAttribute("href"));
  if (url) {
    try {
      var parsed = new URL(url);
      var allowed = [route.basePath, route.basePath + "/diff", route.basePath + "/_/diff"];
      if (parsed.origin === location.origin && allowed.indexOf(parsed.pathname.replace(/\/$/, "")) >= 0 &&
          /^#comment-\d+$/.test(parsed.hash)) return parsed.href;
    } catch (_error) {
      // Fall through to an explicit comment identity.
    }
  }

  var identity = normalizeText(node && (node.id || node.getAttribute("data-comment-id")));
  if (/^comment-\d+$/.test(identity)) return bitbucketCloudRouteUrl(route) + "#" + identity;
  if (/^\d+$/.test(identity)) return bitbucketCloudRouteUrl(route) + "#comment-" + identity;
  return null;
}

function bitbucketCloudApiBase(route) {
  return "https://api.bitbucket.org/2.0/repositories/" + encodeURIComponent(route.workspace) + "/" +
    encodeURIComponent(route.repository) + "/pullrequests/" + route.number;
}

function bitbucketCloudInventoryEntries(route) {
  var apiBase = bitbucketCloudApiBase(route);
  var paginated = "Follow the response's opaque next link until it is absent; do not synthesize page cursors.";
  return [
    { label: "Conversation", url: bitbucketCloudRouteUrl(route) },
    { label: "Commits", url: bitbucketCloudRouteUrl(route, "/commits") },
    { label: "Diff", url: bitbucketCloudRouteUrl(route, "/diff") },
    { label: "Pull request API", url: apiBase },
    { label: "Activity API", url: apiBase + "/activity", detail: paginated },
    { label: "Comments API", url: apiBase + "/comments", detail: paginated },
    { label: "Commits API", url: apiBase + "/commits", detail: paginated },
    { label: "Diff API", url: apiBase + "/diff" },
    { label: "Diffstat API", url: apiBase + "/diffstat", detail: paginated },
    { label: "Patch API", url: apiBase + "/patch" },
    { label: "Statuses API", url: apiBase + "/statuses", detail: paginated },
    { label: "Tasks API", url: apiBase + "/tasks", detail: paginated },
    { label: "Conflicts API", url: apiBase + "/conflicts" }
  ];
}
