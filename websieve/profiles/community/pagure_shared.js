function pagureProjectRoute(match, itemName) {
  if (!match) return null;
  var rawProjectPath = match[1];
  if (/^\//.test(rawProjectPath) || /\/\//.test(rawProjectPath)) return null;
  var parts = rawProjectPath.split("/").filter(Boolean);
  if (!parts.length || parts.some(function(part) { return !/^[\w.%+~-]+$/.test(part); })) return null;

  var fullProjectPath = parts.join("/");
  var routePrefix = pagureInstallPrefix() || "";
  var prefixPath = routePrefix.replace(/^\/+|\/+$/g, "");
  var projectPath = fullProjectPath;
  if (prefixPath && projectPath.indexOf(prefixPath + "/") === 0) {
    projectPath = projectPath.slice(prefixPath.length + 1);
  }
  if (!projectPath) return null;

  var basePath = routePrefix + "/" + projectPath;
  return {
    projectPath: projectPath,
    community: safeDecodeURI(projectPath),
    number: match[2],
    basePath: basePath,
    apiPrefix: routePrefix + "/api/0",
    itemPath: basePath + "/" + itemName + "/" + match[2]
  };
}

function pagureIssueRoute() {
  var route = pagureProjectRoute((location.pathname || "").match(/^\/(.+)\/issue\/(\d+)\/?$/), "issue");
  if (route) route.issuePath = route.itemPath;
  return route;
}

function pagurePullRequestRoute() {
  var route = pagureProjectRoute((location.pathname || "").match(/^\/(.+)\/pull-request\/(\d+)\/?$/), "pull-request");
  if (route) route.pullPath = route.itemPath;
  return route;
}

function pagureIssueRoot() {
  return document.querySelector(".repo-body-container") ||
    document.querySelector("main") ||
    (document.querySelector("#original_comment_box") || {}).parentElement;
}

function pagureIssueHeading(root, route) {
  return Array.prototype.slice.call(root.querySelectorAll("h1, h2, h3, h4")).find(function(heading) {
    return new RegExp("^#" + route.number + "(?:\\s|$)").test(normalizeText(heading.textContent));
  }) || null;
}

function pagureAssetPaths() {
  return Array.prototype.slice.call(document.querySelectorAll("script[src]")).map(function(script) {
    var value = script.getAttribute("src");
    if (!value) return null;
    try {
      var url = new URL(value, location.href);
      return url.origin === location.origin
        ? { pathname: url.pathname, search: url.search }
        : null;
    } catch (_error) {
      return null;
    }
  }).filter(Boolean).map(function(asset) { return asset.pathname; });
}

function pagureInstallPrefix() {
  var paths = new Set(pagureAssetPaths());
  var prefixes = Array.from(paths).filter(function(path) {
    return /\/static\/pagure-common\.js$/i.test(path);
  }).map(function(path) {
    return path.replace(/\/static\/pagure-common\.js$/i, "");
  }).filter(function(prefix) {
    return paths.has(prefix + "/static/pagure-relative-dates.js");
  });
  Array.from(paths).filter(function(path) {
    return /\/static\/comments\.js$/i.test(path);
  }).map(function(path) {
    return path.replace(/\/static\/comments\.js$/i, "");
  }).filter(function(prefix) {
    return paths.has(prefix + "/static/reactions.js");
  }).forEach(function(prefix) {
    if (prefixes.indexOf(prefix) < 0) prefixes.push(prefix);
  });

  var pathname = location.pathname || "/";
  var matching = prefixes.filter(function(prefix) {
    return !prefix || pathname === prefix || pathname.indexOf(prefix + "/") === 0;
  }).sort(function(left, right) {
    return right.length - left.length;
  });
  return matching.length ? matching[0] : null;
}

function pagureAssetEvidence() {
  return pagureInstallPrefix() !== null;
}

function pagureProjectLink(route, suffix) {
  var path = route.basePath + (suffix || "");
  return Array.prototype.slice.call(document.querySelectorAll("a[href]")).find(function(link) {
    try {
      var url = new URL(link.getAttribute("href"), location.href);
      return url.origin === location.origin && url.pathname.replace(/\/$/, "") === path;
    } catch (_error) {
      return false;
    }
  }) || null;
}

function pagureProjectNavigation(route) {
  return !!(pagureProjectLink(route, "") && pagureProjectLink(route, "/issues"));
}

function pagureProductMatch(route, root) {
  if (!route || !root || !pagureAssetEvidence() || !pagureProjectNavigation(route)) return false;
  var opening = root.querySelector("#original_comment_box #comment-0, #comment-0.issue_comment");
  return !!(opening && root.querySelector("#comments") && pagureIssueHeading(root, route));
}

function pagurePullRequestHeading(route) {
  return Array.prototype.slice.call(document.querySelectorAll("h1, h2, h3, h4")).find(function(heading) {
    var marker = Array.prototype.slice.call(heading.querySelectorAll(".font-weight-bold")).some(function(node) {
      return normalizeText(node.textContent) === "#" + route.number;
    });
    return marker || new RegExp("^#" + route.number + "(?:\\s|$)").test(normalizeText(heading.textContent));
  }) || null;
}

function pagurePullRequestProductMatch(route, root) {
  if (!route || !root || !pagureAssetEvidence() || !pagureProjectNavigation(route)) return false;
  var opening = pagurePullRequestOpening(root);
  var comments = root.querySelector("section.request_comment");
  var heading = pagurePullRequestHeading(route);
  return !!(opening && comments && heading);
}

function pagurePullRequestOpening(root) {
  var marker = root && root.querySelector("#comment-0");
  return (marker && marker.closest(".card")) ||
    (root && root.querySelector(".col-md-8 > .card.mb-3, .col-md-8 > .card"));
}

function pagureIssueBody(node) {
  if (!node) return null;
  if (node.matches && node.matches(".comment_text.comment_body, .comment_body, .autogenerated-comment")) return node;
  return node.querySelector(".comment_text.comment_body, .comment_body, .autogenerated-comment");
}

function pagureNodeMarkdown(node) {
  var body = pagureIssueBody(node);
  if (!body) return "";
  var clone = visibilityPrunedClone(body);
  removeAll(clone, "button, form, [role='tooltip'], .issue_actions, .issue_reactions, .comment-reactions");
  return cleanupMarkdownNoise(markdownFor(clone.innerHTML));
}

function pagureIssueAuthor(node) {
  var event = node && (node.matches(".autogenerated-comment") ? node : node.querySelector(".autogenerated-comment"));
  if (event) {
    var eventText = normalizeText(event.textContent);
    var eventAuthor = eventText.match(/\bfrom\s+@?([\w.+~-]+)/i) ||
      eventText.match(/\bby\s+@?([\w.+~-]+)/i);
    return eventAuthor ? eventAuthor[1].replace(/[.,;:!?]+$/, "") : "";
  }

  var header = node && node.matches(".card")
    ? node.querySelector(":scope > .card-header")
    : node && node.closest(".card") && node.closest(".card").querySelector(":scope > .card-header");
  var author = header && header.querySelector(".font-weight-bold, [data-testid='author']");
  return normalizeText(author && (author.getAttribute("title") || author.textContent));
}

function pagureIssueTimestamp(node) {
  var time = node && node.querySelector("time[datetime]");
  return normalizeText(time && time.getAttribute("datetime"));
}

function pagureThreadMetadata(root) {
  var metadata = root.querySelector(".col-md-4");
  if (!metadata || elementSubtreeHidden(metadata)) return null;
  var clone = visibilityPrunedClone(metadata);
  removeAll(clone, "button, form, [role='tooltip'], .dropdown-menu");
  var markdown = cleanupMarkdownNoise(markdownFor(clone.innerHTML));
  return normalizeText(markdown) ? { node: clone, markdown: markdown } : null;
}

function pagureArchiveNotice() {
  var node = Array.prototype.slice.call(document.querySelectorAll(".alert")).find(function(candidate) {
    return !elementSubtreeHidden(candidate) && /static archive|read-only snapshot/i.test(normalizeText(candidate.textContent));
  });
  if (!node) return null;
  var clone = visibilityPrunedClone(node);
  var markdown = cleanupMarkdownNoise(markdownFor(clone.innerHTML));
  return normalizeText(markdown) ? { node: clone, markdown: markdown } : null;
}

function pagureThreadEntrySections(entries) {
  var sections = [];
  entries.forEach(function(entry) {
    var label = entry.kind + (entry.author ? " by " + entry.author : "");
    sections.push("### " + (entry.permalink ? markdownLink(label, entry.permalink) : label));
    if (entry.timestamp) sections.push("- Time: " + entry.timestamp);
    if (entry.context) sections.push("- Context: " + entry.context);
    sections.push(entry.markdown);
  });
  return sections;
}

function pagureThreadPermalink(node, threadPath) {
  var target = node && node.matches("[id^='comment-']")
    ? node
    : node && node.querySelector("[id^='comment-'], a[href*='#comment-']");
  var value = target && (target.id ? "#" + target.id : target.getAttribute("href"));
  var url = materializedHttpUrl(value);
  if (!url) return null;
  try {
    var parsed = new URL(url);
    if (parsed.origin !== location.origin || parsed.pathname.replace(/\/$/, "") !== threadPath) return null;
    return /^#comment-\d+$/.test(parsed.hash) ? location.origin + threadPath + parsed.hash : null;
  } catch (_error) {
    return null;
  }
}

function pagureIssuePermalink(node, route) {
  return pagureThreadPermalink(node, route.issuePath);
}

function pagureIssueInventory(route) {
  var api = location.origin + route.apiPrefix + "/" + route.projectPath + "/issue/" + route.number + "?comments=true";
  var entries = [
    { label: "Project", url: location.origin + route.basePath },
    { label: "Issues", url: location.origin + route.basePath + "/issues" },
    { label: "Issue page", url: location.origin + route.issuePath },
    {
      label: "Issue API",
      url: api,
      detail: "When enabled, this includes comments. Static archives and some installations may not expose this route."
    }
  ];
  if (pagureProjectLink(route, "/pull-requests")) {
    entries.splice(2, 0, { label: "Pull requests", url: location.origin + route.basePath + "/pull-requests" });
  }
  return browsableInventory("Browse this Pagure issue", entries);
}
