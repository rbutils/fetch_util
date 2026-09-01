function azureDevopsPullRequestRoute() {
  var pathname = (location.pathname || "").replace(/\/+$/, "");
  var marker = pathname.toLowerCase().lastIndexOf("/_git/");
  if (marker < 1) return null;
  var prefixPath = pathname.slice(0, marker);
  var tail = pathname.slice(marker + 6).split("/").filter(Boolean);
  if (tail.length !== 3 || tail[1].toLowerCase() !== "pullrequest" || !/^\d+$/.test(tail[2])) return null;

  var repository = safeDecodeURI(tail[0]);
  var prefixParts = prefixPath.split("/").filter(Boolean).map(safeDecodeURI);
  if (!repository || repository === "." || repository === ".." || !prefixParts.length ||
      prefixParts.some(function(part) { return !part || part === "." || part === ".."; })) return null;
  return {
    prefixPath: prefixPath,
    project: prefixParts[prefixParts.length - 1],
    repository: repository,
    number: tail[2],
    basePath: prefixPath + "/_git/" + tail[0] + "/pullrequest/" + tail[2]
  };
}

function azureDevopsPullRequestProductMatch(route) {
  if (!route || !document.body || !document.body.classList.contains("ms-vss-web-vsts-theme")) return false;
  var heading = Array.prototype.slice.call(document.querySelectorAll("[role='heading'], h1")).some(function(node) {
    return new RegExp("\\bPull Request\\s+" + route.number + "\\b", "i").test(normalizeText(node.textContent));
  });
  var tabs = ["overview", "files", "updates", "commits"].every(function(name) {
    var tab = document.querySelector("#__bolt-tab-" + name);
    if (!tab) return false;
    try {
      var url = new URL(tab.getAttribute("href"), location.href);
      return url.origin === location.origin && url.pathname === route.basePath && url.searchParams.get("_a") === name;
    } catch (_error) {
      return false;
    }
  });
  var module = Array.prototype.slice.call(document.scripts).some(function(script) {
    return /Repos\/Views\/PullRequest|Repos\/Discussion/.test(script.textContent || "");
  });
  return heading && tabs && module;
}

function azureDevopsPreparedPullRequest(route) {
  var prepared = window.__fetchUtilAzureDevopsPullRequest;
  if (!route || !prepared || prepared.status !== "ready" || !prepared.product || !prepared.route ||
      !prepared.metadata || !prepared.threads || !Array.isArray(prepared.commits)) return null;
  if (normalizeText(prepared.route.number) !== route.number ||
      normalizeText(prepared.route.project).toLowerCase() !== route.project.toLowerCase() ||
      normalizeText(prepared.route.repository).toLowerCase() !== route.repository.toLowerCase() ||
      !Array.isArray(prepared.threads.value)) return null;
  var metadata = prepared.metadata;
  var repository = metadata.repository || {};
  var project = repository.project || {};
  if (normalizeText(metadata.pullRequestId) !== route.number ||
      normalizeText(repository.name).toLowerCase() !== route.repository.toLowerCase() ||
      normalizeText(project.name).toLowerCase() !== route.project.toLowerCase() ||
      !/^public$/i.test(normalizeText(project.visibility))) return null;
  return prepared;
}

function azureDevopsAccountName(account) {
  return normalizeText(account && (account.displayName || account.uniqueName || account.id));
}

function azureDevopsLiteralBlock(value) {
  return String(value == null ? "" : value).replace(/\r\n?/g, "\n").split("\n").map(function(line) {
    return "    " + line;
  }).join("\n");
}

function azureDevopsSameOriginUrl(value) {
  var url = materializedHttpUrl(value);
  if (!url) return null;
  try {
    return new URL(url).origin === location.origin ? url : null;
  } catch (_error) {
    return null;
  }
}

function azureDevopsApiUrl(path, parameters) {
  try {
    var url = new URL(path, location.origin);
    if (url.origin !== location.origin) return null;
    Object.keys(parameters || {}).forEach(function(name) { url.searchParams.set(name, parameters[name]); });
    return materializedHttpUrl(url.href);
  } catch (_error) {
    return null;
  }
}

function azureDevopsPullRequestUiInventory(route) {
  return ["overview", "files", "updates", "commits"].map(function(name) {
    return {
      label: name.charAt(0).toUpperCase() + name.slice(1),
      url: azureDevopsApiUrl(route.basePath, { _a: name })
    };
  });
}

function azureDevopsFailedPullRequestContent(metadata, route, prepared) {
  if (!prepared || prepared.status !== "failed" || !prepared.route ||
      normalizeText(prepared.route.number) !== route.number ||
      normalizeText(prepared.route.project).toLowerCase() !== route.project.toLowerCase() ||
      normalizeText(prepared.route.repository).toLowerCase() !== route.repository.toLowerCase()) return null;

  var root = document.querySelector("main") || document.body;
  var clone = visibilityPrunedClone(root);
  removeAll(clone, "script, style, button, [role='tooltip']");
  var visible = cleanupMarkdownNoise(markdownFor(clone.innerHTML));
  var title = normalizeText(metadata.title || document.title || ("Pull request " + route.number));
  var reason = normalizeText(prepared.reason || "Azure DevOps REST preparation failed");
  var sections = [
    "# " + title,
    "## Retrieval warning",
    "Azure DevOps REST conversation preparation failed; visible page content may be incomplete.",
    azureDevopsLiteralBlock(reason)
  ];
  if (visible) sections.push("## Visible page content", visible);
  sections.push(browsableInventory("Browse this Azure DevOps pull request", azureDevopsPullRequestUiInventory(route)));
  var markdown = sections.join("\n\n");
  return {
    title: title,
    siteName: "Azure DevOps",
    html: clone.outerHTML,
    markdown: markdown,
    textContent: normalizeText(markdown),
    contentType: "article",
    readerMode: false,
    hostAware: true,
    warningReasons: ["azure_devops_rest_incomplete"]
  };
}

function azureDevopsPullRequestInventory(prepared) {
  var route = prepared.route;
  var metadata = prepared.metadata;
  var repository = metadata.repository || {};
  var entries = azureDevopsPullRequestUiInventory(route);
  entries = entries.concat([
    { label: "Pull request metadata API", url: azureDevopsApiUrl(route.repositoryApiPath, { "api-version": "7.1" }) },
    { label: "Threads API", url: azureDevopsApiUrl(route.repositoryApiPath + "/threads", { "api-version": "7.1" }) },
    { label: "Commits API", url: azureDevopsApiUrl(route.repositoryApiPath + "/commits", { "api-version": "7.1", "$top": "1000" }),
      detail: "Follow each opaque x-ms-continuationtoken until the header is absent." },
    { label: "Work items API", url: azureDevopsApiUrl(route.repositoryApiPath + "/workitems", { "api-version": "7.1" }) },
    { label: "Reviewers API", url: azureDevopsApiUrl(route.repositoryApiPath + "/reviewers", { "api-version": "7.1" }),
      detail: "May require authentication; embedded reviewers are included above." },
    { label: "Iterations API", url: azureDevopsApiUrl(route.repositoryApiPath + "/iterations", { "api-version": "7.1" }),
      detail: "May require authentication; enumerate iterations before requesting changes." },
    { label: "Statuses API", url: azureDevopsApiUrl(route.repositoryApiPath + "/statuses", { "api-version": "7.1" }),
      detail: "May require authentication." },
    { label: "Pull request builds API", url: azureDevopsApiUrl(route.prefixPath + "/_apis/build/builds", {
      repositoryId: repository.id || "", repositoryType: "TfsGit", reasonFilter: "pullRequest",
      branchName: "refs/pull/" + route.number + "/merge", "$top": "1000", "api-version": "7.1"
    }), detail: "May require authentication. Follow each opaque x-ms-continuationtoken until the header is absent." }
  ]);
  prepared.threads.value.forEach(function(thread) {
    var threadUrl = azureDevopsSameOriginUrl(thread && thread._links && thread._links.self && thread._links.self.href);
    if (threadUrl) entries.push({ label: "Thread " + normalizeText(thread.id), url: threadUrl });
    (Array.isArray(thread && thread.comments) ? thread.comments : []).forEach(function(comment) {
      var commentUrl = azureDevopsSameOriginUrl(comment && comment._links && comment._links.self && comment._links.self.href);
      if (commentUrl) entries.push({ label: "Comment " + normalizeText(comment.id), url: commentUrl });
    });
  });
  prepared.commits.forEach(function(commit) {
    var url = azureDevopsSameOriginUrl(commit && (commit.remoteUrl || commit.url));
    if (url) entries.push({ label: "Commit " + normalizeText(commit.commitId), url: url });
  });
  return browsableInventory("Browse this Azure DevOps pull request", entries);
}
